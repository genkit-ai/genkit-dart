import 'package:genkit/schema.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/types.dart';

ModelRef<C> modelRef<C>(String name, {JsonExtensionType<C>? customOptions}) {
  return _ModelRef<C>(name, customOptions);
}

abstract class ModelRef<C> {
  String get name;
  JsonExtensionType<C>? get customOptions;
}

class _ModelRef<C> implements ModelRef<C> {
  @override
  final String name;
  @override
  final JsonExtensionType<C>? customOptions;

  _ModelRef(this.name, this.customOptions);
}

class Model<C> extends Action<ModelRequest, ModelResponse, ModelResponseChunk>
    implements ModelRef<C> {
  @override
  JsonExtensionType<C>? customOptions;

  Model({
    required super.name,
    required super.fn,
    super.metadata,
    this.customOptions,
  }) : super(
         actionType: 'model',
         inputType: ModelRequestType,
         outputType: ModelResponseType,
         streamType: ModelResponseChunkType,
       ) {
    metadata['description'] = name;
    metadata['model'] = <String, dynamic>{};
    metadata['model']['label'] = name;
    if (customOptions != null) {
      metadata['model']['customOptions'] = customOptions!.jsonSchema ?? {};
    }
  }
}
