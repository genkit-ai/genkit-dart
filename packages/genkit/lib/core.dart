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

/// Core Genkit types and interfaces.
///
/// Use this library to define [Flow]s, [Model]s, and [Tool]s without
/// depending on `dart:io` or the Reflection Server.
library;

export 'src/ai/formatters/types.dart';
export 'src/ai/generate.dart'
    show
        GenerateBidiSession,
        GenerateResponseChunk,
        GenerateResponseHelper,
        InterruptResponse;
export 'src/ai/generate_middleware.dart' show GenerateMiddleware;
export 'src/ai/middleware/retry.dart' show RetryMiddleware;
export 'src/ai/model.dart'
    show BidiModel, Model, ModelRef, modelMetadata, modelRef;
export 'src/ai/tool.dart' show Tool, ToolFn, ToolFnArgs;
export 'src/core/action.dart' show Action, ActionFnArg, ActionMetadata;
export 'src/core/flow.dart';
export 'src/core/plugin.dart' show GenkitPlugin;
export 'src/exception.dart' show GenkitException, StatusCodes;
export 'src/o11y/otlp_http_exporter.dart' show configureCollectorExporter;
export 'src/schema_extensions.dart';
export 'src/types.dart';
