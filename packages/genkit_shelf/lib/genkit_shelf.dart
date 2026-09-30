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

/// Shelf integration for Genkit: serve flows, models and other actions over
/// HTTP.
///
/// ```dart
/// final genkit = GenkitRouter()
///   ..addAction(helloFlow)
///   ..addAction(secureFlow, contextProvider: bearerAuth);
///
/// await genkit.serve();
/// ```
///
/// Agents are served with `addAgent` from the experimental
/// `package:genkit_shelf/agents.dart`.
library;

export 'src/cors.dart' show CorsOptions;
export 'src/handler.dart' show ContextProvider, shelfHandler;
export 'src/router.dart' show GenkitRouter;
