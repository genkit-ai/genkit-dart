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

import 'package:genkit/genkit.dart';
import 'package:schemantic_sample/person.dart';
import 'package:test/test.dart';

void main() {
  group('3rd-party Serializer (json_serializable)', () {
    test('SchemanticType.from correctly parses input', () {
      final person = Person.schema.parse({
        'firstName': 'John',
        'lastName': 'Doe',
      });

      expect(person.firstName, 'John');
      expect(person.lastName, 'Doe');
    });

    test('SchemanticType.from correctly returns jsonSchema', () {
      final jsonSchema = Person.schema.jsonSchema();

      expect(jsonSchema['type'], 'object');
      expect(jsonSchema['properties'], contains('firstName'));
      expect(jsonSchema['properties'], contains('lastName'));
      expect(jsonSchema['required'], contains('firstName'));
      expect(jsonSchema['required'], contains('lastName'));
    });

    test('Flow with custom schema works', () async {
      final ai = Genkit();

      final helloFlow = ai.defineFlow(
        name: 'helloFlow',
        inputSchema: Person.schema,
        outputSchema: .string(),
        fn: (person, _) async =>
            'Hello, ${person.firstName} ${person.lastName}!',
      );

      final result = await helloFlow.runRaw({
        'firstName': 'Jane',
        'lastName': 'Smith',
      });

      expect(result.result, 'Hello, Jane Smith!');
    });
  });
}
