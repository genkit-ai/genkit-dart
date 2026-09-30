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

final class SchemaGenerator extends GeneratorForAnnotation<Schema> {
  @override
  Future<String> generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    if (element is! ClassElement || !element.isAbstract) {
      throw InvalidGenerationSourceError(
        '`@Schema` can only be used on abstract classes.',
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

  static final RegExp _nonAlphaNumeric = RegExp(r'[^a-zA-Z0-9]+');

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
          c.modifier = .final$;
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

  /// Extracts dartdoc comment lines from an [Element], returning them as
  /// a list of `///`-prefixed strings suitable for the `docs` field.
  List<String> _extractDocs(Element element) {
    final raw = element.documentationComment;
    if (raw == null || raw.isEmpty) return const [];
    // documentationComment returns lines like "/// foo" already.
    return raw.split('\n');
  }

  Class _generateClass(String baseName, ClassElement element) {
    // If `element` is a type annotated with `@Schema`, then it should
    // inherit the `json` field.
    final isSubclass = _implementsAnnotatedType(element);
    return Class((b) {
      b.name = baseName;
      b.modifier = .base;

      // Carry forward dartdoc from the abstract $ClassName.
      final classDocs = _extractDocs(element);
      if (classDocs.isNotEmpty) {
        b.docs.addAll(classDocs);
      }
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
            ..docs.addAll([
              '/// The JSON schema and type descriptor for [$baseName].',
            ])
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
            ..docs.addAll(['/// Creates a [$baseName] from a JSON map.'])
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
                } else if (getter.returnType.isDartCoreMap) {
                  final valueType =
                      (getter.returnType as InterfaceType).typeArguments[1];
                  if (valueType
                      .getDisplayString()
                      .replaceAll('?', '')
                      .isSchema) {
                    final isValNullable = valueType.isNullable;
                    final mapLambda = Method(
                      (m) => m
                        ..requiredParameters.add(Parameter((p) => p.name = 'k'))
                        ..requiredParameters.add(Parameter((p) => p.name = 'v'))
                        ..body = refer('MapEntry').newInstance([
                          refer('k'),
                          refer('v')
                              .maybeNullSafeProperty(isValNullable, 'toJson')
                              .call([]),
                        ]).code,
                    ).closure;
                    valueExpression = refer(paramName!)
                        .maybeNullSafeProperty(isNullable, 'map')
                        .call([mapLambda]);
                  } else {
                    valueExpression = refer(paramName!);
                  }
                } else if (isExtensionType) {
                  valueExpression = refer(
                    paramName!,
                  ).maybeNullSafeProperty(isNullable, 'toJson').call([]);
                } else if (getter.returnType.element is ExtensionTypeElement) {
                  final extElement =
                      getter.returnType.element as ExtensionTypeElement;
                  final repName = extElement.representation.name;
                  valueExpression = refer(
                    paramName!,
                  ).maybeNullSafeProperty(isNullable, repName!);
                } else if (getter.returnType.element is EnumElement) {
                  valueExpression = refer(
                    paramName!,
                  ).maybeNullSafeProperty(isNullable, 'name');
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
            ..docs.addAll(['/// Serializes this [$baseName] to a JSON map.'])
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
          '// Possible return values are '
          '${types.map((e) => e.toTypeValue()).map((e) => '`$e`').join(', ')}',
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

  static String _typeToDartName(String typeName) =>
      (typeName.endsWith('?') ? '${typeName}OrNull' : typeName).replaceAll(
        _nonAlphaNumeric,
        '',
      );

  static String _capitalize(String s) =>
      s.isEmpty ? s : s.substring(0, 1).toUpperCase() + s.substring(1);

  static String _decapitalize(String s) =>
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
    if (type.isDartCoreMap) {
      final keyType = (type as InterfaceType).typeArguments[0];
      final valueType = type.typeArguments[1];
      if (valueType.isSchema) {
        final keyTypeName = keyType.getDisplayString();
        final nestedBaseName = _resolveBaseName(valueType.element!.name!);
        final nullability = valueType.getDisplayString().endsWith('?')
            ? '?'
            : '';
        final mapNullability = typeName.endsWith('?') ? '?' : '';
        return 'Map<$keyTypeName, $nestedBaseName$nullability>$mapNullability';
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
                "return (_json['$jsonFieldName'] as List?)"
                '?.map((e) => e == null ? null : '
                '$nestedBaseName(e as Map<String, dynamic>)).toList();';
          } else {
            getterBody =
                "return (_json['$jsonFieldName'] as List?)"
                '?.map((e) => '
                '$nestedBaseName.fromJson(e as Map<String, dynamic>))'
                '.toList();';
          }
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List?)"
              '?.cast<$itemTypeName>();';
        }
      } else if (returnType.isDartCoreMap) {
        final keyTypeName = (returnType as InterfaceType).typeArguments[0]
            .getDisplayString()
            .replaceAll('?', '');
        final valueType = returnType.typeArguments[1];
        final valueTypeName = valueType.getDisplayString().replaceAll('?', '');
        final valueIsNullable = valueType.isNullable;
        if (valueType.isSchema) {
          final nestedBaseName = _resolveBaseName(valueType.element!.name!);
          if (valueIsNullable) {
            getterBody =
                "return (_json['$jsonFieldName'] as Map?)"
                '?.map<$keyTypeName, $nestedBaseName?>((k, v) => '
                'MapEntry(k as $keyTypeName, v == null ? null : '
                '$nestedBaseName.fromJson(v as Map<String, dynamic>)));';
          } else {
            getterBody =
                "return (_json['$jsonFieldName'] as Map?)"
                '?.map<$keyTypeName, $nestedBaseName>((k, v) => '
                'MapEntry(k as $keyTypeName, '
                '$nestedBaseName.fromJson(v as Map<String, dynamic>)));';
          }
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as Map?)"
              '?.cast<$keyTypeName, $valueTypeName>();';
        }
      } else if (returnType.isSchema) {
        final nestedBaseName = _resolveBaseName(returnType.element!.name!);
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : "
            "$nestedBaseName.fromJson(_json['$jsonFieldName'] "
            'as Map<String, dynamic>);';
      } else if (nonNullableTypeName == 'DateTime') {
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : "
            "DateTime.parse(_json['$jsonFieldName'] as String);";
      } else if (returnType.element is EnumElement) {
        final enumName = returnType.getDisplayString().replaceAll('?', '');
        getterBody =
            "return _json['$jsonFieldName'] == null ? null : "
            "$enumName.values.byName(_json['$jsonFieldName'] as String);";
      }
    } else if (returnType.element is EnumElement) {
      final enumName = returnType.getDisplayString().replaceAll('?', '');
      getterBody =
          "return $enumName.values.byName(_json['$jsonFieldName'] as String);";
    } else if (returnType.element is ExtensionTypeElement) {
      final extElement = returnType.element as ExtensionTypeElement;
      final repTypeName = extElement.representation.type
          .getDisplayString()
          .replaceAll('?', '');
      final extTypeName = returnType.getDisplayString().replaceAll('?', '');
      if (returnType.isNullable) {
        getterBody =
            "final value = _json['$jsonFieldName'] as $repTypeName?;\n"
            'return value == null ? null : $extTypeName(value);';
      } else {
        getterBody =
            "final value = _json['$jsonFieldName'] as $repTypeName;\n"
            'return $extTypeName(value);';
      }
    } else if (returnType.isDartCoreList) {
      final itemType = (returnType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      final itemIsNullable = itemType.isNullable;
      if (itemType.isSchema) {
        final nestedBaseName = _resolveBaseName(itemType.element!.name!);
        if (itemIsNullable) {
          getterBody =
              "return (_json['$jsonFieldName'] as List).map((e) => e == null ? "
              'null : $nestedBaseName.fromJson(e as Map<String, dynamic>))'
              '.toList();';
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as List)"
              '.map((e) => $nestedBaseName.fromJson(e as Map<String, dynamic>))'
              '.toList();';
        }
      } else {
        getterBody =
            "return (_json['$jsonFieldName'] as List).cast<$itemTypeName>();";
      }
    } else if (returnType.isDartCoreMap) {
      final keyTypeName = (returnType as InterfaceType).typeArguments[0]
          .getDisplayString()
          .replaceAll('?', '');
      final valueType = returnType.typeArguments[1];
      final valueTypeName = valueType.getDisplayString().replaceAll('?', '');
      final valueIsNullable = valueType.isNullable;
      if (valueType.isSchema) {
        final nestedBaseName = _resolveBaseName(valueType.element!.name!);
        if (valueIsNullable) {
          getterBody =
              "return (_json['$jsonFieldName'] as Map)"
              '.map<$keyTypeName, $nestedBaseName?>((k, v) => '
              'MapEntry(k as $keyTypeName, v == null ? null : '
              '$nestedBaseName.fromJson(v as Map<String, dynamic>)));';
        } else {
          getterBody =
              "return (_json['$jsonFieldName'] as Map)"
              '.map<$keyTypeName, $nestedBaseName>((k, v) => '
              'MapEntry(k as $keyTypeName, '
              '$nestedBaseName.fromJson(v as Map<String, dynamic>)));';
        }
      } else {
        getterBody =
            "return (_json['$jsonFieldName'] as Map)"
            '.cast<$keyTypeName, $valueTypeName>();';
      }
    } else if (nonNullableTypeName == 'DateTime') {
      getterBody = "return DateTime.parse(_json['$jsonFieldName'] as String);";
    } else if (returnType.isSchema) {
      final nestedBaseName = _resolveBaseName(returnType.element!.name!);
      getterBody =
          'return $nestedBaseName.fromJson('
          "_json['$jsonFieldName'] as Map<String, dynamic>);";
    }

    // Carry forward dartdoc from the abstract getter.
    final getterDocs = _extractDocs(getter);

    return Method(
      (b) => b
        ..docs.addAll(getterDocs)
        ..type = MethodType.getter
        ..name = fieldName
        ..returns = refer(convertedTypeName)
        ..body = Code(getterBody),
    );
  }

  Method _generateSetter(PropertyAccessorElement getter) {
    // Carry forward dartdoc from the abstract getter to its setter.
    final setterDocs = _extractDocs(getter);
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
        // Normalize the nested model to plain JSON, mirroring the constructor.
        valueExpression = 'value.toJson()';
      } else if (nonNullableTypeName == 'DateTime') {
        valueExpression = 'value.toIso8601String()';
      } else if (paramType.isDartCoreList) {
        final itemType = (paramType as InterfaceType).typeArguments.first;
        final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
        if (itemTypeName.isSchema) {
          // Normalize each nested model in the list to plain JSON so that
          // toJson() (and any later re-parse) sees Maps, not model instances.
          final itemAccess = itemType.isNullable ? 'e?.toJson()' : 'e.toJson()';
          valueExpression = 'value.map((e) => $itemAccess).toList()';
        }
      } else if (paramType.isDartCoreMap) {
        final valueType = (paramType as InterfaceType).typeArguments[1];
        final valueTypeName = valueType.getDisplayString().replaceAll('?', '');
        if (valueTypeName.isSchema) {
          // Normalize each nested model value in the map to plain JSON.
          final valAccess = valueType.isNullable ? 'v?.toJson()' : 'v.toJson()';
          valueExpression = 'value.map((k, v) => MapEntry(k, $valAccess))';
        }
      } else if (paramType.element is EnumElement) {
        valueExpression = 'value.name';
      }
      setterBody =
          "if (value == null) { _json.remove('$jsonFieldName'); } "
          "else { _json['$jsonFieldName'] = $valueExpression; }";
    } else if (paramType.element is EnumElement) {
      setterBody = "_json['$jsonFieldName'] = value.name;";
    } else if (paramType.element is ExtensionTypeElement) {
      final extElement = paramType.element as ExtensionTypeElement;
      final repName = extElement.representation.name;
      setterBody = "_json['$jsonFieldName'] = value.${repName!};";
    } else if (paramType.isDartCoreList) {
      final itemType = (paramType as InterfaceType).typeArguments.first;
      final itemTypeName = itemType.getDisplayString().replaceAll('?', '');
      if (itemTypeName.isSchema) {
        // Normalize each nested model in the list to plain JSON so that
        // toJson() (and any later re-parse) sees Maps, not model instances.
        final itemAccess = itemType.isNullable ? 'e?.toJson()' : 'e.toJson()';
        setterBody =
            "_json['$jsonFieldName'] = value.map((e) => $itemAccess).toList();";
      }
    } else if (paramType.isDartCoreMap) {
      final valueType = (paramType as InterfaceType).typeArguments[1];
      final valueTypeName = valueType.getDisplayString().replaceAll('?', '');
      if (valueTypeName.isSchema) {
        // Normalize each nested model value in the map to plain JSON.
        final valAccess = valueType.isNullable ? 'v?.toJson()' : 'v.toJson()';
        setterBody =
            "_json['$jsonFieldName'] = "
            'value.map((k, v) => MapEntry(k, $valAccess));';
      }
    } else if (nonNullableTypeName == 'DateTime') {
      setterBody = "_json['$jsonFieldName'] = value.toIso8601String();";
    } else if (nonNullableTypeName.isSchema) {
      setterBody = "_json['$jsonFieldName'] = value.toJson();";
    }

    return Method(
      (b) => b
        ..docs.addAll(setterDocs)
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
        ..modifier = .base
        ..extend = refer('SchemanticType<$baseName>')
        ..constructors.add(Constructor((c) => c..constant = true));

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
            ..body = Code('return $baseName._(json as Map<String, dynamic>);'),
        ),
      );

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

    if (element.fields.isEmpty && _implementsAnnotatedType(element)) {
      throw InvalidGenerationSourceError(
        'A @Schema class with no fields cannot be a union of the schema '
        'types it implements. Declare fields on it, or model the union '
        'as a field annotated with @AnyOf.',
        element: element,
      );
    }

    final description = annotation.peek('description')?.stringValue;
    final additionalProperties = annotation
        .peek('additionalProperties')
        ?.boolValue;
    final definition = _schemaLiteral({
      'type': literalString('object'),
      if (description != null) 'description': literalString(description),
      'properties': _jsonMapLiteral(properties),
      if (required.isNotEmpty)
        'required': literalList(required.map(literalString)),
      if (additionalProperties != null)
        'additionalProperties': literalBool(additionalProperties),
    });

    return Method(
      (b) => b
        ..annotations.add(refer('override'))
        ..type = MethodType.getter
        ..name = 'schemaMetadata'
        ..returns = refer('JsonSchemaMetadata')
        ..body = refer('JsonSchemaMetadata').call([], {
          'name': literalString(baseName),
          'definition': definition,
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
    // JSON Schema keywords read from the field annotation, keyed by their JSON
    // names (`default`, `enum`, ...).
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
      return _schemaLiteral({
        'description': ?properties['description'],
        'default': ?properties['default'],
        'anyOf': literalList(schemas),
      });
    }

    if (type.element is EnumElement) {
      final enumElement = type.element as EnumElement;
      final enumValues = enumElement.fields
          .where((f) => f.isEnumConstant)
          .map((f) => f.name)
          .toList();
      return _schemaLiteral({
        'type': literalString('string'),
        ...properties,
        'enum': literalList(enumValues),
      });
    }
    if (type.isDartCoreString) {
      return _schemaLiteral({'type': literalString('string'), ...properties});
    }
    if (type.isDartCoreInt) {
      return _schemaLiteral({'type': literalString('integer'), ...properties});
    }
    if (type.isDartCoreBool) {
      return _schemaLiteral({'type': literalString('boolean'), ...properties});
    }
    if (type.isDartCoreDouble || type.isDartCoreNum) {
      return _schemaLiteral({'type': literalString('number'), ...properties});
    }
    if (type.isDartCoreList) {
      final itemType = (type as InterfaceType).typeArguments.first;
      return _schemaLiteral({
        'type': literalString('array'),
        ...properties,
        'items': _jsonSchemaForType(itemType, null, useRefs: useRefs),
      });
    }
    if (type.isDartCoreMap) {
      final valueType = (type as InterfaceType).typeArguments[1];
      return _schemaLiteral({
        'type': literalString('object'),
        ...properties,
        'additionalProperties': _jsonSchemaForType(
          valueType,
          null,
          useRefs: useRefs,
        ),
      });
    }

    final typeName = type.getDisplayString().replaceAll('?', '');
    if (typeName == 'DateTime') {
      return _schemaLiteral({
        'type': literalString('string'),
        ...properties,
        'format': literalString('date-time'),
      });
    }
    if (type.isSchema) {
      final nestedBaseName = _resolveBaseName(type.element!.name!);
      // In the metadata definition, nested schema types are `$ref`s into the
      // `$defs` that schemantic assembles from `dependencies`.
      final schemaExpression = useRefs
          ? _schemaLiteral({r'$ref': _refLiteral(nestedBaseName)})
          : refer('$nestedBaseName.\$schema.jsonSchema').call([]);
      if (properties.isEmpty) return schemaExpression;
      // Keywords such as `description` and `default` are not allowed as
      // siblings of `$ref`, so wrap the reference in `allOf`.
      return _schemaLiteral({
        'allOf': literalList([schemaExpression]),
        ...properties,
      });
    }
    return _schemaLiteral(properties);
  }

  /// A JSON Schema map literal, with keys in [_schemaKeyOrder].
  Expression _schemaLiteral(Map<String, Expression> entries) {
    final ordered = <String, Expression>{
      for (final key in _schemaKeyOrder)
        if (entries.containsKey(key)) key: entries[key]!,
      for (final entry in entries.entries)
        if (!_schemaKeyOrder.contains(entry.key)) entry.key: entry.value,
    };
    return _jsonMapLiteral({
      for (final entry in ordered.entries)
        _schemaKeyLiteral(entry.key): entry.value,
    });
  }

  /// A `<String, Object?>{...}` literal. Typed explicitly because an untyped
  /// literal infers from its values (`{'type': 'string'}` would be a
  /// `Map<String, String>`, and `{}` a `Map<dynamic, dynamic>`), which breaks
  /// consumers that write into or type-test schema maps.
  Expression _jsonMapLiteral(Map<Object, Expression> entries) =>
      literalMap(entries, refer('String'), refer('Object?'));

  /// Keys containing `$` are emitted as raw strings to avoid interpolation.
  Expression _schemaKeyLiteral(String key) =>
      key.contains(r'$') ? CodeExpression(Code("r'$key'")) : literalString(key);

  Expression _refLiteral(String baseName) =>
      CodeExpression(Code("r'#/\$defs/$baseName'"));

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
            'Change the field type to a number type '
            'or use a different annotation.',
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
    if (enumValues != null) properties['enum'] = literalList(enumValues);
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

/// Key order for generated schema literals. Mirrors the order in which
/// `package:json_schema_builder`'s typed constructors (which the generator
/// used to emit) wrote keys, so schemas serialize the same as before.
const _schemaKeyOrder = [
  'type',
  'title',
  'description',
  'enum',
  'const',
  'default',
  r'$ref',
  'allOf',
  'anyOf',
  // Strings.
  'minLength',
  'maxLength',
  'pattern',
  'format',
  // Numbers.
  'minimum',
  'maximum',
  'exclusiveMinimum',
  'exclusiveMaximum',
  'multipleOf',
  // Arrays.
  'items',
  // Objects.
  'properties',
  'required',
  'additionalProperties',
];

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

const _schemaChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#Schema',
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
/// [Schema].
bool _implementsAnnotatedType(ClassElement element) =>
    _annotatedInterfaces(element).isNotEmpty;

Iterable<InterfaceType> _annotatedInterfaces(ClassElement element) {
  return element.interfaces.where(
    (s) => _schemaChecker.hasAnnotationOf(s.element),
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
