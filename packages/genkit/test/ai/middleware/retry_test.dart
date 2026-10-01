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

import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/middleware/retry.dart' show retryDef;
import 'package:test/test.dart';

void main() {
  group('RetryMiddleware', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('should retry on failure up to maxRetries', () async {
      var attempts = 0;
      genkit.defineModel(
        name: 'fail-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Simulated Failure',
            status: StatusCode.unavailable,
          );
        },
      );

      try {
        await genkit.generate(
          model: modelRef('fail-model'),
          prompt: 'test',
          use: [
            retry(
              maxRetries: 3,
              initialDelay: const Duration(milliseconds: 1),
              maxDelay: const Duration(milliseconds: 5),
              jitter: false,
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Initial attempt (1) + 3 retries = 4 attempts total
      expect(attempts, 4);
    });

    test('should succeed if retry succeeds', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'flakey-model',
        fn: (req, ctx) async {
          attempts++;
          if (attempts < 3) {
            throw GenkitException(
              'Simulated Failure',
              status: StatusCode.unavailable,
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'Success')],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('flakey-model'),
        prompt: 'test',
        use: [
          retry(
            maxRetries: 3,
            initialDelay: const Duration(milliseconds: 1),
            maxDelay: const Duration(milliseconds: 5),
            jitter: false,
          ),
        ],
      );

      expect(attempts, 3);
      expect(result.text, 'Success');
    });

    test('should NOT retry on unknown status if not in allowed list', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'fatal-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Fatal Error',
            status: StatusCode.invalidArgument,
          ); // INVALID_ARGUMENT
        },
      );

      try {
        await genkit.generate(
          model: modelRef('fatal-model'),
          prompt: 'test',
          use: [
            retry(
              maxRetries: 3,
              initialDelay: const Duration(milliseconds: 1),
              maxDelay: const Duration(milliseconds: 5),
              jitter: false,
              statuses: [StatusCode.unavailable], // Only retry UNAVAILABLE
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      expect(attempts, 1);
    });

    test('should NOT retry model if retryModel is false', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'fail-model-disabled',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Simulated Failure',
            status: StatusCode.unavailable,
          );
        },
      );

      try {
        await genkit.generate(
          model: modelRef('fail-model-disabled'),
          prompt: 'test',
          use: [
            retry(
              maxRetries: 3,
              initialDelay: const Duration(milliseconds: 1),
              jitter: false,
              retryModel: false,
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Initial attempt only (1)
      expect(attempts, 1);
    });

    test('should retry tools if retryTools is true', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'tool-caller',
        fn: (req, ctx) async {
          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Final Answer')],
              ),
            );
          }
          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'fail-tool',
                    input: {'name': 'foo'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      genkit.defineTool(
        name: 'fail-tool',
        description: 'desc',
        inputSchema: null,
        fn: (input, ctx) async {
          attempts++;
          throw GenkitException('Tool Failure', status: StatusCode.unavailable);
        },
      );

      try {
        await genkit.generate(
          model: modelRef('tool-caller'),
          prompt: 'test',
          toolNames: ['fail-tool'],
          use: [
            retry(
              maxRetries: 3,
              initialDelay: const Duration(milliseconds: 1),
              jitter: false,
              retryTools: true,
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Initial (1) + 3 retries = 4
      expect(attempts, 4);
    });
    test('should use default statuses if statuses is empty', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'default-status-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Simulated Failure',
            status: StatusCode.unavailable,
          ); // UNAVAILABLE (in default list)
        },
      );

      try {
        await genkit.generate(
          model: modelRef('default-status-model'),
          prompt: 'test',
          use: [
            retry(
              maxRetries: 3,
              initialDelay: const Duration(milliseconds: 1),
              jitter: false,
              statuses: [], // Empty list should trigger defaults
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Should retry: 1 + 3 = 4
      expect(attempts, 4);
    });

    test('should resolve registered RetryMiddleware via retry() ref', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'ref-fail-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Simulated Failure',
            status: StatusCode.unavailable,
          );
        },
      );

      try {
        await genkit.generate(
          model: modelRef('ref-fail-model'),
          prompt: 'test',
          use: [
            retry(
              maxRetries: 2,
              initialDelay: const Duration(milliseconds: 1),
              jitter: false,
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Should retry: 1 + 2 = 3
      expect(attempts, 3);
    });

    test('retry() maps Durations and jitter onto the wire config', () {
      final ref = retry(
        initialDelay: const Duration(milliseconds: 250),
        maxDelay: const Duration(seconds: 10),
        jitter: false,
      );
      final json =
          jsonDecode(jsonEncode(ref.config!.toJson())) as Map<String, dynamic>;

      // Same field names and units as the JS SDK and the Dev UI.
      expect(json, {
        'initialDelayMs': 250,
        'maxDelayMs': 10000,
        'noJitter': true,
      });
      expect(jsonEncode(retry().config!.toJson()), '{}');
    });

    test('JSON config maps back to Durations', () {
      final m =
          retryDef.create(
                RetryOptions.fromJson({
                  'initialDelayMs': 250,
                  'maxDelayMs': 10000,
                  'noJitter': true,
                }),
                GenerateMiddlewareContext(ai: genkit),
              )
              as RetryMiddleware;
      expect(m.initialDelay, const Duration(milliseconds: 250));
      expect(m.maxDelay, const Duration(seconds: 10));
      expect(m.jitter, isFalse);

      final defaults =
          retryDef.create(null, GenerateMiddlewareContext(ai: genkit))
              as RetryMiddleware;
      expect(defaults.initialDelay, RetryMiddleware.defaultInitialDelay);
      expect(defaults.maxDelay, RetryMiddleware.defaultMaxDelay);
      expect(defaults.jitter, isTrue);
    });

    test('retry() serializes statuses as wire names', () {
      final ref = retry(
        statuses: [StatusCode.unavailable, StatusCode.resourceExhausted],
      );
      final json =
          jsonDecode(jsonEncode(ref.config!.toJson())) as Map<String, dynamic>;

      expect(json['statuses'], ['UNAVAILABLE', 'RESOURCE_EXHAUSTED']);
    });

    test('honors statuses from JSON config', () async {
      var attempts = 0;
      genkit.defineModel(
        name: 'json-config-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException('nope', status: StatusCode.notFound);
        },
      );

      // Same shape as config arriving from JSON (e.g. the Dev UI).
      final config = RetryOptions.fromJson({
        'maxRetries': 2,
        'initialDelayMs': 1,
        'noJitter': true,
        'statuses': ['NOT_FOUND'],
      });

      // Model errors surface as a `failed` response rather than a throw.
      final res = await genkit.generate(
        model: modelRef('json-config-model'),
        prompt: 'test',
        use: [middlewareRef(name: 'retry', config: config)],
      );

      // NOT_FOUND is not retried by default, so 3 attempts proves the JSON
      // config was applied.
      expect(attempts, 3);
      expect(res.error!.status, 'NOT_FOUND');
    });

    group('rejects unrecognized status names in config', () {
      for (final name in ['UNAVALIABLE', 'unavailable']) {
        test(name, () async {
          var attempts = 0;
          genkit.defineModel(
            name: 'bad-status-model',
            fn: (req, ctx) async {
              attempts++;
              return ModelResponse(finishReason: .stop);
            },
          );

          await expectLater(
            genkit.generate(
              model: modelRef('bad-status-model'),
              prompt: 'test',
              use: [
                middlewareRef(
                  name: 'retry',
                  config: RetryOptions.fromJson({
                    'statuses': [name],
                  }),
                ),
              ],
            ),
            throwsA(
              isA<GenkitException>()
                  .having((e) => e.status, 'status', StatusCode.invalidArgument)
                  .having((e) => e.message, 'message', contains('"$name"')),
            ),
          );
          // Rejected while resolving middleware, before any model call.
          expect(attempts, 0);
        });
      }
    });

    test('accepts UNKNOWN as a configured status', () async {
      var attempts = 0;
      genkit.defineModel(
        name: 'unknown-status-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException('nope', status: StatusCode.unknown);
        },
      );

      final res = await genkit.generate(
        model: modelRef('unknown-status-model'),
        prompt: 'test',
        use: [
          middlewareRef(
            name: 'retry',
            config: RetryOptions.fromJson({
              'maxRetries': 2,
              'initialDelayMs': 1,
              'noJitter': true,
              'statuses': ['UNKNOWN'],
            }),
          ),
        ],
      );

      // UNKNOWN is a real wire name, so it is honored rather than rejected.
      expect(attempts, 3);
      expect(res.error!.status, 'UNKNOWN');
    });

    test('a plugin middleware named retry overrides the built-in', () async {
      var overrideUsed = false;
      final ai = Genkit(
        isDevEnv: false,
        plugins: [
          _MiddlewarePlugin([
            defineMiddleware<Object?>(
              name: 'retry',
              create: (_, _) {
                overrideUsed = true;
                return RetryMiddleware(maxRetries: 0);
              },
            ),
          ]),
        ],
      );
      addTearDown(ai.shutdown);

      var attempts = 0;
      ai.defineModel(
        name: 'override-fail-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException('fail', status: StatusCode.unavailable);
        },
      );

      final response = await ai.generate(
        model: modelRef('override-fail-model'),
        prompt: 'test',
        use: [
          retry(maxRetries: 5, initialDelay: const Duration(milliseconds: 1)),
        ],
      );
      expect(response.finishReason, FinishReason.failed);
      expect(overrideUsed, isTrue);
      expect(attempts, 1);
    });
  });
}

final class _MiddlewarePlugin extends GenkitPlugin {
  final List<GenerateMiddlewareDef> _middleware;

  _MiddlewarePlugin(this._middleware);

  @override
  String get name => 'retry-override';

  @override
  List<GenerateMiddlewareDef> middleware() => _middleware;
}
