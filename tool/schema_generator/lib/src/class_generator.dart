import 'package:code_builder/code_builder.dart';
import 'package:dart_style/dart_style.dart';

const typeOverrides = {
  'ToolResponse': {'output': 'dynamic'},
  'GenerateActionOptions': {'maxTurns': 'int'},
};

class ClassGenerator {
  final Map<String, dynamic> definitions;
  final Set<String> _generatedClasses = {};

  ClassGenerator(this.definitions);

  String generate(Set<String> allowlist) {
    final library = Library((b) {
      b.directives.addAll([
        Directive.import('package:genkit/schema.dart'),
        Directive.part('types.schema.g.dart'),
      ]);
      for (final className in allowlist) {
        if (definitions.containsKey(className)) {
          _generateClass(b, className, definitions[className]);
        }
      }
    });

    final emitter = DartEmitter();
    return DartFormatter(languageVersion: DartFormatter.latestLanguageVersion)
        .format('${library.accept(emitter)}');
  }

  void _generateClass(
      LibraryBuilder b, String className, Map<String, dynamic> schema,
      {Reference? extend}) {
    if (_generatedClasses.contains(className)) {
      return;
    }
    _generatedClasses.add(className);

    if (schema.containsKey('enum')) {
      _generateEnumExtensionType(b, className, schema['enum']);
    } else if (schema.containsKey('anyOf')) {
      _generateUnionClass(b, className, schema['anyOf'], extend: extend);
    } else {
      _generateStandardClass(b, className, schema, extend: extend);
    }
  }

  void _generateStandardClass(
      LibraryBuilder b, String className, Map<String, dynamic> schema,
      {Reference? extend}) {
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};
    final required =
        (schema['required'] as List<dynamic>? ?? []).cast<String>();

    b.body.add(Class((c) {
      c
        ..name = '${className}Schema'
        ..abstract = true
        ..annotations.add(refer('GenkitSchema').call([]));

      if (extend != null) {
        c.implements.add(extend);
      }

      c.methods.addAll(properties.entries
          .where((e) => !_isNotType(e.value as Map<String, dynamic>))
          .map((e) {
        final isRequired = required.contains(e.key);
        return Method((m) {
          m
            ..name = _sanitizeFieldName(e.key)
            ..type = MethodType.getter
            ..returns =
                _mapType(className, e.key, e.value, isRequired: isRequired)
            ..external = true;
        });
      }));
    }));
  }

  void _generateEnumExtensionType(
      LibraryBuilder b, String enumName, List<dynamic> values) {
    final buffer = StringBuffer();
    buffer.writeln('extension type $enumName(String value) {');
    for (final value in values) {
      final fieldName = _sanitizeFieldName(value.toString());
      buffer
          .writeln("  static $enumName get $fieldName => $enumName('$value');");
    }
    buffer.writeln('}');
    b.body.add(Code(buffer.toString()));
  }

  void _generateUnionClass(
      LibraryBuilder b, String className, List<dynamic> anyOf,
      {Reference? extend}) {
    // Generate the base abstract class for the union type.
    b.body.add(Class((c) {
      c
        ..name = '${className}Schema'
        ..abstract = true
        ..annotations.add(refer('GenkitSchema').call([]));
      if (extend != null) {
        c.implements.add(extend);
      }
    }));

    for (final item in anyOf) {
      final ref = item['\$ref'] as String?;
      if (ref != null) {
        final subclassName = ref.split('/').last;
        final subclassSchema =
            definitions[subclassName] as Map<String, dynamic>;
        if (definitions.containsKey(subclassName) &&
            !_generatedClasses.contains(subclassName)) {
          // Pass the union type as an interface to implement.
          _generateClass(b, subclassName, subclassSchema,
              extend: refer('${className}Schema'));
        }
      }
    }
  }

  String _sanitizeFieldName(String name) {
    if (name == 'required') {
      return 'isRequired';
    }
    return name.replaceAll('-', '_');
  }

  bool _isNotType(Map<String, dynamic> schema) {
    if (schema.containsKey('not')) {
      return true;
    }
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'] as String;
      final parts = ref.split('/');
      if (parts.length > 2 && parts[0] == '#' && parts[1] == '\$defs') {
        var current = definitions;
        for (var i = 2; i < parts.length; i++) {
          if (current is! Map<String, dynamic>) {
            return false;
          }
          final part = parts[i];
          if (current.containsKey(part)) {
            current = current[part];
          } else {
            return false;
          }
        }
        if (current is Map<String, dynamic>) {
          return _isNotType(current);
        }
      }
    }
    return false;
  }

  Reference _mapType(
      String parentType, String fieldName, Map<String, dynamic> schema,
      {bool isRequired = false}) {
    if (typeOverrides.containsKey(parentType) &&
        typeOverrides[parentType]!.containsKey(fieldName)) {
      return refer('${typeOverrides[parentType]![fieldName]}?');
    }
    final type = _mapTypeInner(parentType, schema);
    if (isRequired) {
      return refer(type.symbol!.replaceAll('?', ''));
    }
    if (!type.symbol!.endsWith('?')) {
      return refer('${type.symbol}?');
    }
    return type;
  }

  Reference _mapTypeInner(String parentType, Map<String, dynamic> schema) {
    if (schema.isEmpty) {
      return refer('Map<String, dynamic>');
    }
    if (schema.containsKey('not')) {
      return refer('dynamic');
    }
    if (schema.containsKey('\$ref')) {
      return _mapRefType(parentType, schema);
    }
    final typeValue = schema['type'];
    String? type;
    if (typeValue is String) {
      type = typeValue;
    } else if (typeValue is List) {
      type = typeValue.firstWhere((e) => e != 'null', orElse: () => null);
    }
    switch (type) {
      case 'string':
        return refer('String');
      case 'number':
        return refer('double');
      case 'integer':
        return refer('int');
      case 'boolean':
        return refer('bool');
      case 'array':
        return _mapArrayType(parentType, schema);
      case 'object':
        return refer('Map<String, dynamic>');
      default:
        return refer('dynamic');
    }
  }

  Reference _mapRefType(String parentType, Map<String, dynamic> schema) {
    final ref = schema['\$ref'] as String;
    if (ref == '#/\$defs/DocumentPart') {
      return refer('PartSchema');
    }
    final parts = ref.split('/');
    if (parts.length > 2 && parts[0] == '#' && parts[1] == '\$defs') {
      final defName = parts[2];
      if (definitions.containsKey(defName) && parts.length == 3) {
        final className = defName;
        final newName =
            '${className[0].toUpperCase()}${className.substring(1)}';
        final def = definitions[className];
        if (def != null &&
            def is Map<String, dynamic> &&
            def.containsKey('enum')) {
          return refer(newName);
        }
        return refer('${newName}Schema');
      }
      dynamic current = definitions;
      for (var i = 2; i < parts.length; i++) {
        final part = parts[i];
        if (current is Map<String, dynamic> && current.containsKey(part)) {
          current = current[part];
        } else {
          current = null;
          break;
        }
      }
      if (current is Map<String, dynamic>) {
        return _mapTypeInner(parts.last, current);
      }
    }
    var className = ref.split('/').last;
    if (definitions.containsKey(className)) {
      final newName = '${className[0].toUpperCase()}${className.substring(1)}';
      final def = definitions[className];
      if (def != null &&
          def is Map<String, dynamic> &&
          def.containsKey('enum')) {
        return refer(newName);
      }
      return refer('${newName}Schema');
    }
    return refer('dynamic');
  }

  Reference _mapArrayType(String parentType, Map<String, dynamic> schema) {
    final items = schema['items'] as Map<String, dynamic>?;
    if (items != null) {
      final itemType = _mapType(parentType, 'items', items, isRequired: true);
      return refer('List<${itemType.symbol}>');
    }
    return refer('List<dynamic>');
  }
}
