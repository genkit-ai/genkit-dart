import 'dart:async';
import 'dart:io';

import 'package:genkit/schema.dart';
import 'package:genkit/src/ai/generate.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:genkit/src/core/plugin.dart';
import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/types.dart';

export 'package:genkit/src/o11y/otlp_http_exporter.dart'
    show configureCollectorExporter;

export 'package:genkit/src/types.dart';
export 'package:genkit/schema.dart';
export 'package:genkit/src/schema_extensions.dart';

bool _isDevEnv() {
  return Platform.environment['GENKIT_ENV'] == 'dev';
}

class Genkit {
  final Registry registry = Registry();
  ReflectionServer? _reflectionServer;
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

    if (isDevEnv ?? _isDevEnv()) {
      _reflectionServer = ReflectionServer(
        registry,
        port: reflectionPort ?? 3110,
      );
      _reflectionServer!.start();
    }

    _generateAction = defineGenerateAction(registry);

    registry.register(_generateAction!);
  }

  Future<void> shutdown() async {
    await _reflectionServer?.stop();
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

  Future<ModelResponse> generate<C>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    GenerateOutput? output,
    Map<String, dynamic>? context,
    StreamingCallback<ModelResponseChunk>? onChunk,
  }) async {
    if (messages == null && prompt == null) {
      throw ArgumentError('prompt or messages must be provided');
    }

    final resolvedMessages =
        messages ??
        [
          Message.from(
            role: Role.user,
            content: [TextPart.from(text: prompt!)],
          ),
        ];

    final modelName = model.name;

    return await _generateAction!(
      GenerateActionOptions.from(
        model: modelName,
        messages: resolvedMessages,
        config: config is Map ? config : (config as dynamic)?.toJson(),
        tools: tools,
        output: output == null
            ? null
            : GenerateActionOutputConfig.from(
                format: output.format,
                contentType: output.contentType,
                jsonSchema: output.schema?.jsonSchema as Map<String, dynamic>?,
              ),
      ),
      context: context,
      onChunk: onChunk,
    );
  }

  ActionStream<ModelResponseChunk, ModelResponse> generateStream<C>({
    String? prompt,
    List<Message>? messages,
    required ModelRef<C> model,
    C? config,
    List<String>? tools,
    GenerateOutput? output,
    Map<String, dynamic>? context,
  }) {
    final streamController = StreamController<ModelResponseChunk>();
    final actionStream = ActionStream<ModelResponseChunk, ModelResponse>(
      streamController.stream,
    );

    generate(
          prompt: prompt,
          messages: messages,
          model: model,
          config: config,
          tools: tools,
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
