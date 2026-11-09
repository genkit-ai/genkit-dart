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

/// Serve Genkit flows, models and other actions over HTTP (`dart:io`).
///
/// ```dart
/// import 'package:genkit/io.dart';
///
/// final genkit = GenkitRouter()
///   ..addAction(helloFlow)
///   ..addAction(secureFlow, contextProvider: bearerAuth);
///
/// await genkit.serve();
/// ```
///
/// Or plug it into your own `dart:io` server with
/// [GenkitRouter.handleHttpRequest], or serve a single action with
/// [ioHandler]. Other HTTP frameworks integrate through the framework-neutral
/// [GenkitRouter.handle], [actionHandler] and [withCors]
/// (`package:genkit_shelf` is the shelf adapter).
///
/// Agents are served with `addAgent` from the experimental
/// `package:genkit/experimental_io.dart`.
///
/// Depends on `dart:io`, so it does not work on the web.
library;

import 'src/server/action_handler.dart';
import 'src/server/cors.dart';
import 'src/server/io_adapter.dart';
import 'src/server/router.dart';

export 'src/server/action_handler.dart' show actionHandler;
export 'src/server/cors.dart' show CorsOptions, withCors;
export 'src/server/http.dart'
    show
        ContextProvider,
        GenkitHttpHandler,
        GenkitHttpRequest,
        GenkitHttpResponse,
        RequestData;
export 'src/server/io_adapter.dart' show ioHandler;
export 'src/server/router.dart' show GenkitRouter;
