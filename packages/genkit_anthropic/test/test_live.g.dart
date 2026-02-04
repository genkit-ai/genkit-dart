// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'test_live.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class Person {
  factory Person.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Person._(this._json);

  Person({required String name, required int age}) {
    _json = {'name': name, 'age': age};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<Person> $schema = _PersonTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  int get age {
    return _json['age'] as int;
  }

  set age(int value) {
    _json['age'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _PersonTypeFactory extends SchemanticType<Person> {
  const _PersonTypeFactory();

  @override
  Person parse(Object? json) {
    return Person._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Person',
    definition: Schema.object(
      properties: {'name': Schema.string(), 'age': Schema.integer()},
      required: ['name', 'age'],
    ),
    dependencies: [],
  );
}
