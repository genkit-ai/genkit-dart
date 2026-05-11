// Copyright 2025 Google LLC
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

import 'dart:convert';

import 'package:genkit/plugin.dart';
import 'package:schemantic/schemantic.dart';

const _unsupportedGoogleCloudStorageMediaUrlMessage =
    'Meta models on Vertex AI do not support gs:// media URLs. Use a publicly accessible HTTPS URL or a data URI instead.';

final metaModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'tools': true,
    'systemRole': true,
    'constrained': true,
  },
);

base class VertexAiMetaOptions {
  factory VertexAiMetaOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  VertexAiMetaOptions._(this._json);

  VertexAiMetaOptions({
    String? version,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<String>? stop,
    double? presencePenalty,
    double? frequencyPenalty,
    int? seed,
    String? user,
    bool? llamaGuard,
  }) {
    _json = {
      'version': ?version,
      'temperature': ?temperature,
      'topP': ?topP,
      'maxTokens': ?maxTokens,
      'stop': ?stop,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'seed': ?seed,
      'user': ?user,
      'llamaGuard': ?llamaGuard,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<VertexAiMetaOptions> $schema =
      _VertexAiMetaOptionsTypeFactory();

  String? get version => _json['version'] as String?;
  double? get temperature => (_json['temperature'] as num?)?.toDouble();
  double? get topP => (_json['topP'] as num?)?.toDouble();
  int? get maxTokens => _json['maxTokens'] as int?;
  List<String>? get stop => (_json['stop'] as List?)?.cast<String>();
  double? get presencePenalty => (_json['presencePenalty'] as num?)?.toDouble();
  double? get frequencyPenalty =>
      (_json['frequencyPenalty'] as num?)?.toDouble();
  int? get seed => _json['seed'] as int?;
  String? get user => _json['user'] as String?;
  bool? get llamaGuard => _json['llamaGuard'] as bool?;

  Map<String, dynamic> toJson() => _json;
}

base class _VertexAiMetaOptionsTypeFactory
    extends SchemanticType<VertexAiMetaOptions> {
  const _VertexAiMetaOptionsTypeFactory();

  @override
  VertexAiMetaOptions parse(Object? json) {
    return VertexAiMetaOptions._((json as Map).cast<String, dynamic>());
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'VertexAiMetaOptions',
    definition: {
      'type': 'object',
      'properties': {
        'version': {'type': 'string'},
        'temperature': {'type': 'number', 'minimum': 0.0, 'maximum': 2.0},
        'topP': {'type': 'number', 'minimum': 0.0, 'maximum': 1.0},
        'maxTokens': {'type': 'integer'},
        'stop': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'presencePenalty': {'type': 'number', 'minimum': -2.0, 'maximum': 2.0},
        'frequencyPenalty': {'type': 'number', 'minimum': -2.0, 'maximum': 2.0},
        'seed': {'type': 'integer'},
        'user': {'type': 'string'},
        'llamaGuard': {
          'type': 'boolean',
          'description':
              'Whether Vertex AI should enable Llama Guard safety checks.',
        },
      },
    },
  );
}

Map<String, dynamic> toMetaChatCompletionRequest(
  ModelRequest req,
  String modelName,
  VertexAiMetaOptions options, {
  required bool stream,
}) {
  final isJsonMode =
      req.output?.format == 'json' ||
      req.output?.contentType == 'application/json';
  return {
    'model': options.version ?? modelName,
    'messages': _toMetaMessages(req.messages),
    'stream': stream,
    if (req.tools?.isNotEmpty == true)
      'tools': req.tools!.map(_toMetaTool).toList(),
    'temperature': ?options.temperature,
    'top_p': ?options.topP,
    'max_tokens': ?options.maxTokens,
    'stop': ?options.stop,
    'presence_penalty': ?options.presencePenalty,
    'frequency_penalty': ?options.frequencyPenalty,
    'seed': ?options.seed,
    'user': ?options.user,
    if (isJsonMode && req.output?.schema != null)
      'response_format': {
        'type': 'json_schema',
        'json_schema': {
          'name': 'output',
          'schema': {...req.output!.schema!, 'additionalProperties': false},
          'strict': true,
        },
      },
    if (options.llamaGuard != null)
      'extra_body': {
        'google': {
          'model_safety_settings': {
            'enabled': options.llamaGuard,
            'llama_guard_settings': <String, dynamic>{},
          },
        },
      },
  };
}

ModelResponse fromMetaChatCompletionResponse(Map<String, dynamic> response) {
  final choices = response['choices'] as List?;
  if (choices == null || choices.isEmpty) {
    throw GenkitException('Meta model returned no choices.');
  }
  final choice = choices.first as Map<String, dynamic>;
  final message = choice['message'] as Map<String, dynamic>?;
  if (message == null) {
    throw GenkitException('Meta model returned no message.');
  }
  return ModelResponse(
    finishReason: _mapMetaFinishReason(choice['finish_reason'] as String?),
    message: _fromMetaMessage(message),
    raw: response,
    usage: _fromMetaUsage(response['usage'] as Map<String, dynamic>?),
  );
}

ModelResponse fromMetaChatCompletionChunks(List<Map<String, dynamic>> chunks) {
  final content = StringBuffer();
  var finishReason = FinishReason.unknown;
  GenerationUsage? usage;

  for (final chunk in chunks) {
    final choices = chunk['choices'] as List?;
    if (choices == null || choices.isEmpty) continue;
    final choice = choices.first as Map<String, dynamic>;
    final delta = choice['delta'] as Map<String, dynamic>?;
    final text = delta?['content'] as String?;
    if (text != null) content.write(text);
    if (choice['finish_reason'] != null) {
      finishReason = _mapMetaFinishReason(choice['finish_reason'] as String?);
    }
    usage = _fromMetaUsage(chunk['usage'] as Map<String, dynamic>?) ?? usage;
  }

  return ModelResponse(
    finishReason: finishReason,
    message: Message(
      role: Role.model,
      content: [TextPart(text: '$content')],
    ),
    raw: {'chunks': chunks},
    usage: usage,
  );
}

List<Map<String, dynamic>> _toMetaMessages(List<Message> messages) {
  final result = <Map<String, dynamic>>[];
  for (final message in messages) {
    if (message.role == Role.tool) {
      result.addAll(_toMetaToolMessages(message));
      continue;
    }
    result.add(_toMetaMessage(message));
  }
  return result;
}

Map<String, dynamic> _toMetaMessage(Message message) {
  return switch (message.role.value) {
    'system' => {'role': 'system', 'content': message.text},
    'user' => {'role': 'user', 'content': _toMetaContent(message.content)},
    'model' => {
      'role': 'assistant',
      'content': message.text,
      if (_toMetaToolCalls(message.content).isNotEmpty)
        'tool_calls': _toMetaToolCalls(message.content),
    },
    _ => throw UnimplementedError('Unsupported role: ${message.role}'),
  };
}

List<Map<String, dynamic>> _toMetaToolMessages(Message message) {
  final toolResponses = message.content
      .where((p) => p.isToolResponse)
      .map((p) => p.toolResponse!)
      .toList();
  if (toolResponses.isEmpty) {
    throw ArgumentError('Tool message must contain a ToolResponsePart.');
  }
  return toolResponses.map((response) {
    final ref = response.ref;
    if (ref == null || ref.isEmpty) {
      throw ArgumentError('ToolResponse.ref must be set for Meta models.');
    }
    return {
      'role': 'tool',
      'tool_call_id': ref,
      'content': jsonEncode(response.output),
    };
  }).toList();
}

Object _toMetaContent(List<Part> parts) {
  if (parts.every((part) => part.isText)) {
    return parts.map((part) => part.text).join('\n');
  }
  return parts.map(_toMetaContentPart).toList();
}

Map<String, dynamic> _toMetaContentPart(Part part) {
  if (part.isText) {
    return {'type': 'text', 'text': part.text};
  }
  if (part.isMedia) {
    final mediaUrl = part.media!.url;
    if (mediaUrl.startsWith('gs://')) {
      throw ArgumentError(_unsupportedGoogleCloudStorageMediaUrlMessage);
    }
    return {
      'type': 'image_url',
      'image_url': {'url': mediaUrl},
    };
  }
  throw UnimplementedError('Unsupported part type for Meta model: $part');
}

List<Map<String, dynamic>> _toMetaToolCalls(List<Part> parts) {
  return parts.where((part) => part.isToolRequest).map((part) {
    final request = part.toolRequest!;
    final ref = request.ref;
    if (ref == null || ref.isEmpty) {
      throw ArgumentError('ToolRequest.ref must be set for Meta models.');
    }
    return {
      'id': ref,
      'type': 'function',
      'function': {
        'name': request.name,
        'arguments': jsonEncode(request.input ?? <String, dynamic>{}),
      },
    };
  }).toList();
}

Map<String, dynamic> _toMetaTool(ToolDefinition tool) {
  return {
    'type': 'function',
    'function': {
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.inputSchema ?? {'type': 'object', 'properties': {}},
    },
  };
}

Message _fromMetaMessage(Map<String, dynamic> message) {
  final parts = <Part>[];
  final refusal = message['refusal'] as String?;
  if (refusal != null && refusal.isNotEmpty) {
    parts.add(TextPart(text: '[Refusal] $refusal'));
  }
  final content = message['content'] as String?;
  if (content != null && content.isNotEmpty) {
    parts.add(TextPart(text: content));
  }
  final toolCalls = message['tool_calls'] as List?;
  if (toolCalls != null) {
    for (final toolCall in toolCalls.cast<Map<String, dynamic>>()) {
      final function = toolCall['function'] as Map<String, dynamic>;
      final arguments = function['arguments'] as String? ?? '{}';
      parts.add(
        ToolRequestPart(
          toolRequest: ToolRequest(
            ref: toolCall['id'] as String?,
            name: function['name'] as String,
            input: jsonDecode(arguments) as Map<String, dynamic>,
          ),
        ),
      );
    }
  }
  return Message(role: Role.model, content: parts);
}

FinishReason _mapMetaFinishReason(String? reason) {
  return switch (reason) {
    'stop' => FinishReason.stop,
    'length' => FinishReason.length,
    'content_filter' => FinishReason.blocked,
    'tool_calls' => FinishReason.stop,
    _ => FinishReason.unknown,
  };
}

GenerationUsage? _fromMetaUsage(Map<String, dynamic>? usage) {
  if (usage == null) return null;
  return GenerationUsage(
    inputTokens: (usage['prompt_tokens'] as num?)?.toDouble(),
    outputTokens: (usage['completion_tokens'] as num?)?.toDouble(),
    totalTokens: (usage['total_tokens'] as num?)?.toDouble(),
  );
}
