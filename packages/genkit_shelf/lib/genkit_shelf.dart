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

/// Shelf adapter for Genkit's HTTP serving (`package:genkit/io.dart`).
///
/// ```dart
/// import 'package:genkit/io.dart';
/// import 'package:genkit_shelf/genkit_shelf.dart';
///
/// final genkit = GenkitRouter()
///   ..addAction(helloFlow)
///   ..addAction(secureFlow, contextProvider: bearerAuth);
///
/// final app = Router()
///   ..get('/health', (Request _) => Response.ok('OK'))
///   ..post('/hello', shelfHandler(helloFlow))
///   ..mount('/api/', genkit.asShelfHandler());
/// ```
library;

export 'src/handler.dart' show GenkitRouterShelf, shelfHandler;
