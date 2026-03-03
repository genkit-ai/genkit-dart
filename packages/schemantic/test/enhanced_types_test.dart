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
import 'package:test/test.dart';

void main() {
  group('Enhanced Basic Types', () {
    test('listSchema with options', () {
      final t = SchemanticType.list(
        .string(),
        description: 'My List',
        minItems: 1,
        maxItems: 5,
        uniqueItems: true,
      );
      final json = t.jsonSchema();
      expect(json['type'], 'array');
      expect(json['description'], 'My List');
      expect(json['minItems'], 1);
      expect(json['maxItems'], 5);
      expect(json['uniqueItems'], true);
    });

    test('mapType with options', () {
      final t = SchemanticType.map(
        .string(),
        .integer(),
        description: 'My Map',
        minProperties: 2,
        maxProperties: 10,
      );
      final json = t.jsonSchema();
      expect(json['type'], 'object');
      expect(json['description'], 'My Map');
      expect(json['minProperties'], 2);
      expect(json['maxProperties'], 10);
      expect((json['additionalProperties'] as Map)['type'], 'integer');
    });

    test('listSchema with refs and options', () {
      // Create a recursive/ref type simulation (though stringSchema() is simple)
      final t = SchemanticType.list(
        _MockTypeWithDefs(),
        description: 'Recursive List',
      );
      final json = t.jsonSchema(useRefs: true);

      expect(json['type'], 'array');
      expect(json['description'], 'Recursive List');
      expect(json[r'$defs'], isNotNull);
      expect((json['items'] as Map)[r'$ref'], isNotNull);
    });
  });
}

final class _MockTypeWithDefs extends SchemanticType<int> {
  const _MockTypeWithDefs();
  @override
  int parse(Object? json) => json as int;

  @override
  Map<String, Object?> jsonSchema({bool useRefs = false}) => {
    r'$ref': '#/\$defs/Mock',
    r'$defs': {
      'Mock': {'type': 'integer'},
    },
  };
}
