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

part 'stream_schemas.g.dart';

@JsonSerializable()
class StreamInput {
  final String prompt;

  StreamInput({required this.prompt});

  factory StreamInput.fromJson(Map<String, dynamic> json) =>
      _$StreamInputFromJson(json);
  Map<String, dynamic> toJson() => _$StreamInputToJson(this);
}

@JsonSerializable()
class StreamOutput {
  final String text;
  final String summary;

  StreamOutput({required this.text, required this.summary});

  factory StreamOutput.fromJson(Map<String, dynamic> json) =>
      _$StreamOutputFromJson(json);
  Map<String, dynamic> toJson() => _$StreamOutputToJson(this);
}

class TestStreamChunk {
  final String chunk;

  TestStreamChunk({required this.chunk});

  factory TestStreamChunk.fromJson(Map<String, dynamic> json) =>
      TestStreamChunk(chunk: json['chunk'] as String);

  Map<String, dynamic> toJson() => {'chunk': chunk};
}
