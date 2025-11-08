import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:genkit/schema.dart';
import 'package:source_gen/source_gen.dart';
import 'package:json_schema_builder/json_schema_builder.dart' as jsb;

class SchemaGenerator extends GeneratorForAnnotation<GenkitSchema> {
  @override
  String generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    if (element is! ClassElement || !element.isAbstract) {
      throw InvalidGenerationSourceError(
        '`@GenkitSchema` can only be used on abstract classes.',
        element: element,
      );
    }

    final className = element.name;
    if (className == null || !className.endsWith('Schema')) {
      throw InvalidGenerationSourceError(
        'Schema class names must end with "Schema".',
        element: element,
      );
    }
    final baseName = className!.substring(0, className.length - 6);

    final extensionType = _generateExtensionType(baseName, element);
    final factory = _generateFactory(baseName, element);
    final constInstance = _generateConstInstance(baseName);

    final library = Library((b) => b
      ..body.addAll([
        extensionType,
        factory,
        constInstance,
      ]));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format('${library.accept(emitter)}');
  }

  ExtensionType _generateExtensionType(String baseName, ClassElement element) {
    return ExtensionType((b) {
      b
        ..name = baseName
        ..representationDeclaration = (RepresentationDeclarationBuilder()
              ..declaredRepresentationType = refer('Map<String, dynamic>')
              ..name = '_json')
            .build();

      for (final field in element.fields) {
        final getter = field.getter;
        if (getter != null) {
          b.methods.addAll([
            _generateGetter(getter),
            _generateSetter(getter),
          ]);
        }
      }
    });
  }

  String _convertSchemaType(DartType type) {
    final typeName = type.getDisplayString(withNullability: true);
    if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString(withNullability: false);
      if (itemTypeName.endsWith('Schema')) {
        final nestedBaseName =
            itemTypeName.substring(0, itemTypeName.length - 6);
        final nullability =
            itemType.getDisplayString(withNullability: true).endsWith('?')
                ? '?'
                : '';
        final listNullability = typeName.endsWith('?') ? '?' : '';
        return 'List<$nestedBaseName$nullability>$listNullability';
      }
    }
    final nonNullableTypeName = type.getDisplayString(withNullability: false);
    if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName =
          nonNullableTypeName.substring(0, nonNullableTypeName.length - 6);
      final nullability = typeName.endsWith('?') ? '?' : '';
      return '$nestedBaseName$nullability';
    }
    return typeName;
  }

  Method _generateGetter(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    final jsonFieldName = _getJsonKey(getter);
    final returnType = getter.returnType;
    final typeName = returnType.getDisplayString(withNullability: true);
    final convertedTypeName = _convertSchemaType(returnType);
    final nonNullableTypeName =
        returnType.getDisplayString(withNullability: false);

    var getterBody = "return _json['$jsonFieldName'] as $typeName;";

    if (returnType.isNullable) {
      getterBody = "return _json['$jsonFieldName'] as $typeName;";
      if (returnType.isDartCoreList) {
        final itemType = (returnType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString(withNullability: false);
        final itemIsNullable = itemType.isNullable;
        if (itemTypeName.endsWith('Schema')) {
          final nestedBaseName =
              itemTypeName.substring(0, itemTypeName.length - 6);
          if (itemIsNullable) {
            getterBody =
                "return (_json['$jsonFieldName'] as List?)?.map((e) => e == null ? null : $nestedBaseName(e as Map<String, dynamic>)).toList();";
          } else {
            getterBody =
                "return (_json['$jsonFieldName'] as List?)?.map((e) => $nestedBaseName(e as Map<String, dynamic>)).toList();";
          }
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List?)?.cast<$itemTypeName>();";
        }
      } else if (nonNullableTypeName.endsWith('Schema')) {
        final nestedBaseName =
            nonNullableTypeName.substring(0, nonNullableTypeName.length - 6);
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : $nestedBaseName(_json['$jsonFieldName'] as Map<String, dynamic>);";
      } else if (nonNullableTypeName == 'DateTime') {
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : DateTime.parse(_json['$jsonFieldName'] as String);";
      }
    } else if (returnType.element is EnumElement) {
      final enumName = returnType.getDisplayString(withNullability: false);
      getterBody =
          "return $enumName.values.byName(_json['$jsonFieldName'] as String);";
    } else if (returnType.isDartCoreList) {
      final itemType = (returnType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString(withNullability: false);
      final itemIsNullable = itemType.isNullable;
      if (itemTypeName.endsWith('Schema')) {
        final nestedBaseName =
            itemTypeName.substring(0, itemTypeName.length - 6);
        if (itemIsNullable) {
          getterBody =
              "return (_json['$jsonFieldName'] as List).map((e) => e == null ? null : $nestedBaseName(e as Map<String, dynamic>)).toList();";
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List).map((e) => $nestedBaseName(e as Map<String, dynamic>)).toList();";
        }
      } else {
        getterBody =
            "return (_json['$jsonFieldName'] as List).cast<$itemTypeName>();";
      }
    } else if (nonNullableTypeName == 'DateTime') {
      getterBody =
          "return DateTime.parse(_json['$jsonFieldName'] as String);";
    } else if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName =
          nonNullableTypeName.substring(0, nonNullableTypeName.length - 6);
      getterBody =
          "return $nestedBaseName(_json['$jsonFieldName'] as Map<String, dynamic>);";
    }

    return Method((b) => b
      ..type = MethodType.getter
      ..name = fieldName
      ..returns = refer(convertedTypeName)
      ..body = Code(getterBody));
  }

  Method _generateSetter(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    final jsonFieldName = _getJsonKey(getter);
    final paramType = getter.returnType;
    final convertedTypeName = _convertSchemaType(paramType);
    final nonNullableTypeName =
        paramType.getDisplayString(withNullability: false);

    var setterBody = "_json['$jsonFieldName'] = value;";

    if (paramType.isNullable) {
      var valueExpression = 'value';
      if (nonNullableTypeName.endsWith('Schema')) {
        valueExpression = '(value as dynamic)?._json';
      } else if (nonNullableTypeName == 'DateTime') {
        valueExpression = 'value?.toIso8601String()';
      } else if (paramType.isDartCoreList) {
        final itemType = (paramType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString(withNullability: false);
        final itemIsNullable = itemType.isNullable;
        if (itemTypeName.endsWith('Schema')) {
          if (itemIsNullable) {
            valueExpression =
                'value?.map((e) => (e as dynamic)?._json).toList()';
          } else {
            valueExpression =
                'value?.map((e) => (e as dynamic)._json).toList()';
          }
        }
      }
      setterBody =
          "if (value == null) { _json.remove('$jsonFieldName'); } else { _json['$jsonFieldName'] = $valueExpression; }";
    } else if (paramType.element is EnumElement) {
      setterBody = "_json['$jsonFieldName'] = value.name;";
    } else if (paramType.isDartCoreList) {
      final itemType = (paramType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString(withNullability: false);
      final itemIsNullable = itemType.isNullable;
      if (itemTypeName.endsWith('Schema')) {
        if (itemIsNullable) {
          setterBody =
              "_json['$jsonFieldName'] = value.map((e) => (e as dynamic)?._json).toList();";
        } else {
          setterBody =
              "_json['$jsonFieldName'] = value.map((e) => (e as dynamic)._json).toList();";
        }
      }
    } else if (nonNullableTypeName == 'DateTime') {
      setterBody = "_json['$jsonFieldName'] = value.toIso8601String();";
    } else if (nonNullableTypeName.endsWith('Schema')) {
      setterBody = "_json['$jsonFieldName'] = (value as dynamic)._json;";
    }

    return Method((b) => b
      ..type = MethodType.setter
      ..name = fieldName
      ..requiredParameters.add(Parameter((p) => p
        ..name = 'value'
        ..type = refer(convertedTypeName)))
      ..body = Code(setterBody));
  }

  Class _generateFactory(String baseName, ClassElement element) {
    return Class((b) {
      b
        ..name = '${baseName}TypeFactory'
        ..implements.add(refer('JsonExtensionType<$baseName>'))
        ..constructors.add(Constructor((c) => c..constant = true))
        ..methods.add(Method((m) => m
          ..annotations.add(refer('override'))
          ..name = 'parse'
          ..returns = refer(baseName)
          ..requiredParameters.add(Parameter((p) => p
            ..name = 'json'
            ..type = refer('Object')))
          ..body =
              Code('return $baseName(json as Map<String, dynamic>);')))
        ..methods.add(_generateJsonSchemaGetter(element));
    });
  }

  Method _generateJsonSchemaGetter(ClassElement element) {
    final properties = <String, Expression>{};
    final required = <String>[];

    for (final field in element.fields) {
      final getter = field.getter;
      if (getter != null) {
        final jsonFieldName = _getJsonKey(getter);
        final keyAnnotation =
            _keyChecker.firstAnnotationOf(getter, throwOnUnresolved: false);
        properties[jsonFieldName] =
            _jsonSchemaForType(getter.returnType, keyAnnotation);
        if (!getter.returnType.isNullable) {
          required.add(jsonFieldName);
        }
      }
    }

    final schemaExpression = refer('Schema.object').call([], {
      'properties': literalMap(properties),
      'required': literalList(required.map((r) => literalString(r))),
    });

    return Method((b) => b
      ..annotations.add(refer('override'))
      ..type = MethodType.getter
      ..name = 'jsonSchema'
      ..returns = refer('Schema')
      ..body = schemaExpression.returned.statement);
  }

  Expression _jsonSchemaForType(DartType type, DartObject? keyAnnotation) {
    final properties = <String, Expression>{};
    if (keyAnnotation != null) {
      final reader = ConstantReader(keyAnnotation);
      final description = reader.read('description').literalValue as String?;
      if (description != null) {
        properties['description'] = literalString(description);
      }
    }
    
    Expression schemaExpression;
    if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final enumValues = enumElement.fields
          .where((f) => f.isEnumConstant)
          .map((f) => f.name)
          .toList();
      properties['enumValues'] = literalList(enumValues);
      schemaExpression = refer('Schema.string').call([], properties);
    } else if (type.isDartCoreString) {
      schemaExpression = refer('Schema.string').call([], properties);
    } else if (type.isDartCoreInt) {
      schemaExpression = refer('Schema.integer').call([], properties);
    } else if (type.isDartCoreBool) {
      schemaExpression = refer('Schema.boolean').call([], properties);
    } else if (type.isDartCoreDouble || type.isDartCoreNum) {
      schemaExpression = refer('Schema.number').call([], properties);
    } else if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      properties['items'] = _jsonSchemaForType(itemType, null);
      schemaExpression = refer('Schema.list').call([], properties);
    } else if (type.isDartCoreMap) {
      final valueType = (type as InterfaceType).typeArguments[1];
      properties['additionalProperties'] = _jsonSchemaForType(valueType, null);
      schemaExpression = refer('Schema.object').call([], properties);
    } else {
      final typeName = type.getDisplayString(withNullability: false);
      if (typeName == 'DateTime') {
        properties['format'] = literalString('date-time');
        schemaExpression = refer('Schema.string').call([], properties);
      } else if (typeName.endsWith('Schema')) {
        final nestedBaseName = typeName.substring(0, typeName.length - 6);
        schemaExpression = refer('${nestedBaseName}Type.jsonSchema');
        if (properties.isNotEmpty) {
          final mergedProperties = {
            ...properties,
            'allOf': literalList([refer('${nestedBaseName}Type.jsonSchema')]),
          };
          return refer('Schema.object').call([], mergedProperties);
        }
      } else {
        schemaExpression = refer('Schema.any').call([], properties);
      }
    }
    
    return schemaExpression;
  }

  String _getJsonKey(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    for (final metadata in getter.metadata.annotations) {
      final annotation = metadata.computeConstantValue();
      if (annotation != null && _keyChecker.isExactlyType(annotation.type!)) {
        final reader = ConstantReader(annotation);
        return reader.read('name').literalValue as String? ?? fieldName!;
      }
    }
    return fieldName!;
  }

  Field _generateConstInstance(String baseName) {
    return Field((b) => b
      ..name = '${baseName}Type'
      ..modifier = FieldModifier.constant
      ..assignment = refer('${baseName}TypeFactory').constInstance([]).code);
  }
}

const _keyChecker = TypeChecker.fromUrl('package:genkit/schema.dart#Key');

extension on DartType {
  bool get isNullable {
    return getDisplayString(withNullability: true).endsWith('?');
  }
}
