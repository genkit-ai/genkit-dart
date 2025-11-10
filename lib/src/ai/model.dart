import 'package:genkit/schema.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/types.dart';

class Model extends Action<ModelRequest, ModelResponse, ModelResponseChunk> {
  Model({
    required super.name,
    required super.fn,
    super.metadata,
    Schema? customOptions,
  }) : super(
         actionType: 'model',
         inputType: ModelRequestType,
         outputType: ModelResponseType,
         streamType: ModelResponseChunkType,
       ) {
    metadata['description'] = name;
    metadata['model'] = {'label': name};
    if (customOptions != null) {
      metadata['model']['customOptions'] = customOptions.toJson();
    }
  }
}
