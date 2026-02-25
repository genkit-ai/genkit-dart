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

import 'package:build/build.dart';
import 'package:build_test/build_test.dart';
import 'package:logging/logging.dart';
import 'package:schemantic/builder.dart';
import 'package:test/test.dart';

void main() {
  group('SchemaGenerator', () {
    const schematicBuilderLib = r'''
class Schematic {
  final String? description;
  const Schematic({this.description});
}
class Field {
  final String? name;
  final String? description;
  final Object? defaultValue;
  const Field({this.name, this.description, this.defaultValue});
}
class StringField extends Field {
  final int? minLength;
  final int? maxLength;
  final String? pattern;
  final String? format;
  final List<String>? enumValues;
  const StringField({
    super.name,
    super.description,
    this.minLength,
    this.maxLength,
    this.pattern,
    this.format,
    this.enumValues,
    super.defaultValue,
  });
}
class IntegerField extends Field {
  final int? minimum;
  final int? maximum;
  final int? exclusiveMinimum;
  final int? exclusiveMaximum;
  final int? multipleOf;
  const IntegerField({
    super.name,
    super.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    super.defaultValue,
  });
}
class DoubleField extends Field {
  final num? minimum;
  final num? maximum;
  final num? exclusiveMinimum;
  final num? exclusiveMaximum;
  final num? multipleOf;
  const DoubleField({
    super.name,
    super.description,
    this.minimum,
    this.maximum,
    this.exclusiveMinimum,
    this.exclusiveMaximum,
    this.multipleOf,
    super.defaultValue,
  });
}
''';

    test('generates simple schema', () async {
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

@Schematic()
abstract class $User {
  String get name;
  int? get age;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
            contains('class _UserTypeFactory'),
          ),
        },
      );
    });

    test('generates nested schema with lists and nullable types', () async {
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

@Schematic()
abstract class $Address {
  String get street;
  String? get city;
}

@Schematic()
abstract class $User {
  String get name;
  List<$Address> get addresses;
  $Address? get primaryAddress;
  List<int>? get scores;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
            allOf(
              contains('class _AddressTypeFactory'),
              contains('class _UserTypeFactory'),
              contains('List<Address> get addresses {'),
              contains('Address? get primaryAddress {'),
            ),
          ),
        },
      );
    });

    test('generates schema with @Field annotation', () async {
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

@Schematic()
abstract class $Product {
  @Field(name: 'product_id', description: 'The unique identifier')
  String get id;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
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
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

enum Status { active, inactive }

@Schematic()
abstract class $Item {
  Status get status;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
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

    test('generates schema with defaultValue', () async {
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

@Schematic()
abstract class $Config {
  @StringField(defaultValue: 'production')
  String get environment;

  @IntegerField(defaultValue: 8080)
  int get port;
  
  @Field(defaultValue: true)
  bool get enabled;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
            allOf(
              contains("'default': 'production'"),
              contains("'default': 8080"),
              contains("'default': true"),
              contains("'type': 'string'"),
              contains("'type': 'integer'"),
              contains("'type': 'boolean'"),
              contains('Schema.fromMap'),
            ),
          ),
        },
      );
    });

    test('generates schema with nested schema and defaultValue', () async {
      await _testBuilderWithNoFail(
        {
          'schemantic|lib/schemantic.dart': schematicBuilderLib,
          'a|lib/a.dart': r'''
import 'package:schemantic/schemantic.dart';

part 'a.g.dart';

@Schematic()
abstract class $Inner {
  String get val;
}

@Schematic()
abstract class $Outer {
  @Field(defaultValue: {'val': 'default'})
  $Inner get inner;
}
''',
        },
        {
          'a|lib/a.schemantic.g.part': decodedMatches(
            allOf(
              contains('Schema.fromMap({'),
              contains("'allOf':"),
              contains(r"Schema.fromMap({'$ref': r'#/$defs/Inner'})"),
              contains("'default': {'val': 'default'}"),
            ),
          ),
        },
      );
    });
  });
}

Future<void> _testBuilderWithNoFail(
  Map<String, String> inputs,
  Map<String, Matcher> outputs,
) async {
  await testBuilder(
    schemaBuilder(BuilderOptions({})),
    inputs,
    outputs: outputs,
    onLog: (log) {
      if (log.level >= Level.WARNING) {
        addTearDown(() {
          fail('Unexpected log: $log');
        });
      }
    },
  );
}
