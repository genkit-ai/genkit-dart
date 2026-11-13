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

/// The scenario DSL: a scenario is a list of steps. [Say], [Press] and [Fill]
/// drive the conversation; [Expect] checks run against the turn before them.
library;

import 'dart:convert';

import 'renderer.dart';

/// A scripted conversation.
final class Scenario {
  const Scenario(this.name, this.steps, {this.description});

  final String name;
  final String? description;
  final List<Step> steps;
}

sealed class Step {
  const Step();
}

/// The user types [text].
final class Say extends Step {
  const Say(this.text);
  final String text;
}

/// The user presses the button whose visible label contains [button] on the
/// surface [on] (or any of the [or] alternatives, since the model picks the
/// wording). Sends the `action` message a renderer would.
final class Press extends Step {
  const Press(this.button, {required this.on, this.or = const []});
  final String button;
  final List<String> or;
  final SurfaceRef on;
}

/// The user types [value] into the input whose label contains [field] on the
/// surface [on]. Writes the input's bound data path, like a renderer would; it
/// reaches the agent with the next [Press] (through the event's context).
final class Fill extends Step {
  const Fill(this.field, this.value, {required this.on});
  final String field;
  final String value;
  final SurfaceRef on;
}

/// A check on the conversation state after the most recent turn.
final class Check extends Step {
  const Check(this.name, this.fn);
  final String name;

  /// Returns null on success, or what went wrong.
  final String? Function(CheckContext ctx) fn;
}

/// A surface as it was at some point, for resolving [SurfaceRef]s.
final class SurfaceSnapshot {
  SurfaceSnapshot(SurfaceState s)
    : id = s.id,
      order = s.order,
      createdTurn = s.createdTurn,
      text = s.searchableText;

  final String id;
  final int order;
  final int createdTurn;
  final String text;
}

/// Picks a surface without hardcoding the id the model chose.
sealed class SurfaceRef {
  const SurfaceRef();

  /// The [index]th surface by creation order (0-based). Replacing a surface
  /// keeps its position.
  const factory SurfaceRef.nth(int index) = _Nth;

  /// The most recently created surface.
  static const SurfaceRef last = _Last();

  /// The first surface whose content (literals and data) contains [text],
  /// case-insensitively.
  const factory SurfaceRef.containing(String text) = _Containing;

  /// The first surface created by turn [turn] (0-based, counting only turns
  /// that called the agent). Robust when earlier turns render unexpected UI.
  const factory SurfaceRef.fromTurn(int turn) = _FromTurn;

  /// Resolves against [surfaces] (sorted by creation order).
  SurfaceSnapshot? resolve(List<SurfaceSnapshot> surfaces);
}

final class _Nth extends SurfaceRef {
  const _Nth(this.index);
  final int index;
  @override
  SurfaceSnapshot? resolve(List<SurfaceSnapshot> s) =>
      index >= 0 && index < s.length ? s[index] : null;
  @override
  String toString() => 'surface #$index';
}

final class _FromTurn extends SurfaceRef {
  const _FromTurn(this.turn);
  final int turn;
  @override
  SurfaceSnapshot? resolve(List<SurfaceSnapshot> s) =>
      s.where((x) => x.createdTurn == turn).firstOrNull;
  @override
  String toString() => 'surface from t$turn';
}

final class _Last extends SurfaceRef {
  const _Last();
  @override
  SurfaceSnapshot? resolve(List<SurfaceSnapshot> s) =>
      s.isEmpty ? null : s.last;
  @override
  String toString() => 'last surface';
}

final class _Containing extends SurfaceRef {
  const _Containing(this.text);
  final String text;
  @override
  SurfaceSnapshot? resolve(List<SurfaceSnapshot> s) {
    final needle = text.toLowerCase();
    for (final x in s) {
      if (x.text.contains(needle)) return x;
    }
    return null;
  }

  @override
  String toString() => 'surface containing "$text"';
}

/// What a [Check] can see.
final class CheckContext {
  CheckContext({
    required this.before,
    required this.after,
    required this.changes,
    required this.prose,
    required this.streamed,
    required this.renderer,
  });

  /// Live surfaces before / after the last turn, by creation order.
  final List<SurfaceSnapshot> before;
  final List<SurfaceSnapshot> after;

  /// What the last turn did, by surface id.
  final Map<String, SurfaceChange> changes;

  /// The model's prose in the last turn.
  final String prose;

  /// The A2UI messages streamed during the last turn.
  final List<Map<String, dynamic>> streamed;

  final HeadlessRenderer renderer;

  int count(SurfaceChange c) => changes.values.where((v) => v == c).length;
}

/// Checks, named so the report reads well.
abstract final class Expect {
  /// The last turn created exactly [n] new surfaces (replacing an existing id
  /// does not count).
  static Check newSurfaces(int n) => Check('newSurfaces == $n', (ctx) {
    final got = ctx.count(SurfaceChange.created);
    return got == n ? null : 'created $got';
  });

  /// [n] surfaces are live after the last turn.
  static Check liveSurfaces(int n) => Check('liveSurfaces == $n', (ctx) {
    final got = ctx.after.length;
    return got == n ? null : '$got live: ${ctx.after.map((s) => s.id)}';
  });

  /// The last turn rendered, changed or deleted nothing.
  static Check noUi() => Check(
    'noUi',
    (ctx) => ctx.changes.isEmpty ? null : 'changed ${_describe(ctx.changes)}',
  );

  /// The surface [ref] (as it was before the turn) was updated or replaced in
  /// place, not deleted.
  static Check touched(SurfaceRef ref) => Check('touched($ref)', (ctx) {
    final s = ref.resolve(ctx.before);
    if (s == null) return 'no $ref before the turn';
    return switch (ctx.changes[s.id]) {
      SurfaceChange.updated || SurfaceChange.replaced => null,
      null => '"${s.id}" untouched; changed ${_describe(ctx.changes)}',
      final c => '"${s.id}" ${c.name}',
    };
  });

  /// The surface [ref] (as it was before the turn) was left alone.
  static Check untouched(SurfaceRef ref) => Check('untouched($ref)', (ctx) {
    final s = ref.resolve(ctx.before);
    if (s == null) return 'no $ref before the turn';
    final c = ctx.changes[s.id];
    return c == null ? null : '"${s.id}" ${c.name}';
  });

  /// The surface [ref] (as it was before the turn) is gone.
  static Check deleted(SurfaceRef ref) => Check('deleted($ref)', (ctx) {
    final s = ref.resolve(ctx.before);
    if (s == null) return 'no $ref before the turn';
    return ctx.after.any((a) => a.id == s.id) ? '"${s.id}" still live' : null;
  });

  /// The surface [on] (defaulting to [SurfaceRef.last]) uses a [component] of
  /// this type.
  static Check uses(String component, {SurfaceRef on = SurfaceRef.last}) =>
      Check('uses($component on $on)', (ctx) {
        final s = on.resolve(ctx.after);
        if (s == null) return 'no $on';
        final types = ctx.renderer[s.id]!.componentTypes;
        return types.contains(component) ? null : 'has ${types.join(', ')}';
      });

  /// A live surface ([on], or any) shows [text].
  static Check shows(String text, {SurfaceRef? on}) =>
      Check('shows("$text"${on == null ? '' : ' on $on'})', (ctx) {
        final needle = text.toLowerCase();
        final pool = on == null ? ctx.after : [?on.resolve(ctx.after)];
        if (pool.isEmpty) return 'no ${on ?? 'surfaces'}';
        return pool.any((s) => s.text.contains(needle)) ? null : 'not found';
      });

  /// The UI or the prose produced by the last turn mentions [text]. For
  /// confirmations, where either is a fair answer.
  static Check acknowledges(String text) =>
      Check('acknowledges("$text")', (ctx) {
        final needle = text.toLowerCase();
        if (ctx.prose.toLowerCase().contains(needle)) return null;
        if (jsonEncode(ctx.streamed).toLowerCase().contains(needle)) {
          return null;
        }
        return "not in prose or this turn's messages";
      });

  /// The last turn's prose is at most [chars] long (UI should carry the
  /// substance).
  static Check proseUnder(int chars) => Check('prose <= $chars chars', (ctx) {
    final n = ctx.prose.trim().length;
    return n <= chars ? null : '$n chars';
  });

  static String _describe(Map<String, SurfaceChange> changes) => changes.isEmpty
      ? 'nothing'
      : changes.entries.map((e) => '${e.key}:${e.value.name}').join(', ');
}
