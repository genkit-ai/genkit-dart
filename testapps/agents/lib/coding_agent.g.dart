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

part of 'coding_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class AskUserInput {
  /// Creates a [AskUserInput] from a JSON map.
  factory AskUserInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  AskUserInput._(this._json);

  AskUserInput({required String question, required List<String> options}) {
    _json = {'question': question, 'options': options};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [AskUserInput].
  static const SchemanticType<AskUserInput> $schema =
      _AskUserInputTypeFactory();

  String get question {
    return _json['question'] as String;
  }

  set question(String value) {
    _json['question'] = value;
  }

  List<String> get options {
    return (_json['options'] as List).cast<String>();
  }

  set options(List<String> value) {
    _json['options'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [AskUserInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AskUserInputTypeFactory extends SchemanticType<AskUserInput> {
  const _AskUserInputTypeFactory();

  @override
  AskUserInput parse(Object? json) {
    return AskUserInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'AskUserInput',
    definition: $Schema
        .object(
          properties: {
            'question': $Schema.string(
              description: 'The question to ask the user',
            ),
            'options': $Schema.list(
              description:
                  'Suggested answer options for the user to choose from (2-5)',
              items: $Schema.string(),
            ),
          },
          required: ['question', 'options'],
        )
        .value,
    dependencies: [],
  );
}

base class RunShellInput {
  /// Creates a [RunShellInput] from a JSON map.
  factory RunShellInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RunShellInput._(this._json);

  RunShellInput({required String command}) {
    _json = {'command': command};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RunShellInput].
  static const SchemanticType<RunShellInput> $schema =
      _RunShellInputTypeFactory();

  String get command {
    return _json['command'] as String;
  }

  set command(String value) {
    _json['command'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RunShellInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RunShellInputTypeFactory extends SchemanticType<RunShellInput> {
  const _RunShellInputTypeFactory();

  @override
  RunShellInput parse(Object? json) {
    return RunShellInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RunShellInput',
    definition: $Schema
        .object(
          properties: {
            'command': $Schema.string(
              description: 'The shell command to execute',
            ),
          },
          required: ['command'],
        )
        .value,
    dependencies: [],
  );
}

base class RunShellOutput {
  /// Creates a [RunShellOutput] from a JSON map.
  factory RunShellOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  RunShellOutput._(this._json);

  RunShellOutput({
    required String stdout,
    required String stderr,
    required int exitCode,
  }) {
    _json = {'stdout': stdout, 'stderr': stderr, 'exitCode': exitCode};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [RunShellOutput].
  static const SchemanticType<RunShellOutput> $schema =
      _RunShellOutputTypeFactory();

  String get stdout {
    return _json['stdout'] as String;
  }

  set stdout(String value) {
    _json['stdout'] = value;
  }

  String get stderr {
    return _json['stderr'] as String;
  }

  set stderr(String value) {
    _json['stderr'] = value;
  }

  int get exitCode {
    return _json['exitCode'] as int;
  }

  set exitCode(int value) {
    _json['exitCode'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [RunShellOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RunShellOutputTypeFactory extends SchemanticType<RunShellOutput> {
  const _RunShellOutputTypeFactory();

  @override
  RunShellOutput parse(Object? json) {
    return RunShellOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'RunShellOutput',
    definition: $Schema
        .object(
          properties: {
            'stdout': $Schema.string(),
            'stderr': $Schema.string(),
            'exitCode': $Schema.integer(),
          },
          required: ['stdout', 'stderr', 'exitCode'],
        )
        .value,
    dependencies: [],
  );
}

base class SafetyVerdict {
  /// Creates a [SafetyVerdict] from a JSON map.
  factory SafetyVerdict.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  SafetyVerdict._(this._json);

  SafetyVerdict({required String verdict, required String reason}) {
    _json = {'verdict': verdict, 'reason': reason};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [SafetyVerdict].
  static const SchemanticType<SafetyVerdict> $schema =
      _SafetyVerdictTypeFactory();

  String get verdict {
    return _json['verdict'] as String;
  }

  set verdict(String value) {
    _json['verdict'] = value;
  }

  String get reason {
    return _json['reason'] as String;
  }

  set reason(String value) {
    _json['reason'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [SafetyVerdict] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _SafetyVerdictTypeFactory extends SchemanticType<SafetyVerdict> {
  const _SafetyVerdictTypeFactory();

  @override
  SafetyVerdict parse(Object? json) {
    return SafetyVerdict._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'SafetyVerdict',
    definition: $Schema
        .object(
          properties: {
            'verdict': $Schema.string(
              description: 'Whether the command is safe or risky',
            ),
            'reason': $Schema.string(
              description:
                  'Brief explanation of why the command is safe or risky',
            ),
          },
          required: ['verdict', 'reason'],
        )
        .value,
    dependencies: [],
  );
}
