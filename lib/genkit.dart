import 'dart:io';

import 'package:genkit/schema.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/flow.dart';
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

  Genkit({bool? isDevEnv}) {
    if (isDevEnv ?? _isDevEnv()) {
      _reflectionServer = ReflectionServer(registry);
      _reflectionServer!.start();
    }

    _generateAction = Action(
      actionType: 'util',
      name: 'generate',
      inputType: GenerateActionOptionsType,
      outputType: ModelResponseType,
      streamType: ModelResponseChunkType,
      fn: (options, context) async {
        final model = await registry.get('model', options.model) as Model;

        return model(ModelRequest.from(messages: options.messages));
      },
    );

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

  Model defineModel({
    required String name,
    required ActionFn<ModelRequest, ModelResponse, ModelResponseChunk> fn,
  }) {
    final model = Model(name: name, fn: fn);
    registry.register(model);
    return model;
  }

  Future<ModelResponse> generate({
    String? prompt,
    List<Message>? messages,
    required String model,
  }) async {
    if (messages == null && prompt == null) {
      throw ArgumentError('prompt or messages must be provided');
    }

    messages ??= [
      Message.from(
        role: Role.user,
        content: [TextPart.from(text: prompt!)],
      ),
    ];

    return await _generateAction!(
      GenerateActionOptions.from(model: model, messages: messages),
    );
  }
}
