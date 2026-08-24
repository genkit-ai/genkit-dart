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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/src/known_models.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  /// Builds a plugin whose Anthropic client answers `GET /v1/models` with the
  /// given model ids (and nothing else hits the network).
  AnthropicPluginImpl pluginListing(List<String> modelIds) {
    final mock = MockClient((request) async {
      if (request.url.path == '/v1/models') {
        return http.Response(
          jsonEncode({
            'data': [
              for (final id in modelIds)
                {
                  'id': id,
                  'display_name': id,
                  'created_at': '2025-01-01T00:00:00Z',
                  'type': 'model',
                },
            ],
            'has_more': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response('not found', 404);
    });
    return AnthropicPluginImpl(apiKey: 'test-key', httpClient: mock);
  }

  /// Offline plugin — no request is issued when only [resolve] is exercised.
  AnthropicPluginImpl plugin() => AnthropicPluginImpl(apiKey: 'test-key');

  Map<String, dynamic> modelInfoOf(Action action) =>
      (action.metadata['model'] as Map).cast<String, dynamic>();

  group('known model resolution', () {
    for (final model in KnownClaudeModel.values) {
      test('${model.id} resolves with curated metadata', () {
        final action = plugin().resolve('model', model.id);

        expect(action, isNotNull);
        final info = modelInfoOf(action!);
        expect(info['label'], model.label);
        expect(info['stage'], 'stable');
        expect(
          (info['supports'] as Map).cast<String, dynamic>(),
          model.info.supports,
        );
      });
    }

    test('unknown model falls back to common metadata', () {
      final action = plugin().resolve('model', 'claude-unknown-model');

      expect(action, isNotNull);
      final info = modelInfoOf(action!);
      expect(info['supports'], commonModelInfo.supports);
      expect(info.containsKey('stage'), isFalse);
    });

    test('non-model action types do not resolve', () {
      expect(plugin().resolve('embedder', 'claude-opus-4-8'), isNull);
    });
  });

  group('list', () {
    test('includes curated models missing from discovery', () async {
      final actions = await pluginListing(['claude-3-5-sonnet-latest']).list();
      final names = actions.map((a) => a.name).toList();

      expect(names, contains('anthropic/claude-3-5-sonnet-latest'));
      for (final model in KnownClaudeModel.values) {
        expect(names, contains('anthropic/${model.id}'));
      }

      final curated = actions.firstWhere(
        (a) => a.name == 'anthropic/claude-opus-4-8',
      );
      final info = (curated.metadata['model'] as Map).cast<String, dynamic>();
      expect(info['label'], 'Claude Opus 4.8');
      expect(info['stage'], 'stable');
    });

    test('does not duplicate curated models returned by discovery', () async {
      final actions = await pluginListing([
        'claude-opus-4-8',
        'claude-3-haiku',
      ]).list();
      final names = actions.map((a) => a.name).toList();

      expect(
        names.where((n) => n == 'anthropic/claude-opus-4-8'),
        hasLength(1),
      );

      // Discovered entry still carries the curated metadata.
      final discovered = actions.firstWhere(
        (a) => a.name == 'anthropic/claude-opus-4-8',
      );
      final info = (discovered.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(info['label'], 'Claude Opus 4.8');
      expect(info['stage'], 'stable');

      // A discovered, non-curated model falls back to common metadata.
      final generic = actions.firstWhere(
        (a) => a.name == 'anthropic/claude-3-haiku',
      );
      final genericInfo = (generic.metadata['model'] as Map)
          .cast<String, dynamic>();
      expect(genericInfo['supports'], commonModelInfo.supports);
      expect(genericInfo.containsKey('stage'), isFalse);
    });

    test(
      'enriches dated snapshot ids and does not duplicate their alias',
      () async {
        // The models endpoint returns dated ids; the curated alias must not be
        // appended again, and the dated entry must carry curated metadata.
        final actions = await pluginListing([
          'claude-haiku-4-5-20251001',
        ]).list();
        final names = actions.map((a) => a.name).toList();

        expect(names, contains('anthropic/claude-haiku-4-5-20251001'));
        expect(names, isNot(contains('anthropic/claude-haiku-4-5')));

        final dated = actions.firstWhere(
          (a) => a.name == 'anthropic/claude-haiku-4-5-20251001',
        );
        final info = (dated.metadata['model'] as Map).cast<String, dynamic>();
        expect(info['label'], 'Claude Haiku 4.5');
        expect(info['stage'], 'stable');
      },
    );

    test('falls back to the curated catalog when discovery fails', () async {
      // A 401 is a non-retryable client error, so the SDK surfaces it
      // immediately (no retry backoff) and list() takes the fallback path.
      final plugin = AnthropicPluginImpl(
        apiKey: 'test-key',
        httpClient: MockClient((_) async => http.Response('unauthorized', 401)),
      );

      final names = (await plugin.list()).map((a) => a.name).toSet();
      for (final model in KnownClaudeModel.values) {
        expect(names, contains('anthropic/${model.id}'));
      }
    });
  });

  group('KnownClaudeModel', () {
    test('info carries the label, stable stage, and shared supports', () {
      for (final model in KnownClaudeModel.values) {
        final info = model.info;
        expect(info.label, model.label);
        expect(info.stage, 'stable');
        expect(info.supports, {
          'multiturn': true,
          'media': true,
          'tools': true,
          'toolChoice': true,
          'systemRole': true,
          'constrained': true,
        });
      }
    });

    test('supports map is unmodifiable', () {
      expect(
        () => KnownClaudeModel.opus48.info.supports!['multiturn'] = false,
        throwsUnsupportedError,
      );
    });
  });

  group('knownClaudeModels', () {
    test('exposes the curated bare model names', () {
      expect(
        knownClaudeModels.keys,
        containsAll([
          'claude-fable-5',
          'claude-opus-4-8',
          'claude-opus-4-7',
          'claude-sonnet-5',
          'claude-sonnet-4-6',
          'claude-sonnet-4-5',
          'claude-haiku-4-5',
        ]),
      );
    });

    test('is derived from the enum, keyed by bare model id', () {
      expect(
        knownClaudeModels.keys,
        unorderedEquals([for (final m in KnownClaudeModel.values) m.id]),
      );
      for (final model in KnownClaudeModel.values) {
        expect(knownClaudeModels[model.id]!.label, model.label);
      }
    });
  });
}
