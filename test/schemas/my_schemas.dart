import 'package:json_annotation/json_annotation.dart';

part 'my_schemas.g.dart';

@JsonSerializable()
class MyInput {
  final String message;
  final int count;
  MyInput({required this.message, required this.count});

  factory MyInput.fromJson(Map<String, dynamic> json) =>
      _$MyInputFromJson(json);
  Map<String, dynamic> toJson() => _$MyInputToJson(this);
}

@JsonSerializable()
class MyOutput {
  final String reply;
  final int newCount;
  MyOutput({required this.reply, required this.newCount});

  factory MyOutput.fromJson(Map<String, dynamic> json) =>
      _$MyOutputFromJson(json);
  Map<String, dynamic> toJson() => _$MyOutputToJson(this);
}
