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

import 'dart:async';

import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('CancellationController / CancellationToken', () {
    test('token starts uncancelled', () {
      final controller = CancellationController();
      expect(controller.token.isCancelled, isFalse);
      expect(controller.isCancelled, isFalse);
    });

    test('cancel() flips isCancelled on both sides', () {
      final controller = CancellationController();
      controller.cancel();
      expect(controller.isCancelled, isTrue);
      expect(controller.token.isCancelled, isTrue);
    });

    test('whenCancelled completes on cancel', () async {
      final controller = CancellationController();
      var completed = false;
      unawaited(controller.token.whenCancelled.then((_) => completed = true));
      expect(completed, isFalse);
      controller.cancel();
      await controller.token.whenCancelled;
      expect(completed, isTrue);
    });

    test('cancel is idempotent', () {
      final controller = CancellationController();
      var fired = 0;
      controller.token.onCancel(() => fired++);
      controller
        ..cancel()
        ..cancel();
      expect(fired, 1);
    });

    test('reason is surfaced on the token', () {
      final controller = CancellationController();
      controller.cancel('stopped by user');
      expect(controller.token.reason, 'stopped by user');
    });

    test('throwIfCancelled throws a CancelledException when cancelled', () {
      final controller = CancellationController()..cancel('nope');
      expect(
        controller.token.throwIfCancelled,
        throwsA(
          isA<CancelledException>()
              .having((e) => e.status, 'status', StatusCodes.CANCELLED)
              .having((e) => e.message, 'message', 'nope'),
        ),
      );
    });

    test('throwIfCancelled is a no-op when not cancelled', () {
      final controller = CancellationController();
      expect(controller.token.throwIfCancelled, returnsNormally);
    });

    group('CancellationToken.none', () {
      test('never reports cancelled', () {
        expect(CancellationToken.none.isCancelled, isFalse);
        expect(CancellationToken.none.throwIfCancelled, returnsNormally);
      });
    });
  });

  group('Action cancellation', () {
    Action<String, String, void, void> echoAction({
      Future<void> Function(ActionFnArg<void, String, void> ctx)? onRun,
    }) {
      return Action<String, String, void, void>(
        name: 'echo',
        actionType: .custom,
        fn: (input, ctx) async {
          if (onRun != null) await onRun(ctx);
          ctx.cancel.throwIfCancelled();
          return 'echo:$input';
        },
      );
    }

    test('runs normally without a token', () async {
      final action = echoAction();
      expect(await action.call('hi'), 'echo:hi');
    });

    test('throws immediately when the token is already cancelled', () async {
      final action = echoAction();
      final controller = CancellationController()..cancel();
      await expectLater(
        action.call('hi', cancel: controller.token),
        throwsA(isA<CancelledException>()),
      );
    });

    test('the action body observes ctx.cancel', () async {
      final controller = CancellationController();
      final action = echoAction(
        onRun: (ctx) async {
          // Simulate cancellation arriving during execution.
          controller.cancel();
        },
      );
      await expectLater(
        action.call('hi', cancel: controller.token),
        throwsA(isA<CancelledException>()),
      );
    });

    test('ctx.cancel defaults to none when no token is supplied', () async {
      CancellationToken? seen;
      final action = Action<String, String, void, void>(
        name: 'peek',
        actionType: .custom,
        fn: (input, ctx) async {
          seen = ctx.cancel;
          return input!;
        },
      );
      await action.call('x');
      expect(seen, same(CancellationToken.none));
    });

    test('onCancel hook fires when the token is cancelled mid-run', () async {
      final controller = CancellationController();
      var torndown = false;
      final action = Action<String, String, void, void>(
        name: 'teardown',
        actionType: .custom,
        fn: (input, ctx) async {
          ctx.cancel.onCancel(() => torndown = true);
          controller.cancel();
          await Future<void>.delayed(Duration.zero);
          return input!;
        },
      );
      await action.call('x', cancel: controller.token);
      expect(torndown, isTrue);
    });
  });
}
