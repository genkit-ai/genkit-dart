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
import 'package:schemantic/schemantic.dart';
import 'package:source_gen/source_gen.dart';

class SchemaGenerator extends GeneratorForAnnotation<Schematic> {
  @override
  String generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    if (element is! ClassElement || !element.isAbstract) {
      throw InvalidGenerationSourceError(
        '`@Schematic` can only be used on abstract classes.',
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
    final baseName = className.substring(0, className.length - 6);

    final extensionType = _generateExtensionType(baseName, element);
    final factory = _generateFactory(baseName, element);
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
                // don't need need to worry about nullability here, because
                // further down we check if the value is null and add
                // `if (paramName != null)`.
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
          final interfaceBaseName = interfaceName.substring(
            0,
            interfaceName.length - 6,
          );
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
        final nestedBaseName = itemTypeName.substring(
          0,
          itemTypeName.length - 6,
        );
        final nullability = itemType.getDisplayString().endsWith('?')
            ? '?'
            : '';
        final listNullability = typeName.endsWith('?') ? '?' : '';
        return 'List<$nestedBaseName$nullability>$listNullability';
      }
    }
    final nonNullableTypeName = type.getDisplayString().replaceAll('?', '');
    if (nonNullableTypeName.endsWith('Schema')) {
      final nestedBaseName = nonNullableTypeName.substring(
        0,
        nonNullableTypeName.length - 6,
      );
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
          final nestedBaseName = itemTypeName.substring(
            0,
            itemTypeName.length - 6,
          );
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
        final nestedBaseName = nonNullableTypeName.substring(
          0,
          nonNullableTypeName.length - 6,
        );
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
        final nestedBaseName = itemTypeName.substring(
          0,
          itemTypeName.length - 6,
        );
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
      final nestedBaseName = nonNullableTypeName.substring(
        0,
        nonNullableTypeName.length - 6,
      );
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

  Class _generateFactory(String baseName, ClassElement element) {
    return Class((b) {
      b
        ..name = '_${baseName}TypeFactory'
        ..extend = refer('JsonExtensionType<$baseName>')
        ..constructors.add(Constructor((c) => c..constant = true));

      if (element.fields.isEmpty && element.interfaces.isNotEmpty) {
        final subtypes = element.interfaces
            .map((i) {
              final interfaceName = i.getDisplayString().replaceAll('?', '');
              if (interfaceName.endsWith('Schema')) {
                return interfaceName.substring(0, interfaceName.length - 6);
              }
              return null;
            })
            .where((name) => name != null);

        var parseBody =
            'final Map<String, dynamic> jsonMap = json as Map<String, dynamic>;';
        for (final subtype in subtypes) {
          // This parse logic implies that we need to check validity.
          // Note: validate() might need useRefs argument if it deals with refs?
          // But validate() is on jsb.Schema, which doesn't take args.
          // We assume validate() works on expanded schema or we use the non-ref one for validation?
          // Actually, typical usage for validation is just checking structure.
          // We should use the default schema (useRefs=false or flattened) for validation if possible.
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
                    ..type = refer('Object'),
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
                    ..type = refer('Object'),
                ),
              )
              ..body = Code('return $baseName(json as Map<String, dynamic>);'),
          ),
        );
      }

      // Generate schemaMetadata
      b.methods.add(_generateSchemaMetadataGetter(baseName, element));
    });
  }

  Method _generateSchemaMetadataGetter(String baseName, ClassElement element) {
    // 1. Calculate properties for the "flat" definition.
    // 2. Calculate dependencies.

    final properties = <String, Expression>{};
    final required = <String>[];
    final dependencies = <Expression>{};

    void addDependency(String typeName) {
      if (typeName.endsWith('Schema')) {
        final nestedBaseName = typeName.substring(0, typeName.length - 6);
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
        // Note: _jsonSchemaForType is now called with `useRef: true` implicitly because we want
        // the definition to contain refs to children, NOT inlined children when we successfully resolve them.
        // Wait, current _jsonSchemaForType logic in strict inline mode (old Logic) would recurse.
        // We want _jsonSchemaForType to output refs if it sees a Schematic type.
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

    if (element.fields.isEmpty && element.interfaces.isNotEmpty) {
      final subtypes = element.interfaces
          .map((i) {
            final interfaceName = i.getDisplayString().replaceAll('?', '');
            if (interfaceName.endsWith('Schema')) {
              addDependency(interfaceName);
              final nestedBaseName = interfaceName.substring(
                0,
                interfaceName.length - 6,
              );
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

      definitionExpression = refer(
        'Schema.anyOf',
      ).call([literalList(subtypes)]);
    } else {
      definitionExpression = refer('Schema.object').call([], {
        'properties': literalMap(properties),
        'required': literalList(required.map((r) => literalString(r))),
      });
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
        final nestedBaseName = typeName.substring(0, typeName.length - 6);
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
          // Fallback for some reason? Actually, we should only be calling this for metadata generation now.
          // But if we wanted to support "inline" generation inside here, we would call .jsonSchema() on the type.
          // However, since we are generating code, we can't call .jsonSchema() at runtime here easily without emitting code.
          // We can emit `${nestedBaseName}Type.jsonSchema()`.
          schemaExpression = refer('${nestedBaseName}Type.jsonSchema').call([]);
        }

        if (properties.isNotEmpty) {
          // If there are extra properties (like description), we need to wrap the ref/schema.
          // For a ref, we usually can't add properties directly effectively in all JSON Schema versions,
          // but wrapping in allOf is safer.
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
      if (annotation != null && _keyChecker.isExactlyType(annotation.type!)) {
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
}

const _keyChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#Key',
);

extension on DartType {
  bool get isNullable {
    return getDisplayString().endsWith('?');
  }

  bool get isDynamic {
    return getDisplayString() == 'dynamic';
  }
}
