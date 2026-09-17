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

/// Cooperative cancellation for Genkit actions and generation.
///
/// This is the Dart analog of the Web's `AbortController` / `AbortSignal`
/// split, expressed with Dart-idiomatic names: a [CancellationController] is
/// the writable side (the caller holds it and calls [CancellationController.cancel]),
/// while a [CancellationToken] is the read-only side that is threaded down
/// through actions, middleware, and models so they can observe cancellation.
///
/// It is intentionally dependency-free and browser-safe (no `dart:io`, no
/// `package:web`), built only on `Completer`.
library;

import 'dart:async';

import '../exception.dart';

/// A read-only view of a cancellation request.
///
/// A [CancellationToken] is what the framework hands to actions, middleware,
/// and models. Holders can *observe* cancellation but cannot *trigger* it (that
/// is the job of the [CancellationController] that created the token).
///
/// Cancellation is cooperative: nothing is force-killed. Long-running work is
/// expected to poll [isCancelled] / call [throwIfCancelled], await
/// [whenCancelled], or register an [onCancel] callback to tear down eagerly
/// (e.g. cancel a streaming HTTP subscription).
final class CancellationToken {
  CancellationToken._();

  final Completer<void> _completer = Completer<void>();
  final List<void Function(Object? reason)> _listeners = [];
  Object? _reason;

  /// Whether cancellation has been requested.
  bool get isCancelled => _completer.isCompleted;

  /// The optional reason passed to [CancellationController.cancel], or `null`.
  Object? get reason => _reason;

  /// Completes when the owning controller is cancelled.
  ///
  /// Every token is per-operation and tied to a real [CancellationController],
  /// so this future (and any awaiter) is released when the operation and its
  /// controller become unreachable. It is therefore safe to race against, e.g.
  /// `Future.any([work, token.whenCancelled])`.
  Future<void> get whenCancelled => _completer.future;

  /// Registers [callback] to run when this token is cancelled, and returns a
  /// disposer that unregisters it.
  ///
  /// Unlike [whenCancelled] (a one-shot future that can never be detached),
  /// this lets a caller-supplied token be reused across many operations without
  /// leaking per-operation handlers. If the token is already cancelled,
  /// [callback] runs synchronously and the returned disposer is a no-op.
  void Function() onCancel(void Function() callback) =>
      _register((_) => callback());

  /// Like [onCancel], but forwards the cancellation [reason] to [callback].
  ///
  /// Use this when relinking tokens so a caller-supplied reason (e.g.
  /// `controller.cancel('user pressed stop')`) survives across the hop instead
  /// of being dropped by a zero-arg tear-off.
  void Function() onCancelWithReason(void Function(Object? reason) callback) =>
      _register(callback);

  /// Links [child] to this token so that cancelling this token also cancels
  /// [child] with the same reason. Returns a disposer that unlinks.
  ///
  /// If this token is already cancelled, [child] is cancelled synchronously and
  /// the returned disposer is a no-op. Prefer this over
  /// `token.onCancel(child.cancel)`, which silently drops the reason.
  void Function() link(CancellationController child) =>
      onCancelWithReason(child.cancel);

  void Function() _register(void Function(Object? reason) callback) {
    if (_completer.isCompleted) {
      callback(_reason);
      return () {};
    }
    _listeners.add(callback);
    return () => _listeners.remove(callback);
  }

  /// Throws a [CancelledException] if cancellation has been requested.
  ///
  /// Call this at cooperative checkpoints (e.g. between turns of a generation
  /// loop) to bail out promptly.
  void throwIfCancelled() {
    if (isCancelled) {
      throw CancelledException(reason: _reason, token: this);
    }
  }

  void _cancel(Object? reason) {
    if (_completer.isCompleted) return;
    _reason = reason;
    _completer.complete();
    // Snapshot then clear so listeners that (re)register during fan-out don't
    // fire twice and can't be stranded in the list.
    final listeners = [..._listeners];
    _listeners.clear();
    for (final listener in listeners) {
      // Isolate listeners: one throwing callback must not abort the fan-out
      // (dropping the survivors, which were already cleared) nor escape
      // `CancellationController.cancel`, which is documented as idempotent and
      // non-throwing. Route failures to the ambient error handler instead.
      try {
        listener(reason);
      } catch (e, s) {
        Zone.current.handleUncaughtError(e, s);
      }
    }
  }
}

/// The writable side of a cancellation.
///
/// A caller creates a controller, passes its [token] into an operation (e.g.
/// `ai.generate(..., cancel: controller.token)`), and later calls [cancel] to
/// request that the operation stop.
///
/// This is the Dart analog of the Web `AbortController`.
final class CancellationController {
  /// The read-only token to hand to the operation being controlled.
  final CancellationToken token = CancellationToken._();

  /// Whether [cancel] has already been called.
  bool get isCancelled => token.isCancelled;

  /// Requests cancellation (idempotent). An optional [reason] is surfaced on
  /// [CancellationToken.reason] and the thrown `CancelledException`.
  void cancel([Object? reason]) => token._cancel(reason);
}

/// Thrown when an operation is aborted via a [CancellationToken].
///
/// Maps to [StatusCodes.CANCELLED]. Catch this to distinguish a cooperative
/// cancellation from other failures.
class CancelledException extends GenkitException {
  /// The token that produced this cancellation, when known.
  ///
  /// Lets a caller distinguish a cancellation of *its own* token from one that
  /// bubbled up from an unrelated token (e.g. a tool's internal timeout).
  final CancellationToken? token;

  CancelledException({Object? reason, this.token})
    : super(
        reason is String ? reason : 'Operation was cancelled',
        status: StatusCodes.CANCELLED,
        underlyingException: reason is String ? null : reason,
      );
}
