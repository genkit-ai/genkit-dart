// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'shelf_server_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type HelloInput(Map<String, dynamic> _json) {
  factory HelloInput.from({required String name}) {
    return HelloInput({'name': name});
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class HelloInputTypeFactory implements JsonExtensionType<HelloInput> {
  const HelloInputTypeFactory();

  @override
  HelloInput parse(Object json) {
    return HelloInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'name': Schema.string()},
      required: ['name'],
    );
  }
}

const HelloInputType = HelloInputTypeFactory();

extension type HelloOutput(Map<String, dynamic> _json) {
  factory HelloOutput.from({required String greeting}) {
    return HelloOutput({'greeting': greeting});
  }

  String get greeting {
    return _json['greeting'] as String;
  }

  set greeting(String value) {
    _json['greeting'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class HelloOutputTypeFactory implements JsonExtensionType<HelloOutput> {
  const HelloOutputTypeFactory();

  @override
  HelloOutput parse(Object json) {
    return HelloOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    );
  }
}

const HelloOutputType = HelloOutputTypeFactory();

extension type CountChunk(Map<String, dynamic> _json) {
  factory CountChunk.from({required int count}) {
    return CountChunk({'count': count});
  }

  int get count {
    return _json['count'] as int;
  }

  set count(int value) {
    _json['count'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class CountChunkTypeFactory implements JsonExtensionType<CountChunk> {
  const CountChunkTypeFactory();

  @override
  CountChunk parse(Object json) {
    return CountChunk(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'count': Schema.integer()},
      required: ['count'],
    );
  }
}

const CountChunkType = CountChunkTypeFactory();
