// Copyright 2025 Google LLC
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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'tool_restart_sample.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ApprovalRequest {
  factory ApprovalRequest.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ApprovalRequest._(this._json);

  ApprovalRequest({required String question, required String details}) {
    _json = {'question': question, 'details': details};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ApprovalRequest> $schema =
      _ApprovalRequestTypeFactory();

  String get question {
    return _json['question'] as String;
  }

  set question(String value) {
    _json['question'] = value;
  }

  String get details {
    return _json['details'] as String;
  }

  set details(String value) {
    _json['details'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ApprovalRequestTypeFactory extends SchemanticType<ApprovalRequest> {
  const _ApprovalRequestTypeFactory();

  @override
  ApprovalRequest parse(Object? json) {
    return ApprovalRequest._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ApprovalRequest',
    definition: Schema.object(
      properties: {
        'question': Schema.string(description: 'the main question'),
        'details': Schema.string(description: 'request for approval details'),
      },
      required: ['question', 'details'],
    ),
    dependencies: [],
  );
}
