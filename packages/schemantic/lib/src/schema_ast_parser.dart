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

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:source_gen/source_gen.dart';

/// Intermediate representation of a Schema for generation purposes.
class SchemaInfo {
  final String? type;
  final SchemaInfo? items;
  final Map<String, SchemaInfo>? properties;
  final bool? additionalProperties;
  final String? definitionName;
  final List<String>? required;
  final String? description;

  SchemaInfo({
    this.type,
    this.items,
    this.properties,
    this.additionalProperties,
    this.definitionName,
    this.required,
    this.description,
  });

  factory SchemaInfo.fromDartObject(DartObject object) {
    var type = object.getField('type')?.toStringValue();

    // items
    SchemaInfo? items;
    final itemsObj = object.getField('items');
    if (itemsObj != null && !itemsObj.isNull) {
      items = SchemaInfo.fromDartObject(itemsObj);
    }

    // properties
    Map<String, SchemaInfo>? properties;
    final propsObj = object.getField('properties')?.toMapValue();
    if (propsObj != null) {
      properties = {};
      propsObj.forEach((k, v) {
        final key = k?.toStringValue();
        if (key != null && v != null) {
          properties![key] = SchemaInfo.fromDartObject(v);
        }
      });
    }

    // additionalProperties
    bool? additionalProperties;
    final apObj = object.getField('additionalProperties');
    if (apObj != null && !apObj.isNull) {
      additionalProperties = apObj.toBoolValue();
    }

    // required
    List<String>? required;
    final reqObj = object.getField('required')?.toListValue();
    if (reqObj != null) {
      required = [];
      for (final req in reqObj) {
        final s = req.toStringValue();
        if (s != null) required.add(s);
      }
    }

    final description = object.getField('description')?.toStringValue();

    return SchemaInfo(
      type: type,
      items: items,
      properties: properties,
      additionalProperties: additionalProperties,
      required: required,
      description: description,
    );
  }
}

const _schematicChecker = TypeChecker.fromUrl(
  'package:schemantic/schemantic.dart#Schematic',
);

class SchemaParser {
  static Future<SchemaInfo> parseFromElement(Element element) async {
    final library = element.library;
    if (library == null) {
      throw StateError('Element has no library: $element');
    }

    // Use ResolvedLibraryResult to access AST
    final session = library.session;
    final result = await session.getResolvedLibraryByElement(library);
    if (result is! ResolvedLibraryResult) {
      throw StateError('Could not resolve library for $element');
    }

    // Find the variable declaration in AST
    VariableDeclaration? variableNode;
    for (final part in result.units) {
      final declaration = _findVariableDeclaration(part.unit, element.name!);
      if (declaration != null) {
        variableNode = declaration;
        break;
      }
    }

    if (variableNode == null) {
      throw StateError(
        'Could not find AST node for variable ${element.name}. ensure it is a top-level const or static const.',
      );
    }

    final initializer = variableNode.initializer;
    if (initializer == null) {
      throw StateError('Variable ${element.name} has no initializer');
    }

    return _parseExpression(initializer);
  }

  static VariableDeclaration? _findVariableDeclaration(
    CompilationUnit unit,
    String name,
  ) {
    for (final declaration in unit.declarations) {
      if (declaration is TopLevelVariableDeclaration) {
        for (final variable in declaration.variables.variables) {
          if (variable.name.lexeme == name) {
            return variable;
          }
        }
      }
    }
    return null;
  }

  static SchemaInfo _parseExpression(Expression expression) {
    if (expression is InstanceCreationExpression) {
      final type = expression.constructorName.type.name.lexeme;

      // Check if Schema
      if (type == 'Schema') {
        final constructorName =
            expression.constructorName.name?.name; // named constructor

        return _parseSchemaConstructor(
          constructorName,
          expression.argumentList,
        );
      }
    } else if (expression is MethodInvocation) {
      final target = expression.target;
      if (target is SimpleIdentifier && target.name == 'Schema') {
        final methodName = expression.methodName.name;
        return _parseSchemaConstructor(methodName, expression.argumentList);
      }

      // Handle `.jsonSchema()` calls on generated types
      if (expression.methodName.name == 'jsonSchema') {
        if (target != null) {
          return _resolveSchemaReference(target);
        }
      }
    } else if (expression is Identifier) {
      return _resolveSchemaReference(expression);
    }

    // Handle internal references or other factories if necessary
    throw UnsupportedError(
      'Unsupported expression in Schema definition: ${expression.toSource()}. Only Schema.* constructors and factories are supported.',
    );
  }

  static SchemaInfo _resolveSchemaReference(Expression expression) {
    // Resolve the element
    Element? element;

    // Access staticElement or element via dynamic to bypass version differences
    dynamic getElement(dynamic expr) {
      try {
        return expr.staticElement;
      } catch (_) {
        try {
          return expr.element;
        } catch (_) {
          return null;
        }
      }
    }

    if (expression is Identifier) {
      element = getElement(expression);
    } else if (expression is PropertyAccess) {
      element = getElement(expression.propertyName);
    }

    // For simpleObject reference
    if (element is PropertyAccessorElement) {
      // Getter for a variable
      final variable = element.variable;
      if (_hasSchematicAnnotation(variable)) {
        // It's a Schema variable assignment (const or final)
        final name = variable.name;
        if (name != null) {
          return SchemaInfo(definitionName: _capitalize(name));
        }
      }
    } else if (element is VariableElement) {
      if (_hasSchematicAnnotation(element)) {
        final name = element.name;
        if (name != null) {
          return SchemaInfo(definitionName: _capitalize(name));
        }
      }
      // Also check if it's the specific generated Type const instance
      final name = element.name;
      if (name != null && name.endsWith('Type')) {
        final baseName = name.substring(0, name.length - 4);
        return SchemaInfo(definitionName: _capitalize(baseName));
      }
    }

    // Fallback: Check static type
    final type = expression.staticType;
    if (type != null && type is! DynamicType) {
      final typeName = type.getDisplayString();
      if (typeName.startsWith('SchemanticType<')) {
        final generic = typeName.substring(
          'SchemanticType<'.length,
          typeName.length - 1,
        );
        return SchemaInfo(definitionName: generic);
      }

      if (typeName.endsWith('TypeFactory')) {
        final element = type.element;
        if (element is ClassElement) {
          final supertypes = element.allSupertypes;
          // Find SchemanticType<T>
          for (final s in supertypes) {
            if (s.element.name == 'SchemanticType' &&
                s.typeArguments.isNotEmpty) {
              final generic = s.typeArguments.first.getDisplayString();
              return SchemaInfo(definitionName: generic);
            }
          }
        }
      }
    }

    // Optimistic fallback for identifiers (e.g. generated types not yet visible)
    if (expression is Identifier) {
      final name = expression.name;
      if (name.endsWith('Type')) {
        final baseName = name.substring(0, name.length - 4);
        return SchemaInfo(definitionName: _capitalize(baseName));
      }
    }

    throw UnsupportedError(
      'Could not resolve schema reference for: ${expression.toSource()}. '
      'Ensure it is a variable annotated with @Schematic() or a generated SchemanticType.',
    );
  }

  static bool _hasSchematicAnnotation(Element? element) {
    if (element == null) return false;
    try {
      if (_schematicChecker.hasAnnotationOf(element)) {
        return true;
      }
    } catch (e) {
      // Swallowing exceptions here makes the generator resilient to analyzer errors,
      // but we log it for debugging purposes.
      print(
        'Schemantic Warning: Failed to check annotation for element "${element.name}": $e',
      );
    }
    return false;
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  static SchemaInfo _parseSchemaConstructor(String? name, ArgumentList args) {
    if (name == 'object') {
      return _parseSchemaObject(args);
    } else if (name == 'array' || name == 'list') {
      return _parseSchemaArray(args);
    } else if (['string', 'integer', 'number', 'boolean'].contains(name)) {
      String? description;
      for (final arg in args.arguments) {
        if (arg is NamedExpression && arg.name.label.name == 'description') {
          if (arg.expression is SimpleStringLiteral) {
            description = (arg.expression as SimpleStringLiteral).value;
          }
        }
      }
      return SchemaInfo(type: name, description: description);
    }
    throw UnsupportedError('Unsupported Schema constructor: Schema.$name');
  }

  static SchemaInfo _parseSchemaObject(ArgumentList args) {
    Map<String, SchemaInfo>? properties;
    bool? additionalProperties;
    List<String>? required;
    String? description;

    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;

        if (name == 'properties') {
          properties = _parseProperties(arg.expression);
        } else if (name == 'additionalProperties') {
          if (arg.expression is BooleanLiteral) {
            additionalProperties = (arg.expression as BooleanLiteral).value;
          }
        } else if (name == 'required') {
          required = _parseRequired(arg.expression);
        } else if (name == 'description') {
          if (arg.expression is SimpleStringLiteral) {
            description = (arg.expression as SimpleStringLiteral).value;
          }
        } else {
          throw UnsupportedError(
            "Unsupported argument '$name' in Schema.object",
          );
        }
      }
    }

    return SchemaInfo(
      type: 'object',
      properties: properties,
      additionalProperties: additionalProperties,
      required: required,
      description: description,
    );
  }

  static Map<String, SchemaInfo> _parseProperties(Expression expression) {
    final result = <String, SchemaInfo>{};
    if (expression is SetOrMapLiteral) {
      for (final element in expression.elements) {
        if (element is MapLiteralEntry) {
          final keyExpr = element.key;
          if (keyExpr is SimpleStringLiteral) {
            final key = keyExpr.value;
            result[key] = _parseExpression(element.value);
          } else {
            throw UnsupportedError(
              'Only string literals are supported as property keys in Schema definitions. Found: ${keyExpr.toSource()}',
            );
          }
        }
      }
    }
    return result;
  }

  static List<String> _parseRequired(Expression expression) {
    if (expression is ListLiteral) {
      return expression.elements
          .whereType<SimpleStringLiteral>()
          .map((e) => e.value)
          .toList();
    }
    throw UnsupportedError(
      'Schema.object(required: ...) must be a list literal of strings',
    );
  }

  static SchemaInfo _parseSchemaArray(ArgumentList args) {
    SchemaInfo? items;
    String? description;

    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'items') {
          items = _parseExpression(arg.expression);
        } else if (name == 'description') {
          if (arg.expression is SimpleStringLiteral) {
            description = (arg.expression as SimpleStringLiteral).value;
          }
        } else {
          throw UnsupportedError(
            "Unsupported argument '$name' in Schema.list/array",
          );
        }
      }
    }
    return SchemaInfo(type: 'array', items: items, description: description);
  }
}
