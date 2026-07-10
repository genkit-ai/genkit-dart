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

/// Client-managed state weather agent — same as the regular weather agent but
/// with NO server-side store.
///
/// Ported from the JS `weather-agent-stateless.ts`. The client owns the
/// session state blob and must echo it back on every subsequent turn via
/// `init: { state }`. This demonstrates that tool-calling and multi-turn work
/// fine without a server store — the session history lives in the state blob
/// the client round-trips.
library;

import 'package:genkit/genkit.dart';

import 'genkit.dart';
import 'weather_agent.dart' show getWeather;

/// No store — client-managed state. The client must round-trip the `state`
/// blob returned from each turn.
final weatherAgentStateless = ai.defineAgent(
  name: 'weatherAgentStateless',
  system:
      'You are a helpful weather assistant. Use the getWeather tool to look '
      'up weather. Be concise.',
  use: [retry()],
  tools: [getWeather],
);
