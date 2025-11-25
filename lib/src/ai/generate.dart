import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/ai/tool.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:genkit/src/exception.dart';

/// Defines the utility 'generate' action.
Action<GenerateActionOptions, ModelResponse, ModelResponseChunk>
defineGenerateAction(Registry registry) {
  return Action(
    actionType: 'util',
    name: 'generate',
    inputType: GenerateActionOptionsType,
    outputType: ModelResponseType,
    streamType: ModelResponseChunkType,
    fn: (options, context) async {
      final model = await registry.get('model', options.model) as Model?;
      if (model == null) {
        throw GenkitException('Model ${options.model} not found', statusCode: 404);
      }

      final request = ModelRequest.from(
        messages: options.messages,
        config: options.config,
        tools: (options.tools ?? [])
            .map((e) => toToolDefinition(registry.get('tool', e) as Tool))
            .toList(),
        output: options.output == null
            ? null
            : OutputConfig.from(
                format: options.output!.format,
                contentType: options.output!.contentType,
                schema: options.output!.jsonSchema,
              ),
      );
      return model(request);
    },
  );
}

ToolDefinition toToolDefinition(Tool tool) {
  return ToolDefinition.from(
    name: tool.name,
    description: tool.description!,
    inputSchema: tool.inputType?.jsonSchema != null
        ? tool.inputType?.jsonSchema as Map<String, dynamic>
        : null,
    outputSchema: tool.outputType?.jsonSchema != null
        ? tool.outputType?.jsonSchema as Map<String, dynamic>
        : null,
  );
}

/// Represents the options for a generate request.
class GenerateOptions {
  /// The prompt to send to the model.
  String? prompt;

  /// The messages to send to the model.
  List<Message>? messages;

  /// The model to use for the request.
  Object model;

  /// The configuration for the model.
  GenerateConfig? config;

  /// The tools to use for the request.
  List<String>? tools;

  /// The output format for the request.
  GenerateOutput? output;

  /// Whether to stream the response.
  bool? stream;

  GenerateOptions({
    this.prompt,
    this.messages,
    required this.model,
    this.config,
    this.tools,
    this.output,
    this.stream,
  });
}

/// Base class for model-specific configuration.
///
/// Model providers can extend this class to provide their own configuration
/// options.
abstract class GenerateConfig {
  Map<String, dynamic> toJson();
}

/// Represents the output format for a generate request.
class GenerateOutput {
  /// The JSON schema for the output.
  JsonExtensionType? schema;

  /// The output format.
  String? format;

  /// The content type of the output.
  String? contentType;

  GenerateOutput({this.schema, this.format, this.contentType});
}
