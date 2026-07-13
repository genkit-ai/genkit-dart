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

export 'src/ai/agents/agent.dart'
    show
        Agent,
        AgentFn,
        AgentFnOptions,
        ClientTransform,
        SessionRunner,
        TurnContext,
        TurnResult,
        validateResumeAgainstHistory;
export 'src/ai/agents/agent_core.dart'
    show
        AgentApi,
        AgentChat,
        AgentChunk,
        AgentError,
        AgentInterrupt,
        AgentResponse,
        AgentTransport,
        AgentTurn,
        CancellationToken,
        DetachedTask,
        TurnStream;
export 'src/ai/agents/json_patch.dart'
    show JsonPatch, JsonPatchOperationMap, applyPatch, diff;
export 'src/ai/agents/remote_agent.dart' show HeadersResolver, remoteAgent;
export 'src/ai/agents/session.dart'
    show
        InMemorySessionStore,
        Session,
        SessionError,
        SessionStore,
        SnapshotCallback,
        SnapshotChangeNotifier,
        SnapshotContext,
        SnapshotEvent,
        SnapshotMutator,
        generateUuidV4,
        getCurrentSession,
        reserveSnapshotId,
        runWithSession;

export 'src/ai/embedder.dart'
    show Embedder, EmbedderRef, embedderMetadata, embedderRef;

export 'src/ai/formatters/types.dart';
export 'src/ai/generate_bidi.dart' show GenerateBidiSession;
export 'src/ai/generate_middleware.dart'
    show
        GenerateMiddleware,
        GenerateMiddlewareContext,
        GenerateMiddlewareDef,
        GenerateMiddlewareRef,
        defineMiddleware,
        middlewareRef;
export 'src/ai/generate_types.dart'
    show GenerateResponseChunk, GenerateResponseHelper, InterruptResponse;
export 'src/ai/interrupt.dart' show ToolInterruptException;
export 'src/ai/middleware/retry.dart'
    show RetryMiddleware, RetryOptions, RetryPlugin, retry;
export 'src/ai/model.dart'
    show BidiModel, Model, ModelRef, modelMetadata, modelRef;
export 'src/ai/prompt.dart'
    show
        ExecutablePrompt,
        PromptAction,
        PromptConfig,
        PromptFn,
        PromptGenerateOptions;
export 'src/ai/resource.dart'
    show
        ResourceAction,
        ResourceFn,
        ResourceInput,
        ResourceOutput,
        createResourceMatcher;
export 'src/ai/template_helper.dart'
    show TemplateHelperFn, TemplateHelperOptions;
export 'src/ai/tool.dart' show Tool, ToolFn, ToolFnArgs;
export 'src/core/action.dart' show Action, ActionFnArg, ActionMetadata;
export 'src/core/dynamic_action_provider.dart' show DynamicActionProvider;
export 'src/core/flow.dart';
export 'src/exception.dart' show GenkitException, StatusCodes;
export 'src/genkit_ai.dart' show GenkitAI;
export 'src/genkit_class.dart';
export 'src/schema_extensions.dart';
export 'src/types.dart';
