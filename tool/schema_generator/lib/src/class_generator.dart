import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

class ClassGenerator {
  final Map<String, dynamic> definitions;
  final Set<String> _generatedClasses = {};

  ClassGenerator(this.definitions);

  String generate(Set<String> allowlist) {
    final library = Library((b) {
      b.directives.addAll([
        Directive.import('package:json_annotation/json_annotation.dart'),
        Directive.part('genkit_schemas.g.dart'),
      ]);
      for (final className in allowlist) {
        if (definitions.containsKey(className)) {
          _generateClass(
            b,
            className,
            definitions[className] as Map<String, dynamic>,
          );
        }
      }
    });

    final emitter = DartEmitter();
    return DartFormatter(
      languageVersion: DartFormatter.latestLanguageVersion,
    ).format('${library.accept(emitter)}');
  }

  void _generateClass(
    LibraryBuilder b,
    String className,
    Map<String, dynamic> schema, {
    Reference? extend,
  }) {
    if (_generatedClasses.contains(className)) {
      return;
    }
    _generatedClasses.add(className);

    if (schema.containsKey('enum')) {
      _generateEnum(b, className, schema['enum'] as List);
    } else if (schema.containsKey('anyOf')) {
      _generateUnionClass(
        b,
        className,
        schema['anyOf'] as List,
        extend: extend,
      );
    } else {
      _generateStandardClass(b, className, schema, extend: extend);
    }
  }

  void _generateStandardClass(
    LibraryBuilder b,
    String className,
    Map<String, dynamic> schema, {
    Reference? extend,
  }) {
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required = (schema['required'] as List<dynamic>? ?? [])
        .cast<String>();
    final isAbstract = properties.isEmpty;

    b.body.add(
      Class((c) {
        c
          ..name = className
          ..abstract = isAbstract
          ..extend = extend
          ..annotations.add(
            refer('JsonSerializable').call([], {
              'explicitToJson': literalTrue,
              'includeIfNull': literalFalse,
            }),
          );

        if (!isAbstract) {
          c.constructors.add(
            Constructor((con) {
              con.optionalParameters.addAll(
                properties.entries.map((e) {
                  final isRequired = required.contains(e.key);
                  return Parameter((p) {
                    p
                      ..name = _sanitizeFieldName(e.key)
                      ..toThis = true
                      ..named = true
                      ..required = isRequired;
                  });
                }),
              );
            }),
          );
          c.constructors.add(_createFromJsonConstructor(className));
          c.methods.add(
            _createToJsonMethod(className, isOverride: extend != null),
          );
        }

        c.fields.addAll(
          properties.entries.map((e) {
            return Field((f) {
              f
                ..name = _sanitizeFieldName(e.key)
                ..type = _mapType(e.value as Map<String, dynamic>)
                ..modifier = FieldModifier.final$;
            });
          }),
        );
      }),
    );
  }

  void _generateEnum(LibraryBuilder b, String enumName, List<dynamic> values) {
    b.body.add(
      Enum((e) {
        e
          ..name = enumName
          ..values.addAll(
            values.map(
              (v) => EnumValue(
                (ev) => ev..name = _sanitizeFieldName(v.toString()),
              ),
            ),
          );
      }),
    );
  }

  void _generateUnionClass(
    LibraryBuilder b,
    String className,
    List<dynamic> anyOf, {
    Reference? extend,
  }) {
    final subtypes = <Map<String, String>>[];
    for (final item in anyOf) {
      final ref = (item as Map)['\$ref'] as String?;
      if (ref != null) {
        final subclassName = ref.split('/').last;
        final subclassSchema =
            definitions[subclassName] as Map<String, dynamic>;
        final required = (subclassSchema['required'] as List<dynamic>? ?? [])
            .cast<String>();
        if (required.isNotEmpty) {
          subtypes.add({'name': subclassName, 'key': required.first});
        }
        if (definitions.containsKey(subclassName) &&
            !_generatedClasses.contains(subclassName)) {
          _generateClass(
            b,
            subclassName,
            subclassSchema,
            extend: refer(className),
          );
        }
      }
    }

    b.body.add(
      Class((c) {
        c
          ..name = className
          ..abstract = true
          ..extend = extend
          ..constructors.add(Constructor())
          ..constructors.add(_createFromJsonConstructor(className, subtypes))
          ..methods.add(
            _createToJsonMethod(
              className,
              subtypes: subtypes,
              isOverride: extend != null,
            ),
          );
      }),
    );
  }

  String _sanitizeFieldName(String name) {
    if (name == 'required') {
      return 'isRequired';
    }
    return name.replaceAll('-', '_');
  }

  Reference _mapType(Map<String, dynamic> schema) {
    if (schema.containsKey('not')) {
      return refer('dynamic');
    }
    if (schema.containsKey('\$ref')) {
      return _mapRefType(schema);
    }
    final type = schema['type'] as String?;
    return switch (type) {
      'string' => refer('String?'),
      'number' => refer('double?'),
      'integer' => refer('int?'),
      'boolean' => refer('bool?'),
      'array' => _mapArrayType(schema),
      'object' => refer('Map<String, dynamic>?'),
      _ => refer('dynamic'),
    };
  }

  Reference _mapRefType(Map<String, dynamic> schema) {
    final ref = schema['\$ref'] as String;
    if (ref == '#/\$defs/DocumentPart') {
      return refer('Part?');
    }
    final parts = ref.split('/');
    if (parts case ['#', '\$defs', final defName, final propName]) {
      final def = definitions[defName];
      if (def is Map<String, dynamic>) {
        final prop = (def['properties'] as Map<String, dynamic>?)?[propName];
        if (prop is Map<String, dynamic>) {
          return _mapType(prop);
        }
      }
    }
    var className = ref.split('/').last;
    if (definitions.containsKey(className)) {
      return refer('${className[0].toUpperCase()}${className.substring(1)}?');
    }
    return refer('dynamic');
  }

  Reference _mapArrayType(Map<String, dynamic> schema) {
    final items = schema['items'] as Map<String, dynamic>?;
    if (items != null) {
      return refer('List<${_mapType(items).symbol}>?');
    }
    return refer('List<dynamic>?');
  }

  Constructor _createFromJsonConstructor(
    String className, [
    List<Map<String, String>>? subtypes,
  ]) {
    return Constructor((c) {
      c
        ..factory = true
        ..name = 'fromJson'
        ..requiredParameters.add(
          Parameter(
            (p) => p
              ..name = 'json'
              ..type = refer('Map<String, dynamic>'),
          ),
        );
      if (subtypes == null) {
        c
          ..lambda = true
          ..body = Code('_\$${className}FromJson(json)');
      } else {
        c.body = Code(
          '${subtypes.map((s) => "if (json.containsKey('${s['key']}')) { return ${s['name']}.fromJson(json); }").join('\n')}\n throw Exception(\'Unknown subtype of $className\');',
        );
      }
    });
  }

  Method _createToJsonMethod(
    String className, {
    List<Map<String, String>>? subtypes,
    bool isOverride = false,
  }) {
    return Method((m) {
      m
        ..name = 'toJson'
        ..returns = refer('Map<String, dynamic>');
      if (isOverride) {
        m.annotations.add(refer('override'));
      }
      if (subtypes == null) {
        m
          ..lambda = true
          ..body = Code('_\$${className}ToJson(this)');
      } else {
        m.body = Code(
          '${subtypes.map((s) => "if (this is ${s['name']}) return (this as ${s['name']}).toJson();").join('\n')}\n throw Exception(\'Unknown subtype of $className\');',
        );
      }
    });
  }
}
