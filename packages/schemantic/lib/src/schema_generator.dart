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

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';
import 'package:schemantic/schemantic.dart' hide Field;
import 'package:source_gen/source_gen.dart';
import 'schema_ast_parser.dart';

const _castableTypes = {
  'String',
  'int',
  'num',
  'bool',
  'double',
  'DateTime',
  'dynamic',
  'Object',
};

class SchemaGenerator extends GeneratorForAnnotation<Schematic> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is TopLevelVariableElement) {
      if (element.name == null) {
        throw InvalidGenerationSourceError(
          'Variable name cannot be null',
          element: element,
        );
      }
      return _generateFromSchemaInstance(element.name!, element, annotation);
    } else if (element is FieldElement) {
      if (element.name == null) {
        throw InvalidGenerationSourceError(
          'Field name cannot be null',
          element: element,
        );
      }
      return _generateFromSchemaInstance(element.name!, element, annotation);
    } else if (element is! ClassElement || !element.isAbstract) {
      throw InvalidGenerationSourceError(
        '`@Schematic` can only be used on abstract classes or const/final Schema variables.',
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
    final baseName = _stripSchemaSuffix(className);

    final extensionType = _generateExtensionType(baseName, element);
    final factory = _generateFactory(baseName, element, annotation);
    final constInstance = _generateConstInstance(baseName);

    final library = Library(
      (b) => b..body.addAll([extensionType, factory, constInstance]),
    );

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('${library.accept(emitter)}');
  }

  ExtensionType _generateExtensionType(String baseName, ClassElement element) {
    return ExtensionType((b) {
      b
        ..name = baseName
        ..implements.add(refer('Map<String, dynamic>'))
        ..representationDeclaration =
            (RepresentationDeclarationBuilder()
                  ..declaredRepresentationType = refer('Map<String, dynamic>')
                  ..name = '_json')
                .build();

      b.constructors.add(
        Constructor((c) {
          c.factory = true;
          c.name = 'from';
          final params = <Parameter>[];
          final jsonMapEntries = <String>[];
          for (final field in element.fields) {
            final getter = field.getter;
            if (getter != null) {
              final paramName = getter.name;
              final paramType = refer(_convertSchemaType(getter.returnType));
              final isExtensionType = getter.returnType
                  .getDisplayString()
                  .replaceAll('?', '')
                  .endsWith('Schema');
              final isNullable =
                  getter.returnType.isNullable ||
                  getter.returnType.isDartCoreObject ||
                  getter.returnType.isDynamic;
              params.add(
                Parameter(
                  (p) => p
                    ..name = paramName!
                    ..type = paramType
                    ..named = true
                    ..required = !isNullable,
                ),
              );
              Expression valueExpression;
              if (getter.returnType.isDartCoreList) {
                final itemType =
                    (getter.returnType as InterfaceType).typeArguments.first;
                if (itemType
                    .getDisplayString()
                    .replaceAll('?', '')
                    .endsWith('Schema')) {
                  final toJsonLambda = Method(
                    (m) => m
                      ..requiredParameters.add(Parameter((p) => p.name = 'e'))
                      ..body = refer('e').property('toJson').call([]).code,
                  ).closure;
                  if (getter.returnType.isNullable) {
                    valueExpression = refer(paramName!)
                        .property('map')
                        .call([toJsonLambda])
                        .property('toList')
                        .call([]);
                  } else {
                    valueExpression = refer(paramName!)
                        .property('map')
                        .call([toJsonLambda])
                        .property('toList')
                        .call([]);
                  }
                } else {
                  valueExpression = refer(paramName!);
                }
              } else if (isExtensionType) {
                valueExpression = refer(paramName!).property('toJson').call([]);
              } else {
                valueExpression = refer(paramName!);
              }
              final key = _getJsonKey(getter);
              final emitter = DartEmitter(useNullSafetySyntax: true);
              final valueString = valueExpression.accept(emitter);
              if (isNullable) {
                jsonMapEntries.add(
                  "if ($paramName != null) '$key': $valueString",
                );
              } else {
                jsonMapEntries.add("'$key': $valueString");
              }
            }
          }
          c.optionalParameters.addAll(params);
          final mapLiteral = '{${jsonMapEntries.join(', ')}}';
          c.body = refer(
            baseName,
          ).call([CodeExpression(Code(mapLiteral))]).returned.statement;
        }),
      );

      for (final interface in element.interfaces) {
        final interfaceName = interface.getDisplayString().replaceAll('?', '');
        if (interfaceName.endsWith('Schema')) {
          final interfaceBaseName = _stripSchemaSuffix(interfaceName);
          b.implements.add(refer(interfaceBaseName));
        }
      }

      for (final field in element.fields) {
        final getter = field.getter;
        if (getter != null) {
          b.methods.addAll([_generateGetter(getter), _generateSetter(getter)]);
        }
      }

      b.methods.add(
        Method(
          (m) => m
            ..name = 'toJson'
            ..returns = refer('Map<String, dynamic>')
            ..body = Code('return _json;'),
        ),
      );
    });
  }

  String _convertSchemaType(DartType type) {
    final typeName = type.getDisplayString();
    if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      if (itemTypeName.endsWith('Schema')) {
        final nestedBaseName = _stripSchemaSuffix(itemTypeName);
        final nullability = itemType.getDisplayString().endsWith('?')
            ? '?'
            : '';
        final listNullability = typeName.endsWith('?') ? '?' : '';
        return 'List<$nestedBaseName$nullability>$listNullability';
      }
    }
    final nonNullableTypeName = type.getDisplayString().replaceAll('?', '');
    if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName = _stripSchemaSuffix(nonNullableTypeName);
      final nullability = typeName.endsWith('?') ? '?' : '';
      return '$nestedBaseName$nullability';
    }
    return typeName;
  }

  Method _generateGetter(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    final jsonFieldName = _getJsonKey(getter);
    final returnType = getter.returnType;
    final typeName = returnType.getDisplayString();
    final convertedTypeName = _convertSchemaType(returnType);
    final nonNullableTypeName = returnType.getDisplayString().replaceAll(
      '?',
      '',
    );

    var getterBody = "return _json['$jsonFieldName'] as $typeName;";

    if (returnType.isNullable) {
      getterBody = "return _json['$jsonFieldName'] as $typeName;";
      if (returnType.isDartCoreList) {
        final itemType = (returnType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
        final itemIsNullable = itemType.isNullable;
        if (itemTypeName.endsWith('Schema')) {
          final nestedBaseName = _stripSchemaSuffix(itemTypeName);
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
        final nestedBaseName = _stripSchemaSuffix(nonNullableTypeName);
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : $nestedBaseName(_json['$jsonFieldName'] as Map<String, dynamic>);";
      } else if (nonNullableTypeName == 'DateTime') {
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : DateTime.parse(_json['$jsonFieldName'] as String);";
      }
    } else if (returnType.element is EnumElement) {
      final enumName = returnType.getDisplayString().replaceAll('?', '');
      getterBody =
          "return $enumName.values.byName(_json['$jsonFieldName'] as String);";
    } else if (returnType.isDartCoreList) {
      final itemType = (returnType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      final itemIsNullable = itemType.isNullable;
      if (itemTypeName.endsWith('Schema')) {
        final nestedBaseName = _stripSchemaSuffix(itemTypeName);
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
      getterBody = "return DateTime.parse(_json['$jsonFieldName'] as String);";
    } else if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName = _stripSchemaSuffix(nonNullableTypeName);
      getterBody =
          "return $nestedBaseName(_json['$jsonFieldName'] as Map<String, dynamic>);";
    }

    return Method(
      (b) => b
        ..type = MethodType.getter
        ..name = fieldName
        ..returns = refer(convertedTypeName)
        ..body = Code(getterBody),
    );
  }

  Method _generateSetter(PropertyAccessorElement getter) {
    final fieldName = getter.name;
    final jsonFieldName = _getJsonKey(getter);
    final paramType = getter.returnType;
    final convertedTypeName = _convertSchemaType(paramType);
    final nonNullableTypeName = paramType.getDisplayString().replaceAll(
      '?',
      '',
    );

    var setterBody = "_json['$jsonFieldName'] = value;";

    if (paramType.isNullable) {
      var valueExpression = 'value';
      if (nonNullableTypeName.endsWith('Schema')) {
        valueExpression = 'value';
      } else if (nonNullableTypeName == 'DateTime') {
        valueExpression = 'value.toIso8601String()';
      } else if (paramType.isDartCoreList) {
        final itemType = (paramType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
        final itemIsNullable = itemType.isNullable;
        if (itemTypeName.endsWith('Schema')) {
          if (itemIsNullable) {
            valueExpression = 'value.toList()';
          } else {
            valueExpression = 'value.toList()';
          }
        }
      }
      setterBody =
          "if (value == null) { _json.remove('$jsonFieldName'); } else { _json['$jsonFieldName'] = $valueExpression; }";
    } else if (paramType.element is EnumElement) {
      setterBody = "_json['$jsonFieldName'] = value.name;";
    } else if (paramType.isDartCoreList) {
      final itemType = (paramType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      final itemIsNullable = itemType.isNullable;
      if (itemTypeName.endsWith('Schema')) {
        if (itemIsNullable) {
          setterBody = "_json['$jsonFieldName'] = value.toList();";
        } else {
          setterBody = "_json['$jsonFieldName'] = value.toList();";
        }
      }
    } else if (nonNullableTypeName == 'DateTime') {
      setterBody = "_json['$jsonFieldName'] = value.toIso8601String();";
    } else if (nonNullableTypeName.endsWith('Schema')) {
      setterBody = "_json['$jsonFieldName'] = value;";
    }

    return Method(
      (b) => b
        ..type = MethodType.setter
        ..name = fieldName
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'value'
              ..type = refer(convertedTypeName),
          ),
        )
        ..body = Code(setterBody),
    );
  }

  Class _generateFactory(
    String baseName,
    ClassElement element,
    ConstantReader annotation,
  ) {
    return Class((b) {
      b
        ..name = '_${baseName}TypeFactory'
        ..extend = refer('SchemanticType<$baseName>')
        ..constructors.add(Constructor((c) => c..constant = true));

      if (element.fields.isEmpty && element.interfaces.isNotEmpty) {
        final subtypes = element.interfaces
            .map((i) {
              final interfaceName = i.getDisplayString().replaceAll('?', '');
              if (interfaceName.endsWith('Schema')) {
                return _stripSchemaSuffix(interfaceName);
              }
              return null;
            })
            .where((name) => name != null);

        var parseBody =
            'final Map<String, dynamic> jsonMap = json as Map<String, dynamic>;';
        for (final subtype in subtypes) {
          // This parse logic implies that we need to check validity.
          // Validate JSON structure using the schema before parsing.
          parseBody +=
              'if (${subtype}Type.jsonSchema(useRefs: true).validate(jsonMap)) { return $subtype(jsonMap); }';
        }
        parseBody += 'throw Exception("Invalid JSON for $baseName");';

        b.methods.add(
          Method(
            (m) => m
              ..annotations.add(refer('override'))
              ..name = 'parse'
              ..returns = refer(baseName)
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'json'
                    ..type = refer('Object?'),
                ),
              )
              ..body = Code(parseBody),
          ),
        );
      } else {
        b.methods.add(
          Method(
            (m) => m
              ..annotations.add(refer('override'))
              ..name = 'parse'
              ..returns = refer(baseName)
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'json'
                    ..type = refer('Object?'),
                ),
              )
              ..body = Code('return $baseName(json as Map<String, dynamic>);'),
          ),
        );
      }

      // Generate schemaMetadata
      b.methods.add(
        _generateSchemaMetadataGetter(baseName, element, annotation),
      );
    });
  }

  Method _generateSchemaMetadataGetter(
    String baseName,
    ClassElement element,
    ConstantReader annotation,
  ) {
    // 1. Calculate properties for the "flat" definition.
    // 2. Calculate dependencies.

    final properties = <String, Expression>{};
    final required = <String>[];
    final dependencies = <Expression>{};

    void addDependency(String typeName) {
      if (typeName.endsWith('Schema')) {
        final nestedBaseName = _stripSchemaSuffix(typeName);
        dependencies.add(refer('${nestedBaseName}Type'));
      }
    }

    void processType(DartType type) {
      if (type.isDartCoreList) {
        final itemType = (type as InterfaceType).typeArguments.first;
        processType(itemType);
      } else if (type.isDartCoreMap) {
        final valueType = (type as InterfaceType).typeArguments[1];
        processType(valueType);
      } else {
        final typeName = type.getDisplayString().replaceAll('?', '');
        if (typeName.endsWith('Schema')) {
          addDependency(typeName);
        }
      }
    }

    for (final field in element.fields) {
      final getter = field.getter;
      if (getter != null) {
        final jsonFieldName = _getJsonKey(getter);
        final keyAnnotation = _keyChecker.firstAnnotationOf(
          getter,
          throwOnUnresolved: false,
        );
        properties[jsonFieldName] = _jsonSchemaForType(
          getter.returnType,
          keyAnnotation,
          useRefs: true,
        );

        processType(getter.returnType);

        if (!getter.returnType.isNullable) {
          required.add(jsonFieldName);
        }
      }
    }

    Expression definitionExpression;
    final description = annotation.peek('description')?.stringValue;
    final descriptionExpr = description != null
        ? literalString(description)
        : null;

    if (element.fields.isEmpty && element.interfaces.isNotEmpty) {
      final subtypes = element.interfaces
          .map((i) {
            final interfaceName = i.getDisplayString().replaceAll('?', '');
            if (interfaceName.endsWith('Schema')) {
              addDependency(interfaceName);
              final nestedBaseName = _stripSchemaSuffix(interfaceName);
              return refer('Schema.fromMap').call([
                literalMap({
                  literalString(r'\$ref'): CodeExpression(
                    Code("r'#/\$defs/$nestedBaseName'"),
                  ),
                }),
              ]);
            }
            return null;
          })
          .where((name) => name != null)
          .toList()
          .cast<Expression>();

      // Wrapping anyOf in an object if we have a description, or just use anyOf.
      // json_schema_builder's Schema.anyOf doesn't seem to support description directly in constructor usually?
      // We'll use Schema.fromMap for full control if description is present, or just Schema.anyOf.
      if (descriptionExpr != null) {
        // Schema that is both anyOf and has description.
        // In JSON Schema: { "description": "...", "anyOf": [...] }
        definitionExpression = refer('Schema.fromMap').call([
          literalMap({
            literalString('description'): descriptionExpr,
            literalString('anyOf'): literalList(
              subtypes.map((s) => s.property('toJson').call([])).toList(),
            ),
          }),
        ]);
      } else {
        definitionExpression = refer(
          'Schema.anyOf',
        ).call([literalList(subtypes)]);
      }
    } else {
      final namedArgs = <String, Expression>{
        'properties': literalMap(properties),
        'required': literalList(required.map((r) => literalString(r))),
      };
      if (descriptionExpr != null) {
        namedArgs['description'] = descriptionExpr;
      }
      definitionExpression = refer('Schema.object').call([], namedArgs);
    }

    return Method(
      (b) => b
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'schemaMetadata'
        ..returns = refer('JsonSchemaMetadata')
        ..body = refer('JsonSchemaMetadata').call([], {
          'name': literalString(baseName),
          'definition': definitionExpression,
          'dependencies': literalList(dependencies.toList()),
        }).code,
    );
  }

  Expression _jsonSchemaForType(
    DartType type,
    DartObject? keyAnnotation, {
    bool useRefs = false,
  }) {
    final properties = <String, Expression>{};
    if (keyAnnotation != null) {
      // Validate annotation usage
      final annotationType = keyAnnotation.type!;
      if (_stringFieldChecker.isAssignableFromType(annotationType) &&
          !type.isDartCoreString &&
          !type.isDynamic) {
        // Allow dynamic? Maybe no. But let's be strict as requested.
        // Wait, enums might use StringField (if we allow custom enum schema constraints? probably not supported yet for enums via StringField)
        // For now, strict check.
        throw InvalidGenerationSourceError(
          '@StringField can only be used on String types.',
          todo:
              'Change the field type to String or use a different annotation.',
        );
      }
      if (_integerFieldChecker.isAssignableFromType(annotationType) &&
          !type.isDartCoreInt &&
          !type.isDynamic) {
        throw InvalidGenerationSourceError(
          '@IntegerField can only be used on int types.',
          todo: 'Change the field type to int or use a different annotation.',
        );
      }
      if (_numberFieldChecker.isAssignableFromType(annotationType) &&
          !type.isDartCoreDouble &&
          !type.isDartCoreNum &&
          !type.isDartCoreInt &&
          !type.isDynamic) {
        // NumberField can be used on double, num, or int (since int is num)
        throw InvalidGenerationSourceError(
          '@NumberField can only be used on num, double, or int types.',
          todo:
              'Change the field type to num/double or use a different annotation.',
        );
      }

      final reader = ConstantReader(keyAnnotation);
      final description = reader.read('description').literalValue as String?;
      if (description != null) {
        properties['description'] = literalString(description);
      }

      if (_stringFieldChecker.isAssignableFromType(annotationType)) {
        final minLength = reader.peek('minLength')?.intValue;
        final maxLength = reader.peek('maxLength')?.intValue;
        final pattern = reader.peek('pattern')?.stringValue;
        final format = reader.peek('format')?.stringValue;
        final enumValues = reader
            .peek('enumValues')
            ?.listValue
            .map((e) => e.toStringValue())
            .toList();

        if (minLength != null) properties['minLength'] = literalNum(minLength);
        if (maxLength != null) properties['maxLength'] = literalNum(maxLength);
        if (pattern != null) {
          properties['pattern'] = literalString(pattern, raw: true);
        }
        if (format != null) properties['format'] = literalString(format);
        if (enumValues != null) {
          properties['enumValues'] = literalList(enumValues);
        }
      } else if (_integerFieldChecker.isAssignableFromType(annotationType)) {
        final minimum = reader.peek('minimum')?.intValue;
        final maximum = reader.peek('maximum')?.intValue;
        final exclusiveMinimum = reader.peek('exclusiveMinimum')?.intValue;
        final exclusiveMaximum = reader.peek('exclusiveMaximum')?.intValue;
        final multipleOf = reader.peek('multipleOf')?.intValue;

        if (minimum != null) properties['minimum'] = literalNum(minimum);
        if (maximum != null) properties['maximum'] = literalNum(maximum);
        if (exclusiveMinimum != null) {
          properties['exclusiveMinimum'] = literalNum(exclusiveMinimum);
        }
        if (exclusiveMaximum != null) {
          properties['exclusiveMaximum'] = literalNum(exclusiveMaximum);
        }
        if (multipleOf != null) {
          properties['multipleOf'] = literalNum(multipleOf);
        }
      } else if (_numberFieldChecker.isAssignableFromType(annotationType)) {
        final minimum =
            reader.peek('minimum')?.doubleValue ??
            reader.peek('minimum')?.intValue;
        final maximum =
            reader.peek('maximum')?.doubleValue ??
            reader.peek('maximum')?.intValue;
        final exclusiveMinimum =
            reader.peek('exclusiveMinimum')?.doubleValue ??
            reader.peek('exclusiveMinimum')?.intValue;
        final exclusiveMaximum =
            reader.peek('exclusiveMaximum')?.doubleValue ??
            reader.peek('exclusiveMaximum')?.intValue;
        final multipleOf =
            reader.peek('multipleOf')?.doubleValue ??
            reader.peek('multipleOf')?.intValue;

        if (minimum != null) properties['minimum'] = literalNum(minimum);
        if (maximum != null) properties['maximum'] = literalNum(maximum);
        if (exclusiveMinimum != null) {
          properties['exclusiveMinimum'] = literalNum(exclusiveMinimum);
        }
        if (exclusiveMaximum != null) {
          properties['exclusiveMaximum'] = literalNum(exclusiveMaximum);
        }
        if (multipleOf != null) {
          properties['multipleOf'] = literalNum(multipleOf);
        }
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
      properties['items'] = _jsonSchemaForType(
        itemType,
        null,
        useRefs: useRefs,
      );
      schemaExpression = refer('Schema.list').call([], properties);
    } else if (type.isDartCoreMap) {
      final valueType = (type as InterfaceType).typeArguments[1];
      properties['additionalProperties'] = _jsonSchemaForType(
        valueType,
        null,
        useRefs: useRefs,
      );
      schemaExpression = refer('Schema.object').call([], properties);
    } else {
      final typeName = type.getDisplayString().replaceAll('?', '');
      if (typeName == 'DateTime') {
        properties['format'] = literalString('date-time');
        schemaExpression = refer('Schema.string').call([], properties);
      } else if (typeName.endsWith('Schema')) {
        final nestedBaseName = _stripSchemaSuffix(typeName);
        // If we are building the "definition" for the metadata, we want to use refs for children.
        // If we were building strict inline schema, we would call jsonSchema().
        // BUT here we are only building schemaDefinition (which is used for metadata).
        // So we should ALWAYS use refs here if it's a known Schematic type.
        // The old behavior "inline everything" is achieved by traversing schemaMetadata.

        if (useRefs) {
          schemaExpression = refer('Schema.fromMap').call([
            literalMap({
              literalString(r'\$ref'): CodeExpression(
                Code("r'#/\$defs/$nestedBaseName'"),
              ),
            }),
          ]);
        } else {
          // For metadata generation, we can emit a direct call to the nested type's jsonSchema.
          schemaExpression = refer('${nestedBaseName}Type.jsonSchema').call([]);
        }

        if (properties.isNotEmpty) {
          // If there are extra properties (like description), we need to wrap the ref/schema.
          // Wrap the schema in allOf to allow adding extra properties like description.
          final mergedProperties = {
            ...properties,
            'allOf': literalList([schemaExpression]),
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
      if (annotation != null &&
          _keyChecker.isAssignableFromType(annotation.type!)) {
        final reader = ConstantReader(annotation);
        return reader.read('name').literalValue as String? ?? fieldName!;
      }
    }
    return fieldName!;
  }

  Field _generateConstInstance(String baseName) {
    return Field(
      (b) => b
        ..name = '${baseName}Type'
        ..docs.add('// ignore: constant_identifier_names')
        ..modifier = FieldModifier.constant
        ..assignment = refer('_${baseName}TypeFactory').constInstance([]).code,
    );
  }

  Future<String> _generateFromSchemaInstance(
    String name,
    Element element,
    ConstantReader annotation,
  ) async {
    // 1. Try generic evaluation (works for const)
    SchemaInfo? schemaInfo;

    // Try constant evaluation first
    try {
      if (element is VariableElement) {
        final constValue = element.computeConstantValue();
        if (constValue != null) {
          schemaInfo = SchemaInfo.fromDartObject(constValue);
        }
      }
    } catch (e) {
      // Ignore, fallback to AST
    }

    // 2. Fallback to AST parsing
    if (schemaInfo == null) {
      try {
        schemaInfo = await SchemaParser.parseFromElement(element);
      } catch (e) {
        throw InvalidGenerationSourceError(
          'Could not parse Schema definition: $e',
          element: element,
        );
      }
    }

    return _generateFromSchemaInfo(name, schemaInfo);
  }

  String _generateFromSchemaInfo(String name, SchemaInfo schemaInfo) {
    final baseName = _capitalize(name);
    final specs = <Spec>[];

    // Generate Types
    final typeRef = _analyzeAndGenerateTypes(schemaInfo, baseName, specs);

    // Generate Type Factory
    final factoryClass = _generateFactoryForSchema(
      baseName,
      name,
      typeRef,
      specs,
    );

    // Generate constant instance
    final constInstance = Field(
      (b) => b
        ..name = '${name}Type'
        ..modifier = FieldModifier.constant
        ..assignment = refer('_${baseName}TypeFactory').constInstance([]).code,
    );

    final library = Library(
      (b) => b..body.addAll([...specs, factoryClass, constInstance]),
    );

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('${library.accept(emitter)}');
  }

  /// Analyzes the [schema] object and generates necessary types (e.g. Extension Types).
  /// Returns the [Reference] to the type that should be used.
  Reference _analyzeAndGenerateTypes(
    SchemaInfo schema,
    String name,
    List<Spec> specs,
  ) {
    // Check type
    final type = schema.type;
    final items = schema.items;
    final properties = schema.properties;
    final additionalProperties = schema.additionalProperties;

    // Default to true if not specified, unless properties are present?
    // In JSON Dictionary: "additionalProperties defaults to true"
    // In our `SchemaInfo`, null means unspecified.
    final isExplicitlyOpen = additionalProperties == true;

    if (properties != null && !isExplicitlyOpen) {
      // Generate Extension Type
      final fields = <String, Reference>{};

      properties.forEach((key, valueObject) {
        final propName = _toCamelCase(key);
        var fieldType = _analyzeAndGenerateTypes(
          valueObject,
          '$name${_capitalize(propName)}',
          specs,
        );

        // Apply nullability based on required list
        final isRequired = schema.required?.contains(key) ?? false;
        if (!isRequired) {
          if (fieldType is TypeReference) {
            fieldType = fieldType.rebuild((b) => b..isNullable = true);
          } else if (fieldType.symbol != null &&
              !fieldType.symbol!.endsWith('?')) {
            fieldType = refer('${fieldType.symbol}?');
          }
        }

        fields[key] = fieldType;
      });

      _generateExtensionTypeForSchema(name, fields, specs);
      return refer(name);
    } else if (items != null) {
      // Array
      final itemType = _analyzeAndGenerateTypes(items, '${name}Item', specs);
      return TypeReference(
        (b) => b
          ..symbol = 'List'
          ..types.add(itemType),
      );
    } else {
      // Primitives
      if (type == 'string') return refer('String');
      if (type == 'integer') return refer('int');
      if (type == 'number') return refer('num');
      if (type == 'boolean') return refer('bool');
      if (type == 'object') return refer('Map<String, dynamic>');
      if (type == 'array') return refer('List<dynamic>');
    }

    return refer('Map<String, dynamic>');
  }

  void _generateExtensionTypeForSchema(
    String name,
    Map<String, Reference> fields,
    List<Spec> specs,
  ) {
    final extType = ExtensionType((b) {
      b
        ..name = name
        ..implements.add(refer('Map<String, dynamic>'))
        ..representationDeclaration =
            (RepresentationDeclarationBuilder()
                  ..declaredRepresentationType = refer('Map<String, dynamic>')
                  ..name = '_json')
                .build();

      // Factory from
      final params = <Parameter>[];
      final bodyEntries = <String>[];

      fields.forEach((jsonKey, typeRef) {
        final fieldName = _toCamelCase(jsonKey);

        // Determine if parameter should be required
        bool isRequiredWrapper = true;
        if (typeRef is TypeReference) {
          isRequiredWrapper = !(typeRef.isNullable ?? false);
        } else if (typeRef.symbol != null) {
          isRequiredWrapper = !typeRef.symbol!.endsWith('?');
        }

        params.add(
          Parameter(
            (p) => p
              ..name = fieldName
              ..type = typeRef
              ..named = true
              ..required = isRequiredWrapper,
          ),
        );
        bodyEntries.add("'$jsonKey': $fieldName");
      });

      b.constructors.add(
        Constructor((c) {
          c.name = 'from';
          c.factory = true;
          c.optionalParameters.addAll(params);
          c.body = Code('return $name({${bodyEntries.join(', ')}});');
        }),
      );

      // Getters
      fields.forEach((jsonKey, typeRef) {
        final fieldName = _toCamelCase(jsonKey);

        // Helper to get cast for type
        final typeSymbol = typeRef.symbol;
        String body;

        if (typeRef is TypeReference &&
            typeRef.symbol == 'List' &&
            typeRef.types.isNotEmpty) {
          final itemType = typeRef.types.first;
          final itemSymbol = itemType.symbol;
          if (_castableTypes.contains(itemSymbol)) {
            body = "return (_json['$jsonKey'] as List).cast<$itemSymbol>();";
          } else if (itemSymbol == 'List') {
            // Nested list: (e as List).cast<T>()
            // We need to know inner type of the nested list.
            // itemType is List<T>. itemType.types.first is T.
            if (itemType is TypeReference && itemType.types.isNotEmpty) {
              final innerType = itemType.types.first.symbol;
              // Simple map for 2D arrays
              body =
                  "return (_json['$jsonKey'] as List).map((e) => (e as List).cast<$innerType>().toList()).toList();";
            } else {
              body =
                  "return (_json['$jsonKey'] as List).cast<List<dynamic>>();";
            }
          } else {
            // For Extension Types, map over the list to wrap elements.
            // This prevents runtime type errors with casts and ensures correct wrapping.
            body =
                "return (_json['$jsonKey'] as List).cast<Map<String, dynamic>>().map((e) => $itemSymbol(e)).toList();";
          }
        } else {
          // Handle nullable types
          final isNullable = typeSymbol?.endsWith('?') ?? false;
          final baseSymbol = isNullable
              ? typeSymbol!.substring(0, typeSymbol.length - 1)
              : typeSymbol!;

          if (_castableTypes.contains(baseSymbol) ||
              baseSymbol == 'dynamic' ||
              baseSymbol == 'Object') {
            body = "return _json['$jsonKey'] as $typeSymbol;";
          } else {
            // Extension type or class wrapper
            if (isNullable) {
              body =
                  "return _json['$jsonKey'] == null ? null : $baseSymbol(_json['$jsonKey'] as Map<String, dynamic>);";
            } else {
              body =
                  "return $baseSymbol(_json['$jsonKey'] as Map<String, dynamic>);";
            }
          }
        }

        b.methods.add(
          Method(
            (m) => m
              ..name = fieldName
              ..type = MethodType.getter
              ..returns = typeRef
              ..body = Code(body),
          ),
        );

        // setter
        b.methods.add(
          Method(
            (m) => m
              ..name = fieldName
              ..type = MethodType.setter
              ..requiredParameters.add(
                Parameter(
                  (p) => p
                    ..name = 'value'
                    ..type = typeRef,
                ),
              )
              ..body = Code("_json['$jsonKey'] = value;"),
          ),
        );
      });

      b.methods.add(
        Method(
          (m) => m
            ..name = 'toJson'
            ..returns = refer('Map<String, dynamic>')
            ..body = Code('return _json;'),
        ),
      );
    });

    specs.add(extType);
  }

  Class _generateFactoryForSchema(
    String baseName,
    String variableName,
    Reference typeRef,
    List<Spec> specs,
  ) {
    return Class((b) {
      b
        ..name = '_${baseName}TypeFactory'
        ..extend = TypeReference(
          (b) => b
            ..symbol = 'SchemanticType'
            ..types.add(typeRef),
        )
        ..constructors.add(Constructor((c) => c..constant = true));

      // parse
      b.methods.add(
        Method((m) {
          m
            ..annotations.add(refer('override'))
            ..name = 'parse'
            ..returns = typeRef
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'json'
                  ..type = refer('Object?'),
              ),
            );

          // Special handling for List types to ensure correct runtime casting.
          final symbol = typeRef.symbol ?? '';
          if (symbol.startsWith('List') ||
              (typeRef is TypeReference && typeRef.symbol == 'List')) {
            if (typeRef is TypeReference && typeRef.types.isNotEmpty) {
              final itemSymbol = typeRef.types.first.symbol;
              // Handle primitives and Maps directly via cast
              if (_castableTypes.contains(itemSymbol) ||
                  (itemSymbol?.startsWith('Map') ?? false)) {
                m.body = Code('return (json as List).cast<$itemSymbol>();');
              } else {
                // Assume extension type or class that accepts Map as primary representation
                m.body = Code(
                  'return (json as List).cast<Map<String, dynamic>>().map((e) => $itemSymbol(e)).toList();',
                );
              }
            } else {
              m.body = Code('return (json as List).cast<dynamic>();');
            }
          } else if (symbol.startsWith('Map') ||
              symbol == 'dynamic' ||
              symbol == 'Object') {
            m.body = Code('return json as $symbol;');
          } else {
            m.body = Code('return $symbol(json as Map<String, dynamic>);');
          }
        }),
      );

      // schemaMetadata
      b.methods.add(
        Method(
          (m) => m
            ..annotations.add(refer('override'))
            ..name = 'schemaMetadata'
            ..type = MethodType.getter
            ..returns = refer('JsonSchemaMetadata')
            ..body = refer('JsonSchemaMetadata').call([], {
              'name': literalString(baseName),
              'definition': refer(variableName),
              'dependencies': literalList([]),
            }).code,
        ),
      );
    });
  }

  String _stripSchemaSuffix(String s) {
    if (s.endsWith('Schema')) {
      return s.substring(0, s.length - 6);
    }
    return s;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _toCamelCase(String s) {
    if (s.isEmpty) return s;
    final parts = s.split('_');
    var result = parts[0];
    for (var i = 1; i < parts.length; i++) {
      result += _capitalize(parts[i]);
    }
    return result;
  }
}

const _keyChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#Field',
);

const _stringFieldChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#StringField',
);

const _integerFieldChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#IntegerField',
);

const _numberFieldChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#NumberField',
);

extension on DartType {
  bool get isNullable {
    return getDisplayString().endsWith('?');
  }

  bool get isDynamic {
    return getDisplayString() == 'dynamic';
  }
}
