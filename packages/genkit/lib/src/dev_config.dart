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

/// Resolves one Genkit dev-mode setting from the two channels the tooling has,
/// returning `null` when neither carries a value.
///
/// [envValue] is the process environment entry and [defineValue] the
/// `--dart-define` baked into the binary, which `genkit start:flutter` is
/// limited to on Android and iOS. The environment wins. An empty value from
/// either channel counts as unset, so an exported-but-empty variable does not
/// shadow the define.
///
/// [defineValue] is passed in rather than looked up here: `String.fromEnvironment`
/// resolves against a compile-time constant key, so each caller declares its own
/// `const String.fromEnvironment(key)`.
String? resolveDevConfig(String? envValue, String defineValue) {
  if (envValue != null && envValue.isNotEmpty) return envValue;
  return defineValue.isEmpty ? null : defineValue;
}
