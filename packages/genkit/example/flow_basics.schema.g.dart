// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'flow_basics.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Subject(Map<String, dynamic> _json) {
  factory Subject.from({required String subject}) {
    return Subject({'subject': subject});
  }

  String get subject {
    return _json['subject'] as String;
  }

  set subject(String value) {
    _json['subject'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class SubjectTypeFactory implements JsonExtensionType<Subject> {
  const SubjectTypeFactory();

  @override
  Subject parse(Object json) {
    return Subject(json as Map<String, dynamic>);
  }

  @override
  Schema get jsonSchema {
    return Schema.object(
      properties: {'subject': Schema.string()},
      required: ['subject'],
    );
  }
}

// ignore: constant_identifier_names
const SubjectType = SubjectTypeFactory();

extension type Count(Map<String, dynamic> _json) {
  factory Count.from({required int count}) {
    return Count({'count': count});
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

class CountTypeFactory implements JsonExtensionType<Count> {
  const CountTypeFactory();

  @override
  Count parse(Object json) {
    return Count(json as Map<String, dynamic>);
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
const CountType = CountTypeFactory();
