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

/// What differs between genkit_a2ui versions, so the harness can run against
/// an older one by swapping this file.
library;

import 'package:genkit/genkit.dart';

/// The `data` key a client's a2ui part carries its messages under.
const actionDataKey = 'messages';

/// The Express source a compiled a2ui part was built from, if recorded.
String? expressSourceOf(Part part) => switch (part.metadata?['a2uiExpress']) {
  final String s => s,
  _ => null,
};
