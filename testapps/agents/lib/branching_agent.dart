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

/// Branching agent — fork a conversation from an earlier snapshot.
///
/// Ported from the JS `branching-agent.ts`. A single chat carries state
/// forward automatically. To *branch*, open a new chat attached to an earlier
/// snapshot via `chat(snapshotId: ...)`. The `roundRobin` helper alternates
/// the system persona on each render so the two branches feel distinct.
library;

import 'package:genkit/genkit.dart';

import 'genkit.dart';

var _count = 0;

bool _helperRegistered = false;

/// Registers the `roundRobin` template helper exactly once.
void _ensureHelper() {
  if (_helperRegistered) return;
  _helperRegistered = true;
  ai.defineHelper('roundRobin', (args, options) {
    final o1 = args[0];
    final o2 = args[1];
    final useFirst = _count.isOdd;
    _count++;
    return useFirst ? o1 : o2;
  });
}

final branchingAgent = (() {
  _ensureHelper();
  return ai.defineAgent(
    name: 'branchingAgent',
    model: liteModel,
    system: "You are a {{ roundRobin 'sarcastic' 'business-like' }} assistant.",
    use: [retry()],
    store: InMemorySessionStore(),
  );
})();
