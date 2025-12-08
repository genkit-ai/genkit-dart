// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'shelf_test.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type ShelfTestOutput(Map<String, dynamic> _json) {
  factory ShelfTestOutput.from({required String greeting}) {
    return ShelfTestOutput({'greeting': greeting});
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

class ShelfTestOutputTypeFactory implements JsonExtensionType<ShelfTestOutput> {
  const ShelfTestOutputTypeFactory();

  @override
  ShelfTestOutput parse(Object json) {
    return ShelfTestOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'greeting': Schema.string()},
      required: ['greeting'],
    );
  }
}

const ShelfTestOutputType = ShelfTestOutputTypeFactory();

extension type ShelfTestStream(Map<String, dynamic> _json) {
  factory ShelfTestStream.from({required String chunk}) {
    return ShelfTestStream({'chunk': chunk});
  }

  String get chunk {
    return _json['chunk'] as String;
  }

  set chunk(String value) {
    _json['chunk'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ShelfTestStreamTypeFactory implements JsonExtensionType<ShelfTestStream> {
  const ShelfTestStreamTypeFactory();

  @override
  ShelfTestStream parse(Object json) {
    return ShelfTestStream(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'chunk': Schema.string()},
      required: ['chunk'],
    );
  }
}

const ShelfTestStreamType = ShelfTestStreamTypeFactory();
