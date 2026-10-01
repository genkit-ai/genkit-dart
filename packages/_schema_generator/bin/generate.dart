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

import 'dart:convert';
import 'dart:io';

import 'package:_schema_generator/src/class_generator.dart';
import 'package:http/http.dart' as http;

void main() async {
  final response = await http.get(
    Uri.parse(
      'https://raw.githubusercontent.com/genkit-ai/genkit/refs/heads/main/genkit-tools/genkit-schema.json',
    ),
  );

  if (response.statusCode == 200) {
    final schema = json.decode(response.body) as Map<String, dynamic>;
    final definitions = schema['\$defs'] as Map<String, dynamic>;

    if (definitions.containsKey('GenerateActionOptions')) {
      final genOptions =
          definitions['GenerateActionOptions'] as Map<String, dynamic>;
      final props = genOptions['properties'] as Map<String, dynamic>? ?? {};
      if (props.containsKey('resume')) {
        definitions['GenerateResumeOptions'] = props['resume'];
      }
    }
    if (definitions.containsKey('GenerateActionOutputConfig')) {
      final genOptions =
          definitions['GenerateActionOutputConfig'] as Map<String, dynamic>;
      final props = genOptions['properties'] as Map<String, dynamic>? ?? {};
      if (!props.containsKey('defaultInstructions')) {
        props['defaultInstructions'] = {'type': 'boolean'};
      }
    }

    // The `AgentInput.resume` schema is an inline (anonymous) object. Promote
    // it to a named `$def` so it gets its own generated class.
    if (definitions.containsKey('AgentInput')) {
      final agentInput = definitions['AgentInput'] as Map<String, dynamic>;
      final props = agentInput['properties'] as Map<String, dynamic>? ?? {};
      if (props.containsKey('resume')) {
        definitions['AgentResume'] = props['resume'];
      }
    }

    // The structured error carried in agent outputs and snapshots is named
    // `RuntimeError` on the wire. Generate it under the Dart-internal name
    // `AgentErrorInfo` (to avoid colliding with the hand-written `AgentError`
    // exception class in agent_core.dart) by aliasing the `RuntimeError` def.
    if (definitions.containsKey('RuntimeError')) {
      definitions['AgentErrorInfo'] = definitions['RuntimeError'];
    }

    // The `getSnapshot` companion action input is named `GetSnapshotRequest` on
    // the wire. Generate it under the Dart-internal name `GetSnapshotDataInput`
    // by aliasing the `GetSnapshotRequest` def.
    if (definitions.containsKey('GetSnapshotRequest')) {
      definitions['GetSnapshotDataInput'] = definitions['GetSnapshotRequest'];
    }

    // The wire name `EvalStatusEnum` carries a type-kind suffix that is not
    // idiomatic in Dart. Generate it as `EvalStatus` and repoint `Score.status`.
    // The wire values (`PASS`, ...) are unchanged; the generator lowercases
    // only the Dart identifiers (see `_enumFieldName`).
    if (definitions.containsKey('EvalStatusEnum')) {
      definitions['EvalStatus'] = definitions.remove('EvalStatusEnum');
      final scoreProps =
          (definitions['Score'] as Map<String, dynamic>?)?['properties']
              as Map<String, dynamic>?;
      if (scoreProps != null && scoreProps.containsKey('status')) {
        scoreProps['status'] = {'\$ref': '#/\$defs/EvalStatus'};
      }
    }

    // `toolChoice` is an inline string enum (`auto`/`required`/`none`) on the
    // wire. Promote it to a named `$def` so it generates an open enum
    // (`extension type ToolChoice(String)`) rather than a bare `String?`, and
    // point every property that carries it at the new def.
    if (definitions.containsKey('GenerateRequest')) {
      final props =
          (definitions['GenerateRequest'] as Map<String, dynamic>)['properties']
              as Map<String, dynamic>;
      if (props['toolChoice'] is Map) {
        definitions['ToolChoice'] = props['toolChoice'];
        const ref = {'\$ref': '#/\$defs/ToolChoice'};
        for (final def in [
          'GenerateRequest',
          'ModelRequest',
          'GenerateActionOptions',
        ]) {
          final defProps =
              (definitions[def] as Map<String, dynamic>?)?['properties']
                  as Map<String, dynamic>?;
          if (defProps != null && defProps.containsKey('toolChoice')) {
            defProps['toolChoice'] = ref;
          }
        }
      }
    }

    final classGenerator = ClassGenerator(definitions);
    // Stable types first: the experimental library imports them, and the
    // shared generator skips anything already emitted.
    await _writeLibrary(
      'types.dart',
      classGenerator.generate(_allowlist, partFile: 'types.g.dart'),
    );
    await _writeLibrary(
      'experimental_types.dart',
      classGenerator.generate(
        _experimentalAllowlist,
        partFile: 'experimental_types.g.dart',
        imports: ['types.dart'],
      ),
    );
    await _writeLibrary(
      'core/reflection/reflection_types.dart',
      classGenerator.generate(
        _reflectionAllowlist,
        partFile: 'reflection_types.g.dart',
      ),
    );
  } else {
    throw Exception('Failed to fetch schema');
  }
}

Future<void> _writeLibrary(String fileName, String generatedContent) async {
  final outputFile = File(
    Platform.script.resolve('../../genkit/lib/src/$fileName').toFilePath(),
  );
  final fileContent = '''
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

// This file is generated by tool/schema_generator/bin/generate.dart.
// Do not edit this file manually.

$generatedContent''';
  await outputFile.writeAsString(fileContent);
  print('Successfully generated ${outputFile.absolute}');
}

const _allowlist = {
  'Candidate',
  'Message',
  'ToolDefinition',
  'Part',
  'TextPart',
  'MediaPart',
  'ToolRequestPart',
  'ToolResponsePart',
  'DataPart',
  'CustomPart',
  'BaseDataPoint',
  'EvalRequest',
  'EvalFnResponse',
  'EvalStatus',
  'Score',
  'ReasoningPart',
  'ResourcePart',
  'Media',
  'ToolRequest',
  'ToolResponse',
  'ModelInfo',
  'ModelRequest',
  'ModelResponse',
  'ModelResponseChunk',
  'MiddlewareRef',
  'RuntimeError',
  'GenerateResponse',
  'GenerateRequest',
  'GenerationUsage',
  'Operation',
  'OutputConfig',
  'FinishReason',
  'ToolChoice',
  'Role',
  'DocumentData',
  'GenerateActionOptions',
  'GenerateResumeOptions',
  'GenerateActionOutputConfig',
  'EmbedRequest',
  'EmbedResponse',
  'Embedding',
};

/// Types backing the experimental agent/session API. Generated into
/// `src/experimental_types.dart`, which is only exported from
/// `package:genkit/experimental_client.dart` (and, transitively,
/// `experimental.dart`), so they stay out of the stable surface.
const _experimentalAllowlist = {
  'AgentFinishReason',
  'AgentInit',
  'AgentInput',
  'AgentResume',
  'AgentOutput',
  'AgentErrorInfo',
  'AgentResult',
  'AgentStreamChunk',
  'AgentAbortRequest',
  'AgentAbortResponse',
  'AgentMetadata',
  'AgentStateManagement',
  'TurnEnd',
  'Artifact',
  'GetSnapshotDataInput',
  'JsonPatchOp',
  'JsonPatchOperation',
  'SessionSnapshot',
  'SessionState',
  'SnapshotStatus',
};

/// Reflection API (Dev UI protocol) payloads. Generated next to their only
/// consumer in `src/core/reflection/` and never exported: they are an
/// implementation detail of the reflection server, not user-facing API.
const _reflectionAllowlist = {
  'ReflectionCancelActionParams',
  'ReflectionCancelActionResponse',
  'ReflectionConfigureParams',
  'ReflectionEndInputStreamParams',
  'ReflectionListActionsResponse',
  'ReflectionListValuesParams',
  'ReflectionListValuesResponse',
  'ReflectionRegisterParams',
  'ReflectionRunActionParams',
  'ReflectionRunActionStateParams',
  'ReflectionSendInputStreamChunkParams',
  'ReflectionStreamChunkParams',
};
