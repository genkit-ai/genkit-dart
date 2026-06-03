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

part of 'server.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class TransferMoneyInput {
  /// Creates a [TransferMoneyInput] from a JSON map.
  factory TransferMoneyInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TransferMoneyInput._(this._json);

  TransferMoneyInput({required String toAccountId, required int amount}) {
    _json = {'toAccountId': toAccountId, 'amount': amount};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TransferMoneyInput].
  static const SchemanticType<TransferMoneyInput> $schema =
      _TransferMoneyInputTypeFactory();

  String get toAccountId {
    return _json['toAccountId'] as String;
  }

  set toAccountId(String value) {
    _json['toAccountId'] = value;
  }

  int get amount {
    return _json['amount'] as int;
  }

  set amount(int value) {
    _json['amount'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [TransferMoneyInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TransferMoneyInputTypeFactory
    extends SchemanticType<TransferMoneyInput> {
  const _TransferMoneyInputTypeFactory();

  @override
  TransferMoneyInput parse(Object? json) {
    return TransferMoneyInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TransferMoneyInput',
    definition: $Schema
        .object(
          properties: {
            'toAccountId': $Schema.string(
              description: 'the account id of the transfer destination',
            ),
            'amount': $Schema.integer(
              description: 'the amount in integer cents (100 = 1 USD)',
            ),
          },
          required: ['toAccountId', 'amount'],
        )
        .value,
    dependencies: [],
  );
}

base class TransferMoneyOutput {
  /// Creates a [TransferMoneyOutput] from a JSON map.
  factory TransferMoneyOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TransferMoneyOutput._(this._json);

  TransferMoneyOutput({required String status, String? message}) {
    _json = {'status': status, 'message': ?message};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TransferMoneyOutput].
  static const SchemanticType<TransferMoneyOutput> $schema =
      _TransferMoneyOutputTypeFactory();

  String get status {
    return _json['status'] as String;
  }

  set status(String value) {
    _json['status'] = value;
  }

  String? get message {
    return _json['message'] as String?;
  }

  set message(String? value) {
    if (value == null) {
      _json.remove('message');
    } else {
      _json['message'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [TransferMoneyOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _TransferMoneyOutputTypeFactory
    extends SchemanticType<TransferMoneyOutput> {
  const _TransferMoneyOutputTypeFactory();

  @override
  TransferMoneyOutput parse(Object? json) {
    return TransferMoneyOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'TransferMoneyOutput',
    definition: $Schema
        .object(
          properties: {
            'status': $Schema.string(
              description: 'the outcome of the transfer',
            ),
            'message': $Schema.string(description: 'message'),
          },
          required: ['status'],
        )
        .value,
    dependencies: [],
  );
}

base class AskQuestionInput {
  /// Creates a [AskQuestionInput] from a JSON map.
  factory AskQuestionInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AskQuestionInput._(this._json);

  AskQuestionInput({required List<String> choices, bool? allowOther}) {
    _json = {'choices': choices, 'allowOther': ?allowOther};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AskQuestionInput].
  static const SchemanticType<AskQuestionInput> $schema =
      _AskQuestionInputTypeFactory();

  List<String> get choices {
    return (_json['choices'] as List).cast<String>();
  }

  set choices(List<String> value) {
    _json['choices'] = value;
  }

  bool? get allowOther {
    return _json['allowOther'] as bool?;
  }

  set allowOther(bool? value) {
    if (value == null) {
      _json.remove('allowOther');
    } else {
      _json['allowOther'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AskQuestionInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AskQuestionInputTypeFactory
    extends SchemanticType<AskQuestionInput> {
  const _AskQuestionInputTypeFactory();

  @override
  AskQuestionInput parse(Object? json) {
    return AskQuestionInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AskQuestionInput',
    definition: $Schema
        .object(
          properties: {
            'choices': $Schema.list(
              description: 'the choices to display to the user',
              items: $Schema.string(),
            ),
            'allowOther': $Schema.boolean(
              description: 'when true, allow write-ins',
            ),
          },
          required: ['choices'],
        )
        .value,
    dependencies: [],
  );
}
