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

import 'package:genkit_schema_builder/genkit_schema_builder.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/types.dart';
import 'package:test/test.dart';

part 'model_test.schema.g.dart';

@GenkitSchema()
abstract class TestCustomOptionsSchema {
  String get customField;
}

void main() {
  group('Model', () {
    test('should include customOptions in metadata', () {
      final model = Model(
        name: 'testModel',
        fn: (request, context) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: 'hi')],
            ),
          );
        },
        customOptions: TestCustomOptionsType,
      );

      final metadata = model.metadata;
      expect(metadata['model']['customOptions'], isNotNull);
      expect(metadata['model']['customOptions'], {
        r'$ref': r'#/$defs/TestCustomOptions',
        r'$defs': {
          'TestCustomOptions': {
            'type': 'object',
            'properties': {
              'customField': {'type': 'string'},
            },
            'required': ['customField'],
          },
        },
        r'$schema': 'http://json-schema.org/draft-07/schema#',
      });
    });
  });
}
