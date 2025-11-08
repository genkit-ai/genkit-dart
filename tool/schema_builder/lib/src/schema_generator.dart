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
    final returnType = getter.returnType;
    final typeName = returnType.getDisplayString(withNullability: true);
    final convertedTypeName = _convertSchemaType(returnType);
    final nonNullableTypeName =
        returnType.getDisplayString(withNullability: false);

    var getterBody = "return _json['$fieldName'] as $typeName;";

    if (returnType.isNullable) {
      getterBody = "return _json['$fieldName'] as $typeName;";
      if (returnType.isDartCoreList) {
        final itemType = (returnType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString(withNullability: false);
        if (itemTypeName.endsWith('Schema')) {
          final nestedBaseName =
              itemTypeName.substring(0, itemTypeName.length - 6);
          getterBody =
              "return (_json['$fieldName'] as List?)?.map((e) => $nestedBaseName(e as Map<String, dynamic>)).toList();";
        } else {
          getterBody =
              "return (_json['$fieldName'] as List?)?.cast<$itemTypeName>();";
        }
      } else if (nonNullableTypeName.endsWith('Schema')) {
        final nestedBaseName =
            nonNullableTypeName.substring(0, nonNullableTypeName.length - 6);
        getterBody =
            "return _json['$fieldName'] == null ? null : $nestedBaseName(_json['$fieldName'] as Map<String, dynamic>);";
      }
    } else if (returnType.element is EnumElement) {
      final enumName = returnType.getDisplayString(withNullability: false);
      getterBody =
          "return $enumName.values.byName(_json['$fieldName'] as String);";
    } else if (returnType.isDartCoreList) {
      final itemType = (returnType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString(withNullability: false);
      if (itemTypeName.endsWith('Schema')) {
        final nestedBaseName =
            itemTypeName.substring(0, itemTypeName.length - 6);
        getterBody =
            "return (_json['$fieldName'] as List).map((e) => $nestedBaseName(e as Map<String, dynamic>)).toList();";
      } else {
        getterBody =
            "return (_json['$fieldName'] as List).cast<$itemTypeName>();";
      }
    } else if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName =
          nonNullableTypeName.substring(0, nonNullableTypeName.length - 6);
      getterBody =
          "return $nestedBaseName(_json['$fieldName'] as Map<String, dynamic>);";
    }

    return Method((b) => b
      ..type = MethodType.getter
      ..name = fieldName
      ..returns = refer(convertedTypeName)
      ..body = Code(getterBody));
  }

  Method _generateSetter(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    final paramType = getter.returnType;
    final convertedTypeName = _convertSchemaType(paramType);
    final nonNullableTypeName =
        paramType.getDisplayString(withNullability: false);

    var setterBody = "_json['$fieldName'] = value;";

    if (paramType.isNullable) {
      var valueExpression = 'value';
      if (nonNullableTypeName.endsWith('Schema')) {
        valueExpression = '(value as dynamic)?._json';
      } else if (paramType.isDartCoreList) {
        final itemType = (paramType as InterfaceType).typeArguments.first;
        if (itemType
            .getDisplayString(withNullability: false)
            .endsWith('Schema')) {
          valueExpression = 'value?.map((e) => (e as dynamic)._json).toList()';
        }
      }
      setterBody =
          "if (value == null) { _json.remove('$fieldName'); } else { _json['$fieldName'] = $valueExpression; }";
    } else if (paramType.element is EnumElement) {
      setterBody = "_json['$fieldName'] = value.name;";
    } else if (paramType.isDartCoreList) {
      final itemType = (paramType as InterfaceType).typeArguments.first;
      if (itemType
          .getDisplayString(withNullability: false)
          .endsWith('Schema')) {
        setterBody =
            "_json['$fieldName'] = value.map((e) => (e as dynamic)._json).toList();";
      }
    } else if (nonNullableTypeName.endsWith('Schema')) {
      setterBody = "_json['$fieldName'] = (value as dynamic)._json;";
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
        final fieldName = getter.name;
        properties[fieldName!] = _jsonSchemaForType(getter.returnType);
        if (!getter.returnType.isNullable) {
          required.add(fieldName);
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

  Expression _jsonSchemaForType(DartType type) {
    if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final enumValues = enumElement.fields
          .where((f) => f.isEnumConstant)
          .map((f) => f.name)
          .toList();
      return refer('Schema.string').call([], {
        'enumValues': literalList(enumValues),
      });
    }
    if (type.isDartCoreString) {
      return refer('Schema.string').call([]);
    }
    if (type.isDartCoreInt) {
      return refer('Schema.integer').call([]);
    }
    if (type.isDartCoreBool) {
      return refer('Schema.boolean').call([]);
    }
    if (type.isDartCoreDouble || type.isDartCoreNum) {
      return refer('Schema.number').call([]);
    }
    if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      return refer('Schema.list').call([], {
        'items': _jsonSchemaForType(itemType),
      });
    }
    final typeName = type.getDisplayString(withNullability: false);
    if (typeName.endsWith('Schema')) {
      final nestedBaseName = typeName.substring(0, typeName.length - 6);
      return refer('${nestedBaseName}Type.jsonSchema');
    }
    return refer('Schema.any').call([]);
  }

  Field _generateConstInstance(String baseName) {
    return Field((b) => b
      ..name = '${baseName}Type'
      ..modifier = FieldModifier.constant
      ..assignment = refer('${baseName}TypeFactory').constInstance([]).code);
  }
}

extension on DartType {
  bool get isNullable {
    return getDisplayString(withNullability: true).endsWith('?');
  }
}
