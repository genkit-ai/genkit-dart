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

import 'dart:async';
import 'package:genkit/schema.dart';
import 'package:genkit/src/ai/formatters/formatters.dart';
import 'package:genkit/src/ai/generate.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:genkit/src/core/plugin.dart';
import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/reflection_v2.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/o11y/instrumentation.dart';
import 'package:genkit/src/types.dart';
import 'package:genkit/src/utils.dart';

export 'package:genkit/src/o11y/otlp_http_exporter.dart'
    show configureCollectorExporter;
export 'package:genkit/src/core/flow.dart';
export 'package:genkit/src/types.dart';
export 'package:genkit/schema.dart';
export 'package:genkit/src/schema_extensions.dart';
export 'package:genkit/src/ai/formatters/types.dart';

bool _isDevEnv() {
  return getEnvVar('GENKIT_ENV') == 'dev';
}

class Genkit {
  final Registry registry = Registry();
  Object? _reflectionServer;
  Action<GenerateActionOptions, ModelResponse, ModelResponseChunk>?
  _generateAction;

  Genkit({
    List<GenkitPlugin> plugins = const [],
    bool? isDevEnv,
    int? reflectionPort,
  }) {
    // Register plugins
    for (final plugin in plugins) {
      registry.registerPlugin(plugin);
    }
    
    // Register default formats
    configureFormats(registry);

    if (isDevEnv ?? _isDevEnv()) {
      final v2ServerUrl = getEnvVar('GENKIT_REFLECTION_V2_SERVER');
      if (v2ServerUrl != null) {
        final server = ReflectionServerV2(registry, url: v2ServerUrl);
        server.start();
        _reflectionServer = server;
      } else {
        final server = ReflectionServer(registry, port: reflectionPort ?? 3110);
        server.start();
        _reflectionServer = server;
      }
    }

    _generateAction = defineGenerateAction(registry);

    registry.register(_generateAction!);
  }

  Future<void> shutdown() async {
    if (_reflectionServer is ReflectionServer) {
      await (_reflectionServer as ReflectionServer).stop();
    } else if (_reflectionServer is ReflectionServerV2) {
      await (_reflectionServer as ReflectionServerV2).stop();
    }
  }

  Future<O> run<O>(String name, Future<O> Function() fn) {
    return runInNewSpan(name, (_) => fn());
  }

  Flow<I, O, S> defineFlow<I, O, S>({
    required String name,
    required ActionFn<I, O, S> fn,
    JsonExtensionType<I>? inputType,
    JsonExtensionType<O>? outputType,
    JsonExtensionType<S>? streamType,
  }) {
    final flow = Flow(
      name: name,
      fn: fn,
      inputType: inputType,
      outputType: outputType,
      streamType: streamType,
    );
    registry.register(flow);
    return flow;
  }

  Tool<I, O> defineTool<I, O, S>({
    required String name,
    required String description,
    required ActionFn<I, O, S> fn,
    JsonExtensionType<I>? inputType,
    JsonExtensionType<O>? outputType,
    JsonExtensionType<S>? streamType,
  }) {
    final tool = Tool(
      name: name,
      description: description,
      fn: fn,
      inputType: inputType,
      outputType: outputType,
    );
    registry.register(tool);
    return tool;
  }

  Model defineModel({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk> fn,
  }) {
    final model = Model(name: name, fn: fn);
    registry.register(model);
    return model;
  }

  Future<GenerateResponse> generate<C>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    GenerateOutput? output,
    Map<String, dynamic>? context,
    StreamingCallback<ModelResponseChunk>? onChunk,
  }) async {
    return generateHelper(
      registry,
      prompt: prompt,
      messages: messages,
      model: model,
      config: config,
      tools: tools,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
      output: output,
      context: context,
      onChunk: onChunk,
    );
  }

  ActionStream<ModelResponseChunk, GenerateResponse> generateStream<C>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    String? toolChoice,
    bool? returnToolRequests,
    int? maxTurns,
    GenerateOutput? output,
    Map<String, dynamic>? context,
  }) {
    final streamController = StreamController<ModelResponseChunk>();
    final actionStream = ActionStream<ModelResponseChunk, GenerateResponse>(
      streamController.stream,
    );

    generate(
          prompt: prompt,
          messages: messages,
          model: model,
          config: config,
          tools: tools,
          toolChoice: toolChoice,
          returnToolRequests: returnToolRequests,
          maxTurns: maxTurns,
          output: output,
          context: context,
          onChunk: (chunk) {
            if (streamController.isClosed) return;
            streamController.add(chunk);
          },
        )
        .then((result) {
          actionStream.setResult(result);
          if (!streamController.isClosed) {
            streamController.close();
          }
        })
        .catchError((e, s) {
          actionStream.setError(e, s);
          if (!streamController.isClosed) {
            streamController.addError(e, s);
            streamController.close();
          }
        });

    return actionStream;
  }
}
