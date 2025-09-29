// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'my_schemas.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MyInput _$MyInputFromJson(Map<String, dynamic> json) => MyInput(
      message: json['message'] as String,
      count: (json['count'] as num).toInt(),
    );

Map<String, dynamic> _$MyInputToJson(MyInput instance) => <String, dynamic>{
      'message': instance.message,
      'count': instance.count,
    };

MyOutput _$MyOutputFromJson(Map<String, dynamic> json) => MyOutput(
      reply: json['reply'] as String,
      newCount: (json['newCount'] as num).toInt(),
    );

Map<String, dynamic> _$MyOutputToJson(MyOutput instance) => <String, dynamic>{
      'reply': instance.reply,
      'newCount': instance.newCount,
    };
