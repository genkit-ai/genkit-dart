
import 'package:test/test.dart';
import 'dart:convert';
import 'package:schemantic/schemantic.dart';

void main() {
  group('Basic Types Metadata & Constraints', () {
    test('stringType() metadata', () {
      final t = stringType(
        description: 'A test string',
        minLength: 5,
        maxLength: 10,
        pattern: r'^[a-z]+$',
        format: 'email',
        enumValues: ['a', 'b'],
      );
      
      final json = jsonDecode(t.jsonSchema().toJson());
      
      expect(json['type'], 'string');
      expect(json['description'], 'A test string');
      expect(json['minLength'], 5);
      expect(json['maxLength'], 10);
      expect(json['pattern'], r'^[a-z]+$');
      expect(json['format'], 'email');
      expect(json['enum'], ['a', 'b']);
    });

    test('intType() metadata', () {
      final t = intType(
        description: 'A test int',
        minimum: 0,
        maximum: 100,
        exclusiveMinimum: 10,
        exclusiveMaximum: 90,
        multipleOf: 5,
      );

      final json = jsonDecode(t.jsonSchema().toJson());

      expect(json['type'], 'integer');
      expect(json['description'], 'A test int');
      expect(json['minimum'], 0);
      expect(json['maximum'], 100);
      expect(json['exclusiveMinimum'], 10);
      expect(json['exclusiveMaximum'], 90);
      expect(json['multipleOf'], 5);
    });

    test('doubleType() metadata', () {
      final t = doubleType(
        description: 'A test double',
        minimum: 0.5,
        maximum: 100.5,
        exclusiveMinimum: 10.5,
        exclusiveMaximum: 90.5,
        multipleOf: 0.5,
      );

      final json = jsonDecode(t.jsonSchema().toJson());

      expect(json['type'], 'number');
      expect(json['description'], 'A test double');
      expect(json['minimum'], 0.5);
      expect(json['maximum'], 100.5);
      expect(json['exclusiveMinimum'], 10.5);
      expect(json['exclusiveMaximum'], 90.5);
      expect(json['multipleOf'], 0.5);
    });
    
    test('boolType() metadata', () {
      final t = boolType(description: 'A test bool');
      final json = jsonDecode(t.jsonSchema().toJson());
      expect(json['type'], 'boolean');
      expect(json['description'], 'A test bool');
    });
    
    test('voidType() metadata', () {
        final t = voidType(description: 'A test void');
        final json = jsonDecode(t.jsonSchema().toJson());
        expect(json['type'], 'null');
        expect(json['description'], 'A test void');
    });

    test('dynamicType() metadata', () {
      final t = dynamicType(description: 'A test dynamic');
      final json = jsonDecode(t.jsonSchema().toJson());
      // For dynamic allow anything, so usually empty or just description
      expect(json['description'], 'A test dynamic');
    });

    test('listType metadata', () {
       final t = listType(stringType(),
         description: 'A test list',
         minItems: 1,
         maxItems: 5,
         uniqueItems: true,
       );
       
       final json = jsonDecode(t.jsonSchema().toJson());
       
       expect(json['type'], 'array');
       expect(json['description'], 'A test list');
       expect(json['minItems'], 1);
       expect(json['maxItems'], 5);
       expect(json['uniqueItems'], true);
    });

    test('mapType metadata', () {
      final t = mapType(stringType(), intType(),
        description: 'A test map',
        minProperties: 2,
        maxProperties: 10,
      );
      
      final json = jsonDecode(t.jsonSchema().toJson());
      
      expect(json['type'], 'object');
      expect(json['description'], 'A test map');
      expect(json['minProperties'], 2);
      expect(json['maxProperties'], 10);
    });
  });
}
