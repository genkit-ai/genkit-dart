// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:meta/meta.dart';

import '../types.dart';

/// The wrapper property that carries a non-object tool input to the model.
const _wrappedInputKey = 'input';

/// Adapts tools with non-object input schemas (e.g. `.string()`) at the model
/// boundary.
///
/// No provider accepts a non-object function parameter schema, so the model
/// sees `{input: <schema>}` and its tool calls carry `{input: <value>}`.
/// Everything above the model (history, middleware, interrupts, tool
/// functions) only ever sees the bare value: requests are wrapped on the way
/// in and responses/chunks unwrapped on the way out.
///
/// Stateless: which tools are wrapped is derived from `request.tools`, so a
/// history tool request for a tool that is no longer offered is sent as is.
@internal
final class ToolInputWrapping {
  ToolInputWrapping._(this._wrappedNames);

  /// Wire names (and original names) of the tools whose input is wrapped.
  final Set<String> _wrappedNames;

  List<String> get toolNames => _wrappedNames.toList();

  /// Returns null when none of [tools] need wrapping (the common case), so
  /// callers can skip the request/response rewrite entirely.
  static ToolInputWrapping? forTools(List<ToolDefinition>? tools) {
    if (tools == null || tools.isEmpty) return null;
    final names = <String>{};
    for (final tool in tools) {
      final schema = tool.inputSchema;
      if (schema == null || !needsWrapping(schema)) continue;
      names.add(tool.name);
      final original = tool.metadata?['originalName'];
      if (original is String) names.add(original);
    }
    return names.isEmpty ? null : ToolInputWrapping._(names);
  }

  /// Wraps tool schemas and history tool requests. Bidi turns after the init
  /// carry no `tools`; only their messages are rewritten.
  ModelRequest wrapRequest(ModelRequest request) {
    final json = Map<String, dynamic>.of(request.toJson());
    final tools = request.tools;
    if (tools != null) {
      json['tools'] = [
        for (final tool in tools)
          _wrappedNames.contains(tool.name) && tool.inputSchema != null
              ? <String, dynamic>{
                  ...tool.toJson(),
                  'inputSchema': wrapSchema(tool.inputSchema!),
                }
              : tool.toJson(),
      ];
    }
    final messages = json['messages'] as List;
    if (messages.any((m) => _hasWrappedCall((m as Map)['content'] as List))) {
      json['messages'] = [
        for (final message in messages.cast<Map<String, dynamic>>())
          _mapMessage(
            message,
            (input) => <String, dynamic>{_wrappedInputKey: input},
          ),
      ];
    }
    return ModelRequest.fromJson(json);
  }

  ModelResponse unwrapResponse(ModelResponse response) {
    final json = response.toJson();
    final message = json['message'] as Map<String, dynamic>?;
    if (message == null || !_hasWrappedCall(message['content'] as List)) {
      return response;
    }
    return ModelResponse.fromJson({
      ...json,
      'message': _mapMessage(message, _unwrap),
    });
  }

  ModelResponseChunk unwrapChunk(ModelResponseChunk chunk) {
    final json = chunk.toJson();
    final content = json['content'] as List;
    // Most chunks are text; pass them through untouched.
    if (!_hasWrappedCall(content)) return chunk;
    return ModelResponseChunk.fromJson({
      ...json,
      'content': _mapContent(content, _unwrap),
    });
  }

  // Works on the raw JSON: `Message.content` would build a `Part` per entry.
  bool _hasWrappedCall(List<Object?> content) => content.any(
    (part) =>
        part is Map &&
        part['toolRequest'] is Map &&
        _wrappedNames.contains((part['toolRequest'] as Map)['name']),
  );

  // A model that ignores the wrapper (no `input` key) gets its arguments
  // passed through as is; the tool's own schema validation reports the error.
  static Object? _unwrap(Object? input) =>
      input is Map && input.containsKey(_wrappedInputKey)
      ? input[_wrappedInputKey]
      : input;

  Map<String, dynamic> _mapMessage(
    Map<String, dynamic> message,
    Object? Function(Object?) transform,
  ) => <String, dynamic>{
    ...message,
    'content': _mapContent(message['content'] as List, transform),
  };

  List<Map<String, dynamic>> _mapContent(
    List<Object?> content,
    Object? Function(Object?) transform,
  ) => [
    for (final part in content.cast<Map<String, dynamic>>())
      if (part['toolRequest'] case final Map<String, dynamic> request
          when _wrappedNames.contains(request['name']))
        <String, dynamic>{
          ...part,
          'toolRequest': <String, dynamic>{
            ...request,
            'input': transform(request['input']),
          },
        }
      else
        part,
  ];
}

/// JSON Schema keys that annotate but don't constrain. A schema made only of
/// these accepts any value (e.g. `.dynamicSchema(description: ...)`).
const _annotationKeys = {
  r'$schema',
  r'$comment',
  'title',
  'description',
  'default',
  'examples',
};

/// Whether [schema] describes something other than an object (a primitive,
/// array, nullable or union), which providers reject as function parameters.
///
/// An untyped schema (`.dynamicSchema()`, any value) is left alone: wrapping
/// it would change what existing untyped tools receive.
@visibleForTesting
bool needsWrapping(Map<String, dynamic> schema) {
  if (schema.keys.every(_annotationKeys.contains)) return false;
  if (schema.containsKey('properties')) return false;
  final type = schema['type'];
  if (type == 'object') return false;
  if (type is List && type.contains('object')) return false;
  final ref = schema[r'$ref'];
  if (ref is String) {
    // A root `$ref` is object-like when its definition is.
    final defs = schema[r'$defs'] ?? schema['definitions'];
    final target = defs is Map ? defs[ref.split('/').last] : null;
    if (target is Map<String, dynamic>) return needsWrapping(target);
    return false;
  }
  return true;
}

/// Wraps [schema] as `{type: object, properties: {input: schema}}`.
///
/// Definitions stay on the root so the nested `#/$defs/...` refs resolve.
@visibleForTesting
Map<String, dynamic> wrapSchema(Map<String, dynamic> schema) {
  final inner = Map<String, dynamic>.of(schema);
  final wrapper = <String, dynamic>{
    'type': 'object',
    'properties': {_wrappedInputKey: inner},
    'required': [_wrappedInputKey],
  };
  for (final key in const [r'$schema', r'$defs', 'definitions']) {
    final value = inner.remove(key);
    if (value != null) wrapper[key] = value;
  }
  return wrapper;
}
