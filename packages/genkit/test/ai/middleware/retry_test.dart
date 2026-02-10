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

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('RetryMiddleware', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, plugins: [RetryPlugin()]);
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
            status: StatusCodes.UNAVAILABLE,
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
              initialDelayMs: 1,
              maxDelayMs: 5,
              noJitter: true,
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
              status: StatusCodes.UNAVAILABLE,
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
            initialDelayMs: 1,
            maxDelayMs: 5,
            noJitter: true,
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
            status: StatusCodes.INVALID_ARGUMENT,
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
              initialDelayMs: 1,
              maxDelayMs: 5,
              noJitter: true,
              statuses: [StatusCodes.UNAVAILABLE], // Only retry UNAVAILABLE
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      expect(attempts, 1);
    });

    test('should call onError callback', () async {
      var errors = <Object>[];
      var attemptsInCallback = <int>[];

      genkit.defineModel(
        name: 'callback-model',
        fn: (req, ctx) async {
          throw GenkitException('Fail', status: StatusCodes.UNAVAILABLE);
        },
      );

      try {
        await genkit.generate(
          model: modelRef('callback-model'),
          prompt: 'test',
          use: [
            RetryMiddleware(
              maxRetries: 2,
              initialDelayMs: 1,
              noJitter: true,
              onError: (e, attempt) {
                errors.add(e);
                attemptsInCallback.add(attempt);
                return true; // Continue retry
              },
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      expect(errors.length, 2);
      expect(attemptsInCallback, [1, 2]);
    });

    test('should stop retry if onError returns false', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'cancel-model',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException('Fail', status: StatusCodes.UNAVAILABLE);
        },
      );

      try {
        await genkit.generate(
          model: modelRef('cancel-model'),
          prompt: 'test',
          use: [
            RetryMiddleware(
              maxRetries: 5,
              initialDelayMs: 1,
              noJitter: true,
              onError: (e, attempt) {
                // Verify we stop after 2 attempts (1 retry)
                return attempt < 2;
              },
            ),
          ],
        );
      } catch (e) {
        // Expected
      }

      // Initial (1) + Retry 1 (returns true) + Retry 2 (returns false, stops before delay/call)
      // Wait, if stops, it rethrows.
      // 1. Call model (attempt 1). Fails.
      // 2. Catch. attempt=0. Max retries ok. Status ok. attempt++ (now 1).
      // 3. onError(1). Returns true.
      // 4. Delay. Loop.
      // 5. Call model (attempt 2). Fails.
      // 6. Catch. attempt=1. Max retries ok. Status ok. attempt++ (now 2).
      // 7. onError(2). Returns false.
      // 8. Rethrow.
      //
      // So model was called 2 times.
      expect(attempts, 2);
    });
    test('should NOT retry model if retryModel is false', () async {
      var attempts = 0;

      genkit.defineModel(
        name: 'fail-model-disabled',
        fn: (req, ctx) async {
          attempts++;
          throw GenkitException(
            'Simulated Failure',
            status: StatusCodes.UNAVAILABLE,
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
              initialDelayMs: 1,
              noJitter: true,
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
          throw GenkitException(
            'Tool Failure',
            status: StatusCodes.UNAVAILABLE,
          );
        },
      );

      try {
        await genkit.generate(
          model: modelRef('tool-caller'),
          prompt: 'test',
          tools: ['fail-tool'],
          use: [
            retry(
              maxRetries: 3,
              initialDelayMs: 1,
              noJitter: true,
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
            status: StatusCodes.UNAVAILABLE,
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
              initialDelayMs: 1,
              noJitter: true,
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
            status: StatusCodes.UNAVAILABLE,
          );
        },
      );

      try {
        await genkit.generate(
          model: modelRef('ref-fail-model'),
          prompt: 'test',
          use: [retry(maxRetries: 2, initialDelayMs: 1, noJitter: true)],
        );
      } catch (e) {
        // Expected
      }

      // Should retry: 1 + 2 = 3
      expect(attempts, 3);
    });
  });
}
