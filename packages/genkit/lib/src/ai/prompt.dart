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

import '../core/action.dart';
import '../types.dart';

typedef PromptFn<Input> =
    Future<GenerateActionOptions> Function(
      Input input,
      ActionFnArg<void, Input, void> ctx,
    );

class PromptAction<Input>
    extends Action<Input, GenerateActionOptions, void, void> {
  PromptAction({
    required super.name,
    required PromptFn<Input> fn,
    super.inputSchema,
    super.description,
    Map<String, dynamic>? metadata,
  }) : super(
         actionType: 'prompt',
         outputSchema: GenerateActionOptions.$schema,
         metadata: _promptMetadata(description, metadata),
         fn: (input, ctx) {
           if (input == null && inputSchema != null && null is! Input) {
             throw ArgumentError('Prompt "$name" requires a non-null input.');
           }
           return fn(input as Input, ctx);
         },
       );
}

Map<String, dynamic> _promptMetadata(
  String? description,
  Map<String, dynamic>? metadata,
) {
  final result = <String, dynamic>{...?metadata};
  result['type'] = 'prompt';
  if (description != null) {
    result['description'] = description;
  }
  return result;
}
