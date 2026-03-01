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

import 'package:schemantic/schemantic.dart';

import '../core/action.dart';
import '../exception.dart';
import '../types.dart';

part 'resource.g.dart';

@Schematic()
abstract class $ResourceInput {
  String get uri;
}

@Schematic()
abstract class $ResourceOutput {
  List<$Part> get content;
}

typedef ResourceFn =
    Future<ResourceOutput> Function(
      ResourceInput input,
      ActionFnArg<void, ResourceInput, void> ctx,
    );

class ResourceAction extends Action<ResourceInput, ResourceOutput, void, void> {
  final bool Function(ResourceInput input) _matches;

  ResourceAction({
    required super.name,
    required ResourceFn fn,
    required bool Function(ResourceInput input) matches,
    super.description,
    Map<String, dynamic>? metadata,
  }) : _matches = matches,
       super(
         actionType: 'resource',
         inputSchema: ResourceInput.$schema,
         outputSchema: ResourceOutput.$schema,
         metadata: _resourceMetadata(description, metadata),
         fn: (input, ctx) {
           if (input == null) {
             throw ArgumentError('Resource "$name" requires a non-null input.');
           }
           return fn(input, ctx);
         },
       );

  bool matches(ResourceInput input) => _matches(input);
}

Map<String, dynamic> _resourceMetadata(
  String? description,
  Map<String, dynamic>? metadata,
) {
  final result = <String, dynamic>{...?metadata};
  result['type'] = 'resource';
  if (description != null) {
    result['description'] = description;
  }
  return result;
}

bool Function(ResourceInput input) createResourceMatcher({
  required String? uri,
  required String? template,
}) {
  if (uri != null) {
    if (template == null) {
      return (input) => input.uri == uri;
    }
  } else if (template != null) {
    final regex = _buildSimpleTemplateRegex(template!);
    return (input) => regex.hasMatch(input.uri);
  }
  throw GenkitException(
    'Resource must specify exactly one of uri or template.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

RegExp _buildSimpleTemplateRegex(String template) {
  final buffer = StringBuffer('^');
  var lastIndex = 0;

  final matches = _templateVariablePattern.allMatches(template);
  for (final match in matches) {
    final invalidVarName = match[1];
    if (invalidVarName != null) {
      // Not a simple template var name.
      throw GenkitException(
        'Resource template contains unsupported operator: {$invalidVarName}',
        status: StatusCodes.UNIMPLEMENTED,
      );
    }
    buffer.write(RegExp.escape(template.substring(lastIndex, match.start)));
    buffer.write('(.+?)');
    lastIndex = match.end;
  }

  buffer.write(RegExp.escape(template.substring(lastIndex)));
  buffer.write(r'$');
  return RegExp(buffer.toString());
}

/// Matches `{...}`, and captures `...` if it's not a valid template var name.
final _templateVariablePattern = RegExp(r'\{(?:[A-Za-z0-9_]+|([^}]+))\}');
