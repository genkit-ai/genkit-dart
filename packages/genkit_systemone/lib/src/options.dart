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

import 'package:schemantic/schemantic.dart';

part 'options.g.dart';

/// The per-request configuration of a decision model.
///
/// Preview: this API may change in any minor release.
@Schema()
abstract class $SystemOneOptions {
  /// Parses each text part of the state as JSON, so a prompt template that
  /// renders a JSON document produces an object state rather than a string
  /// one. A text that is not JSON is an error. A fallback to another model
  /// takes that model's config, so set it there too, or send the state as a
  /// data part, which needs no parsing.
  @Field(
    description:
        'Parse each text part of the state as JSON, so a template that '
        'renders JSON produces an object state.',
  )
  bool? get stateJSON;

  /// Merged into the top-level fields of the request body. It reaches fields
  /// this package does not model, such as a gateway's `session_id` or
  /// `trace`. It cannot name a field the request builds itself: model, state,
  /// questions, images, audio, or videos.
  @Field(
    description:
        "Extra top-level request fields, such as a gateway's session_id. "
        'Cannot replace model, state, questions, images, audio, or videos.',
  )
  Map<String, dynamic>? get extra;
}
