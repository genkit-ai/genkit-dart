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

/// Shared typed-state (de)serialization helpers for the agent layer.
///
/// Custom agent state travels the wire as plain JSON. These helpers convert
/// between that raw JSON and the typed `State` view used across the agent client
/// core (`AgentResponse`, `AgentSnapshot`, `DetachedTask`) and the server-side
/// `Session` / `SessionRunner`. They are browser-safe (no `dart:io`).

library;

import 'package:meta/meta.dart';
import 'package:schemantic/schemantic.dart';

/// Casts or parses raw JSON [raw] into the typed [State].
///
/// When a [schema] is supplied, the raw JSON is `parse`d into a real `State`
/// instance (e.g. a schemantic-generated class); otherwise it is a bare view
/// cast over the JSON (the `Object?` / `Map`-shaped default). Returns `null`
/// when [raw] is `null`. Mirrors the `inputSchema != null ? parse : as` pattern
/// used by `Action`.
@internal
State? castOrParseState<State>(Object? raw, SchemanticType<State>? schema) {
  if (raw == null) return null;
  return schema != null ? schema.parse(raw) : raw as State;
}

/// Serializes a typed [value] back into plain JSON for storage on the wire.
///
/// When a [schema] is supplied, delegates to [SchemanticType.serialize] (which
/// handles scalars, lists, maps, and any object exposing `toJson()`); otherwise
/// the value is already JSON-shaped and is returned as-is. Returns `null` when
/// [value] is `null`.
@internal
Object? serializeState<State>(State? value, SchemanticType<State>? schema) {
  if (value == null) return null;
  return schema != null ? schema.serialize(value) : value;
}
