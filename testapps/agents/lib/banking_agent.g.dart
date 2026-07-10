// Copyright 2026 Google LLC
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

part of 'banking_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class UserApprovalInput {
  /// Creates a [UserApprovalInput] from a JSON map.
  factory UserApprovalInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  UserApprovalInput._(this._json);

  UserApprovalInput({required String action, required String details}) {
    _json = {'action': action, 'details': details};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [UserApprovalInput].
  static const SchemanticType<UserApprovalInput> $schema =
      _UserApprovalInputTypeFactory();

  String get action {
    return _json['action'] as String;
  }

  set action(String value) {
    _json['action'] = value;
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

  /// Serializes this [UserApprovalInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _UserApprovalInputTypeFactory
    extends SchemanticType<UserApprovalInput> {
  const _UserApprovalInputTypeFactory();

  @override
  UserApprovalInput parse(Object? json) {
    return UserApprovalInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'UserApprovalInput',
    definition: $Schema
        .object(
          properties: {
            'action': $Schema.string(description: 'The action to be approved'),
            'details': $Schema.string(description: 'Details about the action'),
          },
          required: ['action', 'details'],
        )
        .value,
    dependencies: [],
  );
}

base class TransferMoneyInput {
  /// Creates a [TransferMoneyInput] from a JSON map.
  factory TransferMoneyInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  TransferMoneyInput._(this._json);

  TransferMoneyInput({required double amount, required String toAccount}) {
    _json = {'amount': amount, 'toAccount': toAccount};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TransferMoneyInput].
  static const SchemanticType<TransferMoneyInput> $schema =
      _TransferMoneyInputTypeFactory();

  double get amount {
    return (_json['amount'] as num).toDouble();
  }

  set amount(double value) {
    _json['amount'] = value;
  }

  String get toAccount {
    return _json['toAccount'] as String;
  }

  set toAccount(String value) {
    _json['toAccount'] = value;
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
            'amount': $Schema.number(),
            'toAccount': $Schema.string(),
          },
          required: ['amount', 'toAccount'],
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

  TransferMoneyOutput({required bool success, required String transactionId}) {
    _json = {'success': success, 'transactionId': transactionId};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [TransferMoneyOutput].
  static const SchemanticType<TransferMoneyOutput> $schema =
      _TransferMoneyOutputTypeFactory();

  bool get success {
    return _json['success'] as bool;
  }

  set success(bool value) {
    _json['success'] = value;
  }

  String get transactionId {
    return _json['transactionId'] as String;
  }

  set transactionId(String value) {
    _json['transactionId'] = value;
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
            'success': $Schema.boolean(),
            'transactionId': $Schema.string(),
          },
          required: ['success', 'transactionId'],
        )
        .value,
    dependencies: [],
  );
}
