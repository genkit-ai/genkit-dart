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

/// Agent conformance test runner.
///
/// Ported from the Genkit JS `agents_spec_test.ts`. Reads the shared spec from
/// `test/ai/agents/specs/agent.yaml` and executes each test case against
/// harness-provided agent implementations. See
/// `docs/agents-conformance-testing.md` (in genkit-js) for the spec format.
library;

import 'dart:async';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

// ---------------------------------------------------------------------------
// YAML -> plain Dart conversion
// ---------------------------------------------------------------------------

dynamic _fromYaml(dynamic value) {
  if (value is YamlMap) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _fromYaml(entry.value),
    };
  }
  if (value is YamlList) {
    return <dynamic>[for (final item in value) _fromYaml(item)];
  }
  return value;
}

// ---------------------------------------------------------------------------
// Assertion helpers (mirroring the JS harness)
// ---------------------------------------------------------------------------

class _SpecError implements Exception {
  _SpecError(this.message);
  final String message;
  @override
  String toString() => message;
}

bool _deepEqual(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List && b is List) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!_deepEqual(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map && b is Map) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_deepEqual(a[key], b[key])) return false;
    }
    return true;
  }
  // Treat int/double equivalently for JSON-ish comparisons.
  if (a is num && b is num) return a == b;
  return a == b;
}

/// Asserts that [actual] contains all fields specified in [expected]. Arrays
/// are matched as ordered (non-contiguous) subsequences; objects as subsets;
/// scalars by deep equality.
void _assertContains(Object? actual, Object? expected, [String path = '']) {
  if (expected == null) return;

  if (expected is List) {
    if (actual is! List) {
      throw _SpecError('Expected array at $path, got ${actual.runtimeType}');
    }
    _assertContainsSubsequence(actual, expected, path);
    return;
  }

  if (expected is Map) {
    if (actual is! Map) {
      throw _SpecError('Expected object at $path, got ${actual.runtimeType}');
    }
    for (final entry in expected.entries) {
      _assertContains(actual[entry.key], entry.value, '$path.${entry.key}');
    }
    return;
  }

  if (!_deepEqual(actual, expected)) {
    throw _SpecError(
      'Mismatch at $path: expected ${_json(expected)}, got ${_json(actual)}',
    );
  }
}

void _assertContainsSubsequence(
  List<dynamic> actual,
  List<dynamic> expected,
  String path,
) {
  var actualIdx = 0;
  for (var i = 0; i < expected.length; i++) {
    var found = false;
    while (actualIdx < actual.length) {
      try {
        _assertContains(actual[actualIdx], expected[i], '$path[$actualIdx]');
        found = true;
        actualIdx++;
        break;
      } on _SpecError {
        actualIdx++;
      }
    }
    if (!found) {
      throw _SpecError(
        'Expected item at $path[$i] not found in actual array.\n'
        '  Expected: ${_json(expected[i])}\n'
        '  Actual array: ${_json(actual)}',
      );
    }
  }
}

String _json(Object? value) {
  try {
    return value.toString();
  } catch (_) {
    return '<unprintable>';
  }
}

// ---------------------------------------------------------------------------
// Template resolution
// ---------------------------------------------------------------------------

final _templateExact = RegExp(r'^\{\{(\w+)\}\}$');
final _templateInline = RegExp(r'\{\{(\w+)\}\}');

dynamic _resolveTemplates(dynamic value, Map<String, dynamic> captures) {
  if (value is String) {
    final exact = _templateExact.firstMatch(value);
    if (exact != null) {
      final name = exact.group(1)!;
      if (!captures.containsKey(name)) {
        throw _SpecError(
          "Template reference '{{$name}}' not found in captures",
        );
      }
      return captures[name];
    }
    return value.replaceAllMapped(_templateInline, (m) {
      final name = m.group(1)!;
      if (!captures.containsKey(name)) {
        throw _SpecError(
          "Template reference '{{$name}}' not found in captures",
        );
      }
      final v = captures[name];
      return v is String ? v : v.toString();
    });
  }
  if (value is List) {
    return [for (final item in value) _resolveTemplates(item, captures)];
  }
  if (value is Map) {
    return <String, dynamic>{
      for (final entry in value.entries)
        entry.key.toString(): _resolveTemplates(entry.value, captures),
    };
  }
  return value;
}

// ---------------------------------------------------------------------------
// Programmable model
// ---------------------------------------------------------------------------

typedef _HandleResponse =
    Future<ModelResponse> Function(
      ModelRequest req,
      void Function(ModelResponseChunk chunk)? sendChunk,
    );

class _ProgrammableModel {
  _HandleResponse handleResponse = (req, sc) async {
    throw StateError('programmableModel.handleResponse not programmed');
  };
  int requestCount = 0;
  ModelRequest? lastRequest;
}

// ---------------------------------------------------------------------------
// Harness setup
// ---------------------------------------------------------------------------

Map<String, Agent> _setupHarness(Genkit ai, _ProgrammableModel pm) {
  ai.defineModel(
    name: 'programmableModel',
    fn: (request, ctx) async {
      pm.requestCount++;
      pm.lastRequest = request;
      return pm.handleResponse(
        request,
        ctx.streamingRequested ? ctx.sendChunk : null,
      );
    },
  );

  // --- Tools ---
  ai.defineTool(
    name: 'testTool',
    description: 'A simple test tool',
    inputSchema: SchemanticType.map(
      SchemanticType.string(),
      SchemanticType.dynamicSchema(),
    ),
    fn: (input, ctx) async => 'tool called',
  );

  // interruptTool always pauses the turn and returns the tool request to the
  // client for external resolution.
  ai.defineTool(
    name: 'interruptTool',
    description: 'An interrupt tool',
    inputSchema: SchemanticType.map(
      SchemanticType.string(),
      SchemanticType.dynamicSchema(),
    ),
    fn: (input, ctx) async => ctx.interrupt(),
  );

  // restartTool pauses on first call and succeeds when resumed (the restart
  // carries `resumed` metadata).
  ai.defineTool(
    name: 'restartTool',
    description: 'A tool that requires confirmation before executing',
    inputSchema: SchemanticType.map(
      SchemanticType.string(),
      SchemanticType.dynamicSchema(),
    ),
    fn: (input, ctx) async {
      final resumed = ctx.resumed;
      if (resumed == null) {
        ctx.interrupt({'requiresConfirmation': true});
      }
      final action = input['action'];
      return {'result': 'confirmed: $action'};
    },
  );

  // --- Prompt-backed agents ---
  final promptAgent = ai.defineAgent(
    name: 'promptAgent',
    model: modelRef('programmableModel'),
  );

  final promptAgentWithStore = ai.defineAgent(
    name: 'promptAgentWithStore',
    model: modelRef('programmableModel'),
    store: InMemorySessionStore(),
  );

  final promptAgentWithTools = ai.defineAgent(
    name: 'promptAgentWithTools',
    model: modelRef('programmableModel'),
    toolNames: ['testTool'],
  );

  final promptAgentWithInterrupt = ai.defineAgent(
    name: 'promptAgentWithInterrupt',
    model: modelRef('programmableModel'),
    toolNames: ['interruptTool'],
    store: InMemorySessionStore(),
  );

  final promptAgentWithRestartTool = ai.defineAgent(
    name: 'promptAgentWithRestartTool',
    model: modelRef('programmableModel'),
    toolNames: ['restartTool'],
    store: InMemorySessionStore(),
  );

  // --- Custom agents ---
  final customAgentBlocking = ai.defineCustomAgent(
    name: 'customAgentBlocking',
    store: InMemorySessionStore(),
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        final cancel = options.cancel;
        if (cancel != null && !cancel.isCancelled) {
          await cancel.whenCancelled;
        }
        return null;
      });
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'unblocked')],
        ),
      );
    },
  );

  final customAgentFailing = ai.defineCustomAgent(
    name: 'customAgentFailing',
    store: InMemorySessionStore(),
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        // Throw a GenkitException so the surfaced error message is exactly
        // 'intentional failure' (matching the JS `new Error(...)` message).
        throw GenkitException('intentional failure');
      });
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'unreachable')],
        ),
      );
    },
  );

  final customAgentWithArtifacts = ai.defineCustomAgent(
    name: 'customAgentWithArtifacts',
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        sess.addArtifacts([
          Artifact(
            name: 'doc1',
            parts: [TextPart(text: 'v1')],
          ),
        ]);
        sess.addArtifacts([
          Artifact(
            name: 'doc1',
            parts: [TextPart(text: 'v2')],
          ),
        ]);
        sess.addArtifacts([
          Artifact(
            name: 'doc2',
            parts: [TextPart(text: 'other')],
          ),
        ]);
        return null;
      });
      return AgentResult(
        artifacts: sess.getArtifacts(),
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'done')],
        ),
      );
    },
  );

  final customAgentWithCustomState = ai.defineCustomAgent(
    name: 'customAgentWithCustomState',
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        final prev = (sess.getCustom() as Map?) ?? {};
        final counter = ((prev['counter'] as int?) ?? 0) + 1;
        sess.updateCustom((_) => {'counter': counter});
        return null;
      });
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'done')],
        ),
      );
    },
  );

  final customAgentWithMultiCustomState = ai.defineCustomAgent(
    name: 'customAgentWithMultiCustomState',
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        sess.updateCustom((_) => {'counter': 1, 'status': 'working'});
        sess.updateCustom(
          (prev) => {...(prev as Map).cast<String, dynamic>(), 'counter': 2},
        );
        sess.updateCustom(
          (prev) => {
            ...(prev as Map).cast<String, dynamic>(),
            'status': 'done',
          },
        );
        return null;
      });
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'done')],
        ),
      );
    },
  );

  final customAgentWithArtifactsStore = ai.defineCustomAgent(
    name: 'customAgentWithArtifactsStore',
    store: InMemorySessionStore(),
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        final existing = sess.getArtifacts();
        final count = existing.length + 1;
        sess.addArtifacts([
          Artifact(
            name: 'doc$count',
            parts: [TextPart(text: 'content$count')],
          ),
        ]);
        return null;
      });
      return AgentResult(
        artifacts: sess.getArtifacts(),
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'done')],
        ),
      );
    },
  );

  final customAgentWithCustomStateStore = ai.defineCustomAgent(
    name: 'customAgentWithCustomStateStore',
    store: InMemorySessionStore(),
    fn: (sess, options) async {
      await sess.run((input, ctx) async {
        final prev = (sess.getCustom() as Map?) ?? {};
        final counter = ((prev['counter'] as int?) ?? 0) + 1;
        sess.updateCustom((_) => {'counter': counter});
        return null;
      });
      return AgentResult(
        message: Message(
          role: Role.model,
          content: [TextPart(text: 'done')],
        ),
      );
    },
  );

  return {
    'promptAgent': promptAgent,
    'promptAgentWithStore': promptAgentWithStore,
    'promptAgentWithTools': promptAgentWithTools,
    'promptAgentWithInterrupt': promptAgentWithInterrupt,
    'promptAgentWithRestartTool': promptAgentWithRestartTool,
    'customAgentBlocking': customAgentBlocking,
    'customAgentFailing': customAgentFailing,
    'customAgentWithArtifacts': customAgentWithArtifacts,
    'customAgentWithCustomState': customAgentWithCustomState,
    'customAgentWithMultiCustomState': customAgentWithMultiCustomState,
    'customAgentWithArtifactsStore': customAgentWithArtifactsStore,
    'customAgentWithCustomStateStore': customAgentWithCustomStateStore,
  };
}

// ---------------------------------------------------------------------------
// Step executors
// ---------------------------------------------------------------------------

Future<void> _executeSend(
  Agent agent,
  _ProgrammableModel pm,
  Map<String, dynamic> step,
  Map<String, dynamic> captures,
) async {
  final resolved = _resolveTemplates(step, captures) as Map<String, dynamic>;

  final modelResponses = resolved['modelResponses'] as List?;
  final streamChunks = resolved['streamChunks'] as List?;

  if (modelResponses != null || streamChunks != null) {
    var reqCounter = 0;
    pm.handleResponse = (req, sc) async {
      if (streamChunks != null &&
          reqCounter < streamChunks.length &&
          streamChunks[reqCounter] != null &&
          sc != null) {
        for (final chunk in (streamChunks[reqCounter] as List)) {
          sc(
            ModelResponseChunk.fromJson(
              Map<String, dynamic>.from(chunk as Map),
            ),
          );
        }
      }
      final resp = ModelResponse.fromJson(
        Map<String, dynamic>.from(modelResponses![reqCounter] as Map),
      );
      reqCounter++;
      return resp;
    };
  }

  final initMap = (resolved['init'] as Map?) ?? const {};
  final init = AgentInit.fromJson(Map<String, dynamic>.from(initMap));

  final bidi = agent.action.streamBidi(init: init);

  final inputs = (resolved['inputs'] as List?) ?? const [];
  for (final input in inputs) {
    bidi.send(AgentInput.fromJson(Map<String, dynamic>.from(input as Map)));
  }
  // Do not await: on early-exit paths (e.g. pre-turn validation failures) the
  // agent returns before consuming the input stream, so the underlying
  // controller's close() future would never complete. Mirrors JS's
  // unawaited `session.close()`.
  unawaited(bidi.close());

  // --- expectError: an API-misuse case that must THROW rather than resolve
  // gracefully. The thrown error (an AgentInitError / GenkitException) surfaces
  // through the bidi stream or its result future; assert its status + message.
  final expectError = resolved['expectError'];
  if (expectError is Map) {
    Object? thrown;
    try {
      await for (final _ in bidi) {
        // Drain any chunks emitted before the error.
      }
      await bidi.onResult;
    } catch (e) {
      thrown = e;
    }
    if (thrown == null) {
      throw _SpecError(
        'Expected the turn to throw $expectError, but it resolved normally.',
      );
    }
    final status = thrown is GenkitException ? thrown.status.name : null;
    final message = thrown is GenkitException
        ? thrown.message
        : thrown.toString();
    if (expectError['status'] != null && status != expectError['status']) {
      throw _SpecError(
        "Expected thrown error.status '${expectError['status']}', "
        "got '$status' (message: $message)",
      );
    }
    if (expectError['message'] != null &&
        !message.contains(expectError['message'] as String)) {
      throw _SpecError(
        "Expected thrown error.message to contain '${expectError['message']}', "
        'got: $message',
      );
    }
    return;
  }

  final chunks = <AgentStreamChunk>[];
  await for (final chunk in bidi) {
    chunks.add(chunk);
  }
  final output = await bidi.onResult;

  // --- expectChunks: strict ordered comparison ---
  final expectChunks = resolved['expectChunks'] as List?;

  if (expectChunks != null) {
    final actualChunks = chunks.map((c) => c.toJson()).toList();
    if (actualChunks.length != expectChunks.length) {
      throw _SpecError(
        'Expected ${expectChunks.length} chunks, got ${actualChunks.length}.\n'
        '  Actual: $actualChunks\n'
        '  Expected: $expectChunks',
      );
    }
    for (var i = 0; i < expectChunks.length; i++) {
      final expected = expectChunks[i] as Map;
      final actual = actualChunks[i];
      if (expected.containsKey('turnEnd')) {
        if (actual['turnEnd'] == null) {
          throw _SpecError('Chunk $i: expected turnEnd, got $actual');
        }
        final expTurnEnd = expected['turnEnd'] as Map?;
        if (expTurnEnd != null && expTurnEnd['finishReason'] != null) {
          final actualReason = (actual['turnEnd'] as Map?)?['finishReason'];
          if (actualReason != expTurnEnd['finishReason']) {
            throw _SpecError(
              'Chunk $i: expected turnEnd.finishReason '
              "'${expTurnEnd['finishReason']}', got '$actualReason'",
            );
          }
        }
      } else if (expected.containsKey('modelChunk')) {
        _assertContains(
          actual['modelChunk'],
          expected['modelChunk'],
          'chunk[$i].modelChunk',
        );
      } else if (expected.containsKey('artifact')) {
        _assertContains(
          actual['artifact'],
          expected['artifact'],
          'chunk[$i].artifact',
        );
      } else if (expected.containsKey('customPatch')) {
        _assertContains(
          actual['customPatch'],
          expected['customPatch'],
          'chunk[$i].customPatch',
        );
      } else {
        _assertContains(actual, expected, 'chunk[$i]');
      }
    }
  }

  // --- expectOutput ---
  final expectOutput = resolved['expectOutput'] as Map?;
  if (expectOutput != null) {
    if (expectOutput['message'] != null) {
      _assertContains(
        output.message?.toJson(),
        expectOutput['message'],
        'output.message',
      );
    }
    if (expectOutput['hasSnapshotId'] == true) {
      if (output.snapshotId == null || output.snapshotId!.isEmpty) {
        throw _SpecError(
          'Expected output to have a snapshotId, got: ${output.snapshotId}',
        );
      }
    }
    if (expectOutput['hasSessionId'] == true) {
      final sid = output.state?.sessionId;
      if (sid == null || sid.isEmpty) {
        throw _SpecError(
          'Expected output.state to have a sessionId, got: $sid',
        );
      }
    }
    if (expectOutput['stateContains'] != null) {
      if (output.state == null) {
        throw _SpecError('Expected output to have state');
      }
      _assertContains(
        output.state!.toJson(),
        expectOutput['stateContains'],
        'output.state',
      );
    }
    if (expectOutput['artifactsContain'] != null) {
      final artifacts = output.artifacts;
      if (artifacts == null) {
        throw _SpecError('Expected output to have artifacts');
      }
      for (final expectedArt in (expectOutput['artifactsContain'] as List)) {
        final name = (expectedArt as Map)['name'];
        final found = artifacts.where((a) => a.name == name).firstOrNull;
        if (found == null) {
          throw _SpecError('Expected artifact `$name` not found in output');
        }
        _assertContains(found.toJson(), expectedArt, 'artifact($name)');
      }
    }
    if (expectOutput['finishReason'] != null) {
      final actualReason = output.finishReason?.value;
      if (actualReason != expectOutput['finishReason']) {
        throw _SpecError(
          "Expected output.finishReason '${expectOutput['finishReason']}', "
          "got '$actualReason'",
        );
      }
    }
    if (expectOutput['errorContains'] != null) {
      final error = output.error;
      if (error == null) {
        throw _SpecError('Expected output to have an error, got: null');
      }
      final errExp = expectOutput['errorContains'] as Map;
      if (errExp['status'] != null && error.status != errExp['status']) {
        throw _SpecError(
          "Expected output.error.status '${errExp['status']}', "
          "got '${error.status}'",
        );
      }
      if (errExp['message'] != null &&
          !error.message.contains(errExp['message'] as String)) {
        throw _SpecError(
          "Expected output.error.message to contain '${errExp['message']}', "
          'got: ${error.message}',
        );
      }
    }
  }

  // --- captures ---
  if (step['captureSnapshotId'] != null) {
    if (output.snapshotId == null) {
      throw _SpecError(
        "captureSnapshotId '${step['captureSnapshotId']}' requested but "
        'output has no snapshotId',
      );
    }
    captures[step['captureSnapshotId'] as String] = output.snapshotId;
  }
  if (step['captureState'] != null) {
    if (output.state == null) {
      throw _SpecError(
        "captureState '${step['captureState']}' requested but output has no "
        'state',
      );
    }
    captures[step['captureState'] as String] = output.state!.toJson();
  }
  if (step['captureSessionId'] != null) {
    final sid = output.state?.sessionId;
    if (sid == null) {
      throw _SpecError(
        "captureSessionId '${step['captureSessionId']}' requested but output "
        'has no state.sessionId',
      );
    }
    captures[step['captureSessionId'] as String] = sid;
  }
}

Future<void> _executeGetSnapshotData(
  Agent agent,
  Map<String, dynamic> step,
  Map<String, dynamic> captures,
) async {
  final resolved = _resolveTemplates(step, captures) as Map<String, dynamic>;
  final snapshotId = resolved['snapshotId'] as String?;
  final sessionId = resolved['sessionId'] as String?;

  if ((snapshotId != null) == (sessionId != null)) {
    throw _SpecError(
      'getSnapshotData invocation requires exactly one of snapshotId or '
      'sessionId',
    );
  }

  if (resolved['expectError'] != null) {
    final expectErr = resolved['expectError'] as String;
    try {
      await agent.getSnapshotData(snapshotId: snapshotId, sessionId: sessionId);
      throw _SpecError(
        'Expected error containing "$expectErr" but getSnapshotData succeeded',
      );
    } on _SpecError {
      rethrow;
    } catch (e) {
      final msg = e is GenkitException ? e.message : e.toString();
      if (!msg.contains(expectErr)) {
        throw _SpecError('Expected error containing `$expectErr`, got: $msg');
      }
    }
    return;
  }

  final snapshot = await agent.getSnapshotData(
    snapshotId: snapshotId,
    sessionId: sessionId,
  );
  if (snapshot == null) {
    throw _SpecError('Snapshot not found for ${snapshotId ?? sessionId}');
  }

  _assertSnapshot(snapshot, resolved['expectSnapshot'] as Map?);
}

void _assertSnapshot(SessionSnapshot snapshot, Map? expect) {
  if (expect == null) return;

  if (expect['parentId'] != null && snapshot.parentId != expect['parentId']) {
    throw _SpecError(
      "Expected parentId '${expect['parentId']}', got '${snapshot.parentId}'",
    );
  }
  if (expect['status'] != null && snapshot.status?.value != expect['status']) {
    throw _SpecError(
      "Expected status '${expect['status']}', got '${snapshot.status?.value}'",
    );
  }
  if (expect['finishReason'] != null) {
    final actual = snapshot.finishReason?.value;
    if (actual != expect['finishReason']) {
      throw _SpecError(
        "Expected finishReason '${expect['finishReason']}', got '$actual'",
      );
    }
  }
  if (expect['hasSessionId'] == true) {
    final sid = snapshot.state?.sessionId;
    if (sid == null || sid.isEmpty) {
      throw _SpecError(
        'Expected snapshot.state to have a sessionId, got: $sid',
      );
    }
  }
  if (expect['stateContains'] != null) {
    if (snapshot.state == null) {
      throw _SpecError('Expected snapshot to have state');
    }
    _assertContains(
      snapshot.state!.toJson(),
      expect['stateContains'],
      'snapshot.state',
    );
  }

  if (expect['errorContains'] != null) {
    if (snapshot.error == null) {
      throw _SpecError('Expected snapshot to have error');
    }
    _assertContains(
      snapshot.error!.toJson(),
      expect['errorContains'],
      'snapshot.error',
    );
  }
}

Future<void> _executeAbort(
  Agent agent,
  Map<String, dynamic> step,
  Map<String, dynamic> captures,
) async {
  final resolved = _resolveTemplates(step, captures) as Map<String, dynamic>;
  final snapshotId = resolved['snapshotId'] as String?;
  if (snapshotId == null) {
    throw _SpecError('abort invocation requires snapshotId');
  }

  final previousStatus = await agent.abort(snapshotId);

  if (resolved.containsKey('expectPreviousStatus')) {
    final expected = resolved['expectPreviousStatus']; // null means absent
    if (previousStatus != expected) {
      throw _SpecError(
        "Expected previous status '$expected', got '$previousStatus'",
      );
    }
  }
}

Future<void> _executeWaitUntilCompleted(
  Agent agent,
  Map<String, dynamic> step,
  Map<String, dynamic> captures,
) async {
  final resolved = _resolveTemplates(step, captures) as Map<String, dynamic>;
  final snapshotId = resolved['snapshotId'] as String?;
  final timeoutMs = (resolved['timeoutMs'] as int?) ?? 5000;
  if (snapshotId == null) {
    throw _SpecError('waitUntilCompleted invocation requires snapshotId');
  }

  const terminal = {'completed', 'failed', 'aborted'};
  final start = DateTime.now();
  SessionSnapshot? snapshot;
  while (DateTime.now().difference(start).inMilliseconds < timeoutMs) {
    snapshot = await agent.getSnapshotData(snapshotId: snapshotId);
    if (snapshot != null && terminal.contains(snapshot.status?.value)) {
      break;
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }

  if (snapshot == null) {
    throw _SpecError('Snapshot $snapshotId not found after waiting');
  }
  if (!terminal.contains(snapshot.status?.value)) {
    throw _SpecError(
      'Snapshot $snapshotId did not reach terminal status within ${timeoutMs}ms.'
      ' Status: ${snapshot.status}',
    );
  }

  _assertSnapshot(snapshot, resolved['expectSnapshot'] as Map?);
}

// ---------------------------------------------------------------------------
// Spec loading + runner
// ---------------------------------------------------------------------------

File _specFile() {
  const candidates = [
    'test/ai/agents/specs/agent.yaml',
    'packages/genkit/test/ai/agents/specs/agent.yaml',
  ];
  for (final c in candidates) {
    final f = File(c);
    if (f.existsSync()) return f;
  }
  throw StateError(
    'agent.yaml spec not found (cwd: ${Directory.current.path})',
  );
}

void main() {
  final spec =
      _fromYaml(loadYaml(_specFile().readAsStringSync()))
          as Map<String, dynamic>;
  final tests = (spec['tests'] as List).cast<Map<String, dynamic>>();

  group('Agent conformance spec', () {
    late Genkit ai;
    late _ProgrammableModel pm;
    late Map<String, Agent> agents;

    setUp(() {
      ai = Genkit(promptDir: null);
      pm = _ProgrammableModel();
      agents = _setupHarness(ai, pm);
    });

    tearDown(() => ai.shutdown());

    for (final testCase in tests) {
      final name = testCase['name'] as String;
      test(name, () async {
        final agent = agents[testCase['agent']];
        if (agent == null) {
          fail("Unknown agent '${testCase['agent']}' in test '$name'");
        }

        final captures = <String, dynamic>{};
        final steps = (testCase['steps'] as List).cast<Map<String, dynamic>>();

        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          final type = step['type'] as String;
          final label = 'step[$i] ($type)';
          try {
            switch (type) {
              case 'send':
                await _executeSend(agent, pm, step, captures);
              case 'getSnapshotData':
                await _executeGetSnapshotData(agent, step, captures);
              case 'abort':
                await _executeAbort(agent, step, captures);
              case 'waitUntilCompleted':
                await _executeWaitUntilCompleted(agent, step, captures);
              default:
                fail('Unknown step type: $type');
            }
          } catch (e) {
            fail("$label in test '$name' failed: $e");
          }
        }
      });
    }
  });
}
