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

import 'dart:async';

import 'action.dart';

/// Default cache lifetime for a [DynamicActionProvider]'s listing, matching
/// JS's `SimpleCache` default of three seconds.
const _defaultDapTtlMillis = 3 * 1000;

/// Builds the DAP key stamped onto actions resolved through a provider so their
/// provenance survives into tool definitions, traces, and reflection. Mirrors
/// JS's `/dynamic-action-provider/<host>:<actionType>/<name>` format.
String dapActionKey(String host, ActionType actionType, String name) =>
    '/dynamic-action-provider/$host:${actionType.value}/$name';

/// Caches a [DynamicActionProvider]'s listing with a TTL and de-duplicates
/// concurrent refreshes, mirroring JS's `SimpleCache`.
class _DapCache {
  final int ttlMillis;
  List<ActionMetadata>? _value;
  DateTime? _expiresAt;
  Future<List<ActionMetadata>>? _inflight;

  _DapCache(this.ttlMillis);

  bool get _isStale {
    final value = _value;
    final expiresAt = _expiresAt;
    return value == null ||
        expiresAt == null ||
        ttlMillis < 0 ||
        DateTime.now().isAfter(expiresAt);
  }

  void setValue(List<ActionMetadata> value) {
    _value = value;
    _expiresAt = DateTime.now().add(Duration(milliseconds: ttlMillis));
  }

  void invalidate() {
    _value = null;
    _expiresAt = null;
  }

  Future<List<ActionMetadata>> getOrFetch(
    Future<List<ActionMetadata>> Function() fetch,
  ) {
    if (!_isStale) return Future.value(_value!);
    final existing = _inflight;
    if (existing != null) return existing;
    final future = () async {
      try {
        final value = await fetch();
        setValue(value);
        return value;
      } catch (_) {
        invalidate();
        rethrow;
      } finally {
        _inflight = null;
      }
    }();
    _inflight = future;
    return future;
  }
}

/// A provider that resolves actions (tools, prompts, resources) dynamically at
/// runtime rather than registering them statically. Backs integrations such as
/// the MCP host, where the available actions are discovered from a remote
/// server and may change over time.
///
/// The provider is itself an [Action]: refreshing its listing runs inside a
/// span so each refresh is traced (matching JS, where the DAP is a
/// `dynamic-action-provider` action and the cache calls `dap.run()`).
/// Reflection listing uses [getActionMetadataRecord], which skips the trace so
/// the Dev UI does not create a span every time it lists actions.
class DynamicActionProvider
    extends Action<void, List<ActionMetadata>, void, void> {
  final FutureOr<Iterable<ActionMetadata>> Function()? listActionsFn;
  final FutureOr<Action?> Function(ActionType actionType, String name)?
  getActionFn;

  final _DapCache _cache;

  /// Creates a dynamic action provider. [cacheTtlMillis] controls the listing
  /// cache lifetime (defaults to three seconds; negative disables caching).
  factory DynamicActionProvider({
    required String name,
    FutureOr<Iterable<ActionMetadata>> Function()? listActionsFn,
    FutureOr<Action?> Function(ActionType actionType, String name)? getActionFn,
    Map<String, dynamic>? metadata,
    int? cacheTtlMillis,
  }) {
    // Bind `fn` to the instance so running the provider action directly (e.g.
    // via the reflection `runAction` path) performs the same stamped fetch as
    // [listActions], matching JS where the cache calls `dap.run()`.
    late DynamicActionProvider provider;
    provider = DynamicActionProvider._(
      name: name,
      listActionsFn: listActionsFn,
      getActionFn: getActionFn,
      metadata: metadata,
      cacheTtlMillis: cacheTtlMillis,
      fn: (input, context) => provider._fetchAndStamp(),
    );
    return provider;
  }

  DynamicActionProvider._({
    required super.name,
    this.listActionsFn,
    this.getActionFn,
    super.metadata,
    int? cacheTtlMillis,
    required super.fn,
  }) : _cache = _DapCache(cacheTtlMillis ?? _defaultDapTtlMillis),
       super(actionType: .dynamicActionProvider);

  Future<List<ActionMetadata>> _fetchAndStamp() async {
    final fn = listActionsFn;
    if (fn == null) return const [];
    final actions = (await fn()).toList();
    for (final action in actions) {
      action.key ??= dapActionKey(name, action.actionType, action.name);
    }
    return actions;
  }

  /// Invalidates the cached listing so the next [listActions] refetches.
  void invalidateCache() => _cache.invalidate();

  /// Returns the provider's action listing, refreshing from source when the
  /// cache is stale. When [skipTrace] is false (the default) a refresh runs
  /// inside a span so it appears in traces.
  Future<List<ActionMetadata>> listActions({bool skipTrace = false}) {
    return _cache.getOrFetch(() async {
      // Skip the trace for Dev UI listing so it does not create a span every
      // time the actions are enumerated.
      if (skipTrace) return _fetchAndStamp();
      // Route through the action machinery so the refresh is a real span whose
      // `fn` performs the stamped fetch.
      return (await runRaw(null)).result;
    });
  }

  /// Resolves a single action by type and name, stamping its DAP [key].
  Future<Action?> getAction(ActionType actionType, String name) async {
    final fn = getActionFn;
    if (fn == null) return null;
    final action = await fn(actionType, name);
    if (action != null) {
      action.key ??= dapActionKey(this.name, action.actionType, action.name);
    }
    return action;
  }

  /// Returns metadata for actions of [actionType] matching [name], supporting
  /// `*` (all), a `prefix*` wildcard, and exact matches. Mirrors JS's
  /// `listActionMetadata`.
  Future<List<ActionMetadata>> listActionMetadata(
    ActionType actionType,
    String name,
  ) async {
    final all = await listActions();
    final typed = all.where((m) => m.actionType == actionType);
    if (name == '*') return typed.toList();
    if (name.endsWith('*')) {
      final prefix = name.substring(0, name.length - 1);
      return typed.where((m) => m.name.startsWith(prefix)).toList();
    }
    return typed.where((m) => m.name == name).toList();
  }

  /// Expands the provider into a map of DAP key to metadata, used by reflection
  /// (Dev UI) to surface individual dynamic actions. Skips the trace so listing
  /// does not create a span. Mirrors JS's `getActionMetadataRecord`.
  Future<Map<String, ActionMetadata>> getActionMetadataRecord() async {
    final result = <String, ActionMetadata>{};
    for (final meta in await listActions(skipTrace: true)) {
      final key = meta.key ?? dapActionKey(name, meta.actionType, meta.name);
      result[key] = meta;
    }
    return result;
  }
}
