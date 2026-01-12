// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'types.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type ProcessObjectInput(Map<String, dynamic> _json) {
  factory ProcessObjectInput.from({
    required String message,
    required int count,
  }) {
    return ProcessObjectInput({'message': message, 'count': count});
  }

  String get message {
    return _json['message'] as String;
  }

  set message(String value) {
    _json['message'] = value;
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

class ProcessObjectInputTypeFactory
    implements JsonExtensionType<ProcessObjectInput> {
  const ProcessObjectInputTypeFactory();

  @override
  ProcessObjectInput parse(Object json) {
    return ProcessObjectInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'message': Schema.string(), 'count': Schema.integer()},
      required: ['message', 'count'],
    );
  }
}

// ignore: constant_identifier_names
const ProcessObjectInputType = ProcessObjectInputTypeFactory();

extension type ProcessObjectOutput(Map<String, dynamic> _json) {
  factory ProcessObjectOutput.from({
    required String reply,
    required int newCount,
  }) {
    return ProcessObjectOutput({'reply': reply, 'newCount': newCount});
  }

  String get reply {
    return _json['reply'] as String;
  }

  set reply(String value) {
    _json['reply'] = value;
  }

  int get newCount {
    return _json['newCount'] as int;
  }

  set newCount(int value) {
    _json['newCount'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ProcessObjectOutputTypeFactory
    implements JsonExtensionType<ProcessObjectOutput> {
  const ProcessObjectOutputTypeFactory();

  @override
  ProcessObjectOutput parse(Object json) {
    return ProcessObjectOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'reply': Schema.string(), 'newCount': Schema.integer()},
      required: ['reply', 'newCount'],
    );
  }
}

// ignore: constant_identifier_names
const ProcessObjectOutputType = ProcessObjectOutputTypeFactory();

extension type StreamObjectsInput(Map<String, dynamic> _json) {
  factory StreamObjectsInput.from({required String prompt}) {
    return StreamObjectsInput({'prompt': prompt});
  }

  String get prompt {
    return _json['prompt'] as String;
  }

  set prompt(String value) {
    _json['prompt'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class StreamObjectsInputTypeFactory
    implements JsonExtensionType<StreamObjectsInput> {
  const StreamObjectsInputTypeFactory();

  @override
  StreamObjectsInput parse(Object json) {
    return StreamObjectsInput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'prompt': Schema.string()},
      required: ['prompt'],
    );
  }
}

// ignore: constant_identifier_names
const StreamObjectsInputType = StreamObjectsInputTypeFactory();

extension type StreamObjectsOutput(Map<String, dynamic> _json) {
  factory StreamObjectsOutput.from({
    required String text,
    required String summary,
  }) {
    return StreamObjectsOutput({'text': text, 'summary': summary});
  }

  String get text {
    return _json['text'] as String;
  }

  set text(String value) {
    _json['text'] = value;
  }

  String get summary {
    return _json['summary'] as String;
  }

  set summary(String value) {
    _json['summary'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class StreamObjectsOutputTypeFactory
    implements JsonExtensionType<StreamObjectsOutput> {
  const StreamObjectsOutputTypeFactory();

  @override
  StreamObjectsOutput parse(Object json) {
    return StreamObjectsOutput(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'text': Schema.string(), 'summary': Schema.string()},
      required: ['text', 'summary'],
    );
  }
}

// ignore: constant_identifier_names
const StreamObjectsOutputType = StreamObjectsOutputTypeFactory();

extension type StreamyThrowyChunk(Map<String, dynamic> _json) {
  factory StreamyThrowyChunk.from({required int count}) {
    return StreamyThrowyChunk({'count': count});
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

class StreamyThrowyChunkTypeFactory
    implements JsonExtensionType<StreamyThrowyChunk> {
  const StreamyThrowyChunkTypeFactory();

  @override
  StreamyThrowyChunk parse(Object json) {
    return StreamyThrowyChunk(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'count': Schema.integer()},
      required: ['count'],
    );
  }
}

// ignore: constant_identifier_names
const StreamyThrowyChunkType = StreamyThrowyChunkTypeFactory();
