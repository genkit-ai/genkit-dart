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

/// Intermediate representation of a Schema for generation purposes.
class SchemaInfo {
  final String? type;
  final SchemaInfo? items;
  final Map<String, SchemaInfo>? properties;
  final bool? additionalProperties;
  final String? definitionName;
  final List<String>? required;

  SchemaInfo({
    this.type,
    this.items,
    this.properties,
    this.additionalProperties,
    this.definitionName,
    this.required,
  });

  factory SchemaInfo.fromDartObject(DartObject object) {
    String? type = object.getField('type')?.toStringValue();

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

    return SchemaInfo(
      type: type,
      items: items,
      properties: properties,
      additionalProperties: additionalProperties,
      required: required,
    );
  }
}

class SchemaParser {
  static Future<SchemaInfo> parseFromElement(Element element) async {
    final library = element.library;
    if (library == null) throw StateError('Element has no library');

    final session = library.session;
    final result = session.getParsedLibraryByElement(library);
    if (result is! ParsedLibraryResult) {
      throw StateError('Could not parse library');
    }

    VariableDeclaration? varDecl;

    // Naive search for now (improve with element location if needed)
    for (final part in result.units) {
      final declaration = _findVariableDeclaration(part.unit, element.name!);
      if (declaration != null) {
        varDecl = declaration;
        break;
      }
    }

    if (varDecl == null) {
      throw StateError('Could not find AST for ${element.name}');
    }

    final initializer = varDecl.initializer;
    if (initializer == null) {
      throw StateError('Variable ${element.name} has no initializer');
    }

    return _parseExpression(initializer);
  }

  static VariableDeclaration? _findVariableDeclaration(
    CompilationUnit unit,
    String name,
  ) {
    for (final decl in unit.declarations) {
      if (decl is TopLevelVariableDeclaration) {
        for (final v in decl.variables.variables) {
          if (v.name.lexeme == name) return v;
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
    }
    // Handle internal references or other factories if necessary
    throw UnsupportedError(
      'Unsupported expression in Schema definition: ${expression.toSource()}. Only Schema.* constructors and factories are supported.',
    );
  }

  static SchemaInfo _parseSchemaConstructor(String? name, ArgumentList args) {
    if (name == 'object') {
      return _parseSchemaObject(args);
    } else if (name == 'array' || name == 'list') {
      return _parseSchemaArray(args);
    } else if (['string', 'integer', 'number', 'boolean'].contains(name)) {
      return SchemaInfo(type: name);
    }
    throw UnsupportedError('Unsupported Schema constructor: Schema.$name');
  }

  static SchemaInfo _parseSchemaObject(ArgumentList args) {
    Map<String, SchemaInfo>? properties;
    bool? additionalProperties;
    List<String>? required;

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
    for (final arg in args.arguments) {
      if (arg is NamedExpression) {
        final name = arg.name.label.name;
        if (name == 'items') {
          items = _parseExpression(arg.expression);
        } else {
          throw UnsupportedError(
            "Unsupported argument '$name' in Schema.list/array",
          );
        }
      }
    }
    return SchemaInfo(type: 'array', items: items);
  }
}
