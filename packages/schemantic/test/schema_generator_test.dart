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

import 'package:build_test/build_test.dart';
import 'package:schemantic/src/schema_generator.dart';
import 'package:source_gen/source_gen.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaGenerator', () {
    const schematicBuilderLib = r'''
class Schematic {
  const Schematic();
}
class Key {
  final String? name;
  final String? description;
  const Key({this.name, this.description});
}
''';

    test('generates simple schema', () async {
      final builder = PartBuilder([SchemaGenerator()], '.schema.g.dart');

      await testBuilder(
        builder,
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.schema.g.dart';

@Schematic()
abstract class UserSchema {
  String get name;
  int? get age;
}
''',
        },
        outputs: {
          'a|lib/a.schema.g.dart': decodedMatches(
            contains('class UserTypeFactory'),
          ),
        },
      );
    });

    test('generates nested schema with lists and nullable types', () async {
      final builder = PartBuilder([SchemaGenerator()], '.schema.g.dart');

      await testBuilder(
        builder,
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.schema.g.dart';

@Schematic()
abstract class AddressSchema {
  String get street;
  String? get city;
}

@Schematic()
abstract class UserSchema {
  String get name;
  List<AddressSchema> get addresses;
  AddressSchema? get primaryAddress;
  List<int>? get scores;
}
''',
        },
        outputs: {
          'a|lib/a.schema.g.dart': decodedMatches(
            allOf(
              contains('class AddressTypeFactory'),
              contains('class UserTypeFactory'),
              contains('List<Address> get addresses {'),
              contains('Address? get primaryAddress {'),
            ),
          ),
        },
      );
    });

    test('generates schema with @Key annotation', () async {
      final builder = PartBuilder([SchemaGenerator()], '.schema.g.dart');

      await testBuilder(
        builder,
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.schema.g.dart';

@Schematic()
abstract class ProductSchema {
  @Key(name: 'product_id', description: 'The unique identifier')
  String get id;
}
''',
        },
        outputs: {
          'a|lib/a.schema.g.dart': decodedMatches(
            allOf(
              contains("return _json['product_id'] as String;"),
              contains(
                "'product_id': Schema.string(description: 'The unique identifier')",
              ),
            ),
          ),
        },
      );
    });

    test('generates schema with enums', () async {
      final builder = PartBuilder([SchemaGenerator()], '.schema.g.dart');

      await testBuilder(
        builder,
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.schema.g.dart';

enum Status { active, inactive }

@Schematic()
abstract class ItemSchema {
  Status get status;
}
''',
        },
        outputs: {
          'a|lib/a.schema.g.dart': decodedMatches(
            allOf(
              contains(
                "return Status.values.byName(_json['status'] as String);",
              ),
              contains("enumValues: ['active', 'inactive']"),
            ),
          ),
        },
      );
    });
  });
}
