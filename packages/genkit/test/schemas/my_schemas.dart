// Copyright 2024 Google LLC
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
