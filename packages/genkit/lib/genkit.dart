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

/// The core Genkit framework library.
///
/// Use this library to define [Flow]s, [Model]s, and [Tool]s.
///
/// This is the main entry point for creating Genkit applications.
/// @docImport 'src/ai/model.dart';
/// @docImport 'src/ai/tool.dart';
/// @docImport 'src/core/flow.dart';
library;

// Agent, session, and snapshot APIs are experimental and live in
// `package:genkit/experimental.dart` (and its `_client` / `_io` variants).
// They are intentionally excluded from this stable surface so they can evolve
// without a major version bump.

export 'src/ai/embedder.dart'
    show Embedder, EmbedderRef, embedderMetadata, embedderRef;
export 'src/ai/evaluator.dart' show Evaluator;

export 'src/ai/generate_middleware.dart'
    show
        GenerateMiddleware,
        GenerateMiddlewareContext,
        GenerateMiddlewareDef,
        GenerateMiddlewareRef,
        GenerateTurnState,
        defineMiddleware,
        middlewareRef;
export 'src/ai/generate_types.dart'
    show GenerateResponseChunk, GenerateResponseHelper, InterruptResponse;
export 'src/ai/middleware/retry.dart' show RetryMiddleware, RetryOptions, retry;
export 'src/ai/middleware/simulate_constrained_generation.dart'
    show SimulateConstrainedGenerationMiddleware, simulateConstrainedGeneration;
// BidiModel / bidiModelRef live in the experimental surface
// (`package:genkit/experimental.dart`) alongside generateBidi.
export 'src/ai/model.dart' show Model, ModelRef, modelMetadata, modelRef;
export 'src/ai/prompt.dart'
    show
        ExecutablePrompt,
        PromptAction,
        PromptFn,
        PromptGenerateOptions,
        PromptRef;
export 'src/ai/resource.dart'
    show ResourceAction, ResourceFn, ResourceInput, ResourceOutput;
export 'src/ai/template_helper.dart'
    show TemplateHelperFn, TemplateHelperOptions;
export 'src/ai/tool.dart'
    show
        Interrupt,
        Tool,
        ToolFn,
        ToolFnArg,
        ToolInterruptResult,
        ToolResponseResult,
        ToolResult;
export 'src/core/action.dart'
    show
        Action,
        ActionFn,
        ActionFnArg,
        ActionMetadata,
        ActionStream,
        ActionType,
        InternalActionFn,
        RunResult,
        StreamingCallback,
        TraceStartCallback;
export 'src/core/cancellation.dart'
    show CancellationController, CancellationToken, CancelledException;
export 'src/core/dynamic_action_provider.dart' show DynamicActionProvider;
export 'src/core/flow.dart';
export 'src/core/plugin.dart' show GenkitPlugin;
export 'src/core/registry.dart' show Registry;
export 'src/exception.dart' show GenkitException, StatusCode;
export 'src/genkit_ai.dart' show GenkitAI;
export 'src/genkit_class.dart';
export 'src/schema_extensions.dart';
export 'src/types.dart';
