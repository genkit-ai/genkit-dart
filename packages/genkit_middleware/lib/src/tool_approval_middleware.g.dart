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

part of 'tool_approval_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

final class ToolApprovalOptions {
  factory ToolApprovalOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolApprovalOptions._(this._json);

  ToolApprovalOptions({required List<String> approved}) {
    _json = {'approved': approved};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolApprovalOptions> $schema =
      _ToolApprovalOptionsTypeFactory();

  List<String> get approved {
    return (_json['approved'] as List).cast<String>();
  }

  set approved(List<String> value) {
    _json['approved'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ToolApprovalOptionsTypeFactory
    extends SchemanticType<ToolApprovalOptions> {
  const _ToolApprovalOptionsTypeFactory();

  @override
  ToolApprovalOptions parse(Object? json) {
    return ToolApprovalOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolApprovalOptions',
    definition: $Schema
        .object(
          properties: {'approved': $Schema.list(items: $Schema.string())},
          required: ['approved'],
        )
        .value,
    dependencies: [],
  );
}
