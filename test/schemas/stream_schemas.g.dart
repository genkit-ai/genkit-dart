// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'stream_schemas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

StreamInput _$StreamInputFromJson(Map<String, dynamic> json) => StreamInput(
      prompt: json['prompt'] as String,
    );

Map<String, dynamic> _$StreamInputToJson(StreamInput instance) =>
    <String, dynamic>{
      'prompt': instance.prompt,
    };

StreamOutput _$StreamOutputFromJson(Map<String, dynamic> json) => StreamOutput(
      text: json['text'] as String,
      summary: json['summary'] as String,
    );

Map<String, dynamic> _$StreamOutputToJson(StreamOutput instance) =>
    <String, dynamic>{
      'text': instance.text,
      'summary': instance.summary,
    };
