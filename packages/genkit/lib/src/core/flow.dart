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

import 'package:meta/meta.dart';

import 'action.dart';

base class Flow<Input, Output, Chunk, Init>
    extends Action<Input, Output, Chunk, Init> {
  /// Creates a unary flow.
  ///
  /// A null input is rejected with `INVALID_ARGUMENT` unless `Input` is itself
  /// nullable (or `void`/`dynamic`).
  Flow({
    required super.name,
    required ActionFn<Input, Output, Chunk, Init> fn,
    super.inputSchema,
    super.outputSchema,
    super.streamSchema,
    super.initSchema,
    super.metadata,
  }) : super(fn: requireInput('Flow', name, fn), actionType: .flow);

  /// Creates a bidirectional flow whose function receives the input stream.
  ///
  /// Experimental: bidirectional streaming is not covered by semver and may
  /// change in any minor release.
  @experimental
  Flow.bidi({
    required super.name,
    required BidiActionFn<Input, Output, Chunk, Init> fn,
    super.inputSchema,
    super.outputSchema,
    super.streamSchema,
    super.initSchema,
    super.metadata,
  }) : super(fn: bidiInput('Bidi flow', name, fn), actionType: .flow);
}
