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
import 'package:source_gen/source_gen.dart';

import '../schemantic.dart' hide Field;

class SchemaGenerator extends GeneratorForAnnotation<Schematic> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement || !element.isAbstract) {
      throw InvalidGenerationSourceError(
        '`@Schematic` can only be used on abstract classes.',
        element: element,
      );
    }

    final className = element.name;
    if (className == null) {
      throw InvalidGenerationSourceError(
        'Schema class must have a name.',
        element: element,
      );
    }

    String baseName;
    if (className.startsWith(r'$')) {
      baseName = className.substring(1);
    } else {
      throw InvalidGenerationSourceError(
        'Schema class names must start with "\$".',
        element: element,
      );
    }

    final helperClasses = _generateHelperClasses(baseName, element);
    final extensionType = _generateClass(baseName, element);
    final factory = _generateFactory(baseName, element, annotation);

    final libraryMembers = <Spec>[extensionType, ...helperClasses, factory];

    final library = Library((b) => b..body.addAll(libraryMembers));

    final emitter = DartEmitter(useNullSafetySyntax: true);
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('${library.accept(emitter)}');
  }

  RegExp alphaNumeric = RegExp(r'[^a-zA-Z0-9]');

  List<Class> _generateHelperClasses(String baseName, ClassElement element) {
    final classes = <Class>[];
    for (final field in element.fields) {
      if (field.getter == null) continue;
      final anyOfAnnotation = _anyOfChecker.firstAnnotationOf(
        field.getter!,
        throwOnUnresolved: false,
      );
      if (anyOfAnnotation == null) {
        continue;
      }
      var fieldName = field.name;
      if (fieldName == null) {
        throw ArgumentError('Field $field in $element has no name');
      }
      classes.add(
        Class((c) {
          c.name = baseName + _capitalize(fieldName);
          c.fields.add(
            Field(
              (f) => f
                ..name = 'value'
                ..type = refer('Object?')
                ..modifier = FieldModifier.final$,
            ),
          );

          final reader = ConstantReader(anyOfAnnotation);
          final types = reader.peek('anyOf')?.listValue ?? [];
          for (final typeObj in types) {
            final type = typeObj.toTypeValue();
            if (type != null) {
              final typeName = _convertSchemaType(type);
              final typeAsDartName = _typeToDartName(typeName);
              final ctorName = _decapitalize(typeAsDartName);

              c.constructors.add(
                Constructor(
                  (ctor) => ctor
                    ..name = ctorName
                    ..requiredParameters.add(
                      Parameter(
                        (p) => p
                          ..name = 'value'
                          ..toThis = !type.isSchema
                          ..type = refer(typeName),
                      ),
                    )
                    ..initializers.addAll(
                      type.isSchema
                          ? [
                              refer('value')
                                  .assign(
                                    refer('value').property('toJson').call([]),
                                  )
                                  .code,
                            ]
                          : [],
                    ),
                ),
              );
            }
          }
        }),
      );
    }
    return classes;
  }

  Class _generateClass(String baseName, ClassElement element) {
    // If `element` is a type annotated with `@Schematic`, then it should
    // inherit the `json` field.
    final isSubclass = _implementsAnnotatedType(element);
    return Class((b) {
      b.name = baseName;

      b.fields.add(
        Field((f) {
          f
            ..name = '_json'
            ..late = true
            ..modifier = FieldModifier.final$
            ..type = refer('Map<String, dynamic>');

          if (isSubclass) {
            f.annotations.add(refer('override'));
          }
        }),
      );

      b.fields.add(
        Field((f) {
          f
            ..static = true
            ..modifier = FieldModifier.constant
            ..name = r'$schema'
            ..type = refer('SchemanticType<$baseName>')
            ..assignment = refer(
              '_${baseName}TypeFactory',
            ).constInstance([]).code;
        }),
      );

      b.constructors.add(
        Constructor(
          (c) => c
            ..name = 'fromJson'
            ..factory = true
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = 'json'
                  ..type = refer('Map<String, dynamic>'),
              ),
            )
            ..body = refer(
              r'$schema',
            ).property('parse').call([refer('json')]).code,
        ),
      );

      b.constructors.add(
        Constructor(
          (c) => c
            ..name = '_'
            ..requiredParameters.add(
              Parameter(
                (p) => p
                  ..name = '_json'
                  ..toThis = true,
              ),
            ),
        ),
      );

      b.constructors.add(
        Constructor((c) {
          final params = <Parameter>[];
          final jsonMapEntries = <String>[];

          for (final field in element.fields) {
            final getter = field.getter;
            if (getter != null) {
              final paramName = getter.name;
              final anyOfAnnotation = _anyOfChecker.firstAnnotationOf(
                getter,
                throwOnUnresolved: false,
              );

              if (anyOfAnnotation != null) {
                // Handle AnyOf parameter using Helper Class
                final helperClassName = baseName + _capitalize(paramName!);
                final isNullable = getter.returnType.isNullable;
                params.add(
                  Parameter(
                    (p) => p
                      ..name = paramName
                      ..type = refer('$helperClassName${isNullable ? "?" : ""}')
                      ..named = true
                      ..required = !isNullable,
                  ),
                );

                final key = _getJsonKey(getter);
                // Assign helper.value to map
                if (isNullable) {
                  jsonMapEntries.add(
                    "if ($paramName != null) '$key': $paramName.value",
                  );
                } else {
                  jsonMapEntries.add("'$key': $paramName.value");
                }
              } else {
                // Standard Field Handling
                final paramType = refer(_convertSchemaType(getter.returnType));
                final isExtensionType = getter.returnType
                    .getDisplayString()
                    .replaceAll('?', '')
                    .isSchema;
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
                      .isSchema) {
                    final toJsonLambda = Method(
                      (m) => m
                        ..requiredParameters.add(Parameter((p) => p.name = 'e'))
                        ..body = refer('e').property('toJson').call([]).code,
                    ).closure;
                    valueExpression = refer(paramName!)
                        .maybeNullSafeProperty(isNullable, 'map')
                        .call([toJsonLambda])
                        .property('toList')
                        .call([]);
                  } else {
                    valueExpression = refer(paramName!);
                  }
                } else if (isExtensionType) {
                  valueExpression = refer(
                    paramName!,
                  ).maybeNullSafeProperty(isNullable, 'toJson').call([]);
                } else {
                  valueExpression = refer(paramName!);
                }
                final key = _getJsonKey(getter);
                final emitter = DartEmitter(useNullSafetySyntax: true);
                final valueString = valueExpression.accept(emitter);
                if (isNullable) {
                  jsonMapEntries.add("'$key': ?$valueString");
                } else {
                  jsonMapEntries.add("'$key': $valueString");
                }
              }
            }
          }
          c.optionalParameters.addAll(params);
          final mapLiteral = '{${jsonMapEntries.join(', ')}}';
          c.body = Code('_json = $mapLiteral;');
        }),
      );

      for (final interface in element.interfaces) {
        final interfaceName = interface.getDisplayString().replaceAll('?', '');
        if (interfaceName.isSchema) {
          final interfaceBaseName = _resolveBaseName(interfaceName);
          b.implements.add(refer(interfaceBaseName));
        }
      }

      for (final field in element.fields) {
        final getter = field.getter;
        if (getter != null) {
          final anyOfAnnotation = _anyOfChecker.firstAnnotationOf(
            getter,
            throwOnUnresolved: false,
          );

          if (anyOfAnnotation != null) {
            final types =
                ConstantReader(anyOfAnnotation).peek('anyOf')?.listValue ?? [];
            // Generate single setter for AnyOf
            b.methods.add(_generateAnyOfSetter(getter, types, baseName));
            b.methods.add(_generateAnyOfGetter(getter, types));
          } else {
            // Generate standard accessors
            b.methods.addAll([
              _generateGetter(getter),
              _generateSetter(getter),
            ]);
          }
        }
      }

      b.methods.add(
        Method(
          (m) => m
            ..annotations.add(refer('override'))
            ..name = 'toString'
            ..returns = refer('String')
            ..body = Code('return _json.toString();'),
        ),
      );

      b.methods.add(
        Method((m) {
          m
            ..name = 'toJson'
            ..returns = refer('Map<String, dynamic>')
            ..body = Code('return _json;');

          if (isSubclass) {
            m.annotations.add(refer('override'));
          }
        }),
      );
    });
  }

  Method _generateAnyOfGetter(
    PropertyAccessorElement mainGetter,
    List<DartObject> types,
  ) {
    return Method(
      (m) => m
        ..name = mainGetter.name
        ..docs.add(
          '// Possible return values are ${types.map((e) => e.toTypeValue()).map((e) => '`$e`').join(', ')}',
        )
        ..type = MethodType.getter
        ..returns = refer('Object?')
        ..body = Code("return _json['${_getJsonKey(mainGetter)}'] as Object?;"),
    );
  }

  Method _generateAnyOfSetter(
    PropertyAccessorElement mainGetter,
    List<DartObject> types,
    String baseName,
  ) {
    final mainName = mainGetter.name;
    final jsonFieldName = _getJsonKey(mainGetter);
    final helperClassName = baseName + _capitalize(mainName!);

    return Method(
      (m) => m
        ..name = mainName
        ..type = MethodType.setter
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'value'
              ..type = refer(helperClassName),
          ),
        )
        ..body = Code("_json['$jsonFieldName'] = value.value;"),
    );
  }

  String _typeToDartName(String typeName) =>
      (typeName.endsWith('?') ? '${typeName}OrNull' : typeName).replaceAll(
        alphaNumeric,
        '',
      );

  String _capitalize(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1);

  String _decapitalize(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toLowerCase() + s.substring(1);

  String _convertSchemaType(DartType type) {
    final typeName = type.getDisplayString();
    if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      if (itemType.isSchema) {
        final nestedBaseName = _resolveBaseName(itemType.element!.name!);
        final nullability = itemType.getDisplayString().endsWith('?')
            ? '?'
            : '';
        final listNullability = typeName.endsWith('?') ? '?' : '';
        return 'List<$nestedBaseName$nullability>$listNullability';
      }
    }
    if (type.isSchema) {
      final nestedBaseName = _resolveBaseName(type.element!.name!);
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
    if (returnType.isDartCoreDouble && !returnType.isNullable) {
      getterBody = "return (_json['$jsonFieldName'] as num).toDouble();";
    }

    if (returnType.isNullable) {
      if (returnType.isDartCoreDouble) {
        getterBody = "return (_json['$jsonFieldName'] as num?)?.toDouble();";
      } else {
        getterBody = "return _json['$jsonFieldName'] as $typeName;";
      }
      if (returnType.isDartCoreList) {
        final itemType = (returnType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
        final itemIsNullable = itemType.isNullable;
        if (itemType.isSchema) {
          final nestedBaseName = _resolveBaseName(itemType.element!.name!);
          if (itemIsNullable) {
            getterBody =
                "return (_json['$jsonFieldName'] as List?)?.map((e) => e == null ? null : $nestedBaseName(e as Map<String, dynamic>)).toList();";
          } else {
            getterBody =
                "return (_json['$jsonFieldName'] as List?)?.map((e) => $nestedBaseName.fromJson(e as Map<String, dynamic>)).toList();";
          }
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List?)?.cast<$itemTypeName>();";
        }
      } else if (returnType.isSchema) {
        final nestedBaseName = _resolveBaseName(returnType.element!.name!);
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : $nestedBaseName.fromJson(_json['$jsonFieldName'] as Map<String, dynamic>);";
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
      if (itemType.isSchema) {
        final nestedBaseName = _resolveBaseName(itemType.element!.name!);
        if (itemIsNullable) {
          getterBody =
              "return (_json['$jsonFieldName'] as List).map((e) => e == null ? null : $nestedBaseName.fromJson(e as Map<String, dynamic>)).toList();";
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List).map((e) => $nestedBaseName.fromJson(e as Map<String, dynamic>)).toList();";
        }
      } else {
        getterBody =
            "return (_json['$jsonFieldName'] as List).cast<$itemTypeName>();";
      }
    } else if (nonNullableTypeName == 'DateTime') {
      getterBody = "return DateTime.parse(_json['$jsonFieldName'] as String);";
    } else if (returnType.isSchema) {
      final nestedBaseName = _resolveBaseName(returnType.element!.name!);
      getterBody =
          "return $nestedBaseName.fromJson(_json['$jsonFieldName'] as Map<String, dynamic>);";
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
      if (nonNullableTypeName.isSchema) {
        valueExpression = 'value';
      } else if (nonNullableTypeName == 'DateTime') {
        valueExpression = 'value.toIso8601String()';
      } else if (paramType.isDartCoreList) {
        final itemType = (paramType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
        if (itemTypeName.isSchema) {
          valueExpression = 'value.toList()';
        }
      }
      setterBody =
          "if (value == null) { _json.remove('$jsonFieldName'); } else { _json['$jsonFieldName'] = $valueExpression; }";
    } else if (paramType.element is EnumElement) {
      setterBody = "_json['$jsonFieldName'] = value.name;";
    } else if (paramType.isDartCoreList) {
      final itemType = (paramType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      if (itemTypeName.isSchema) {
        setterBody = "_json['$jsonFieldName'] = value.toList();";
      }
    } else if (nonNullableTypeName == 'DateTime') {
      setterBody = "_json['$jsonFieldName'] = value.toIso8601String();";
    } else if (nonNullableTypeName.isSchema) {
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
              if (interfaceName.isSchema) {
                return _resolveBaseName(interfaceName);
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
              'if (${subtype}Type.jsonSchema(useRefs: true).validate(jsonMap)) { return $subtype.fromJson(jsonMap); }';
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
              ..body = Code(
                'return $baseName._(json as Map<String, dynamic>);',
              ),
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
      if (typeName.isSchema) {
        final nestedBaseName = _resolveBaseName(typeName);
        // We use the static field $schema for dependencies if possible,
        // but since dependencies list expects SchemanticType instances:
        // refer('${nestedBaseName}.\$schema')
        dependencies.add(refer('$nestedBaseName.\$schema'));
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
        if (typeName.isSchema) {
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
        final anyOfAnnotation = _anyOfChecker.firstAnnotationOf(
          getter,
          throwOnUnresolved: false,
        );

        if (anyOfAnnotation != null) {
          final types =
              ConstantReader(anyOfAnnotation).peek('anyOf')?.listValue ?? [];
          for (final typeObject in types) {
            final type = typeObject.toTypeValue();
            if (type != null) {
              processType(type);
            }
          }
        }

        properties[jsonFieldName] = _jsonSchemaForType(
          getter.returnType,
          keyAnnotation,
          anyOfAnnotation: anyOfAnnotation,
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
            if (interfaceName.isSchema) {
              addDependency(interfaceName);
              final nestedBaseName = _resolveBaseName(interfaceName);
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
        'required': literalList(required.map(literalString)),
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
    DartObject? anyOfAnnotation,
    bool useRefs = false,
  }) {
    final properties = <String, Expression>{};
    if (keyAnnotation != null) {
      final annotationType = keyAnnotation.type!;
      _validateAnnotation(annotationType, type);

      final reader = ConstantReader(keyAnnotation);
      properties.addAll(_readCommonProperties(reader));

      if (_stringFieldChecker.isAssignableFromType(annotationType)) {
        properties.addAll(_readStringProperties(reader));
      } else if (_integerFieldChecker.isAssignableFromType(annotationType) ||
          _numberFieldChecker.isAssignableFromType(annotationType)) {
        properties.addAll(_readNumberProperties(reader));
      }
    }

    if (anyOfAnnotation != null) {
      final types =
          ConstantReader(anyOfAnnotation).peek('anyOf')?.listValue ?? [];
      final schemas = types
          .map((t) => t.toTypeValue())
          .nonNulls
          .map((t) => _jsonSchemaForType(t, null, useRefs: useRefs))
          .toList();

      final namedArgs = <String, Expression>{'anyOf': literalList(schemas)};
      if (properties.containsKey('description')) {
        namedArgs['description'] = properties['description']!;
      }
      if (properties.containsKey('default')) {
        namedArgs['defaultValue'] = properties['default']!;
      }

      return refer('Schema.combined').call([], namedArgs);
    }

    final hasDefault = properties.containsKey('default');

    Expression schemaExpression;
    if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final enumValues = enumElement.fields
          .where((f) => f.isEnumConstant)
          .map((f) => f.name)
          .toList();
      properties[hasDefault ? 'enum' : 'enumValues'] = literalList(enumValues);
      if (hasDefault) {
        properties['type'] = literalString('string');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.string').call([], properties);
      }
    } else if (type.isDartCoreString) {
      if (hasDefault) {
        properties['type'] = literalString('string');
        if (properties.containsKey('enumValues')) {
          properties['enum'] = properties.remove('enumValues')!;
        }
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.string').call([], properties);
      }
    } else if (type.isDartCoreInt) {
      if (hasDefault) {
        properties['type'] = literalString('integer');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.integer').call([], properties);
      }
    } else if (type.isDartCoreBool) {
      if (hasDefault) {
        properties['type'] = literalString('boolean');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.boolean').call([], properties);
      }
    } else if (type.isDartCoreDouble || type.isDartCoreNum) {
      if (hasDefault) {
        properties['type'] = literalString('number');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.number').call([], properties);
      }
    } else if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      properties['items'] = _jsonSchemaForType(
        itemType,
        null,
        useRefs: useRefs,
      );
      if (hasDefault) {
        properties['type'] = literalString('array');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.list').call([], properties);
      }
    } else if (type.isDartCoreMap) {
      final valueType = (type as InterfaceType).typeArguments[1];
      properties['additionalProperties'] = _jsonSchemaForType(
        valueType,
        null,
        useRefs: useRefs,
      );
      if (hasDefault) {
        properties['type'] = literalString('object');
        schemaExpression = refer(
          'Schema.fromMap',
        ).call([literalMap(properties)]);
      } else {
        schemaExpression = refer('Schema.object').call([], properties);
      }
    } else {
      final typeName = type.getDisplayString().replaceAll('?', '');
      if (typeName == 'DateTime') {
        if (hasDefault) {
          properties['type'] = literalString('string');
          properties['format'] = literalString('date-time');
          schemaExpression = refer(
            'Schema.fromMap',
          ).call([literalMap(properties)]);
        } else {
          properties['format'] = literalString('date-time');
          schemaExpression = refer('Schema.string').call([], properties);
        }
      } else if (type.isSchema) {
        final nestedBaseName = _resolveBaseName(type.element!.name!);
        // If we are building the "definition" for the metadata, we want to use refs for children.
        if (useRefs) {
          final refMap = <Object, Object>{
            literalString(r'\$ref'): CodeExpression(
              Code("r'#/\$defs/$nestedBaseName'"),
            ),
          };
          // default is not allowed as sibling of $ref, so we don't add it here.
          // It will be added in the allOf wrapper below.
          schemaExpression = refer('Schema.fromMap').call([literalMap(refMap)]);
        } else {
          // For metadata generation, we can emit a direct call to the nested type's jsonSchema.
          schemaExpression = refer(
            '$nestedBaseName.\$schema.jsonSchema',
          ).call([]);
        }

        if (properties.isNotEmpty) {
          // If there are extra properties (like description or default), we need to wrap the ref/schema.
          // Wrap the schema in allOf to allow adding extra properties.
          if (useRefs) {
            // we already have schemaExpression as a ref.
            // Always wrap if we have properties (because we can't put them on the ref)
            final allOfList = [
              refer('Schema.fromMap').call([
                literalMap({
                  r'$ref': CodeExpression(Code("r'#/\$defs/$nestedBaseName'")),
                }),
              ]),
            ];

            final combinedMap = <Object, Object>{
              'allOf': literalList(allOfList),
            };
            if (properties.containsKey('description')) {
              combinedMap['description'] = properties['description']!;
            }
            if (properties.containsKey('default')) {
              combinedMap['default'] = properties['default']!;
            }

            return refer('Schema.fromMap').call([literalMap(combinedMap)]);
          } else {
            // Not using refs (inline).
            // SchemaExpression is types.jsonSchema().
            // Wrapper needed.
            final combinedMap = <Object, Object>{
              'allOf': literalList([schemaExpression]),
            };
            if (properties.containsKey('description')) {
              combinedMap['description'] = properties['description']!;
            }
            if (properties.containsKey('default')) {
              combinedMap['default'] = properties['default']!;
            }
            return refer('Schema.fromMap').call([literalMap(combinedMap)]);
          }
        }
      } else {
        if (hasDefault) {
          schemaExpression = refer(
            'Schema.fromMap',
          ).call([literalMap(properties)]);
        } else {
          schemaExpression = refer('Schema.any').call([], properties);
        }
      }
    }

    return schemaExpression;
  }

  void _validateAnnotation(DartType annotationType, DartType type) {
    if (_stringFieldChecker.isAssignableFromType(annotationType) &&
        !type.isDartCoreString &&
        !type.isDynamic) {
      throw InvalidGenerationSourceError(
        '@StringField can only be used on String types.',
        todo: 'Change the field type to String or use a different annotation.',
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
      throw InvalidGenerationSourceError(
        '@DoubleField can only be used on num, double, or int types.',
        todo:
            'Change the field type to num/double or use a different annotation.',
      );
    }
  }

  Map<String, Expression> _readCommonProperties(ConstantReader reader) {
    final properties = <String, Expression>{};
    final description = reader.peek('description')?.stringValue;
    if (description != null) {
      properties['description'] = literalString(description);
    }
    final defaultValue = reader.peek('defaultValue')?.literalValue;
    if (defaultValue != null) {
      properties['default'] = _toLiteral(defaultValue);
    }
    return properties;
  }

  Expression _toLiteral(Object? value) {
    if (value == null) return literalNull;
    if (value is String) return literalString(value);
    if (value is num) return literalNum(value);
    if (value is bool) return literalBool(value);
    if (value is List) {
      return literalList(value.map(_toLiteral));
    }
    if (value is Map) {
      return literalMap(
        value.map((k, v) => MapEntry(_toLiteral(k), _toLiteral(v))),
      );
    }
    if (value is DartObject) {
      return _toLiteral(ConstantReader(value).literalValue);
    }
    // Fallback or error if unsafe type
    throw ArgumentError.value(
      value,
      'value',
      'Not a supported literal type for Schema generation',
    );
  }

  Map<String, Expression> _readStringProperties(ConstantReader reader) {
    final properties = <String, Expression>{};
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
    return properties;
  }

  Map<String, Expression> _readNumberProperties(ConstantReader reader) {
    final properties = <String, Expression>{};

    void readNum(String key) {
      final value = reader.peek(key)?.literalValue;
      if (value is num) {
        properties[key] = literalNum(value);
      }
    }

    readNum('minimum');
    readNum('maximum');
    readNum('exclusiveMinimum');
    readNum('exclusiveMaximum');
    readNum('multipleOf');

    return properties;
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

  String _resolveBaseName(String s) {
    if (s.startsWith(r'$')) {
      return s.substring(1);
    }
    // This path should not be taken if call sites are guarded by `isSchema`.
    // Throwing an error makes the contract stricter.
    throw ArgumentError(
      'Invalid schema name "$s". Schema names must start with a "\$".',
    );
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
  'package:schemantic/schemantic.dart#DoubleField',
);

const _schematicChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#Schematic',
);

const _anyOfChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#AnyOf',
);

extension on DartType {
  bool get isNullable {
    return getDisplayString().endsWith('?');
  }

  bool get isDynamic {
    return getDisplayString() == 'dynamic';
  }

  bool get isSchema {
    return element?.name?.startsWith(r'$') ?? false;
  }
}

/// Returns `true` if the given [element] is a subclass of a type annotated with
/// [Schematic].
bool _implementsAnnotatedType(ClassElement element) =>
    _annotatedInterfaces(element).isNotEmpty;

Iterable<InterfaceType> _annotatedInterfaces(ClassElement element) {
  return element.interfaces.where(
    (s) => _schematicChecker.hasAnnotationOf(s.element),
  );
}

extension on String {
  bool get isSchema => startsWith(r'$');
}

extension on Expression {
  Expression maybeNullSafeProperty(bool nullable, String name) {
    if (nullable) {
      return nullSafeProperty(name);
    }
    return property(name);
  }
}
