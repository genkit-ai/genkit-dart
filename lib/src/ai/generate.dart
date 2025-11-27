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
    fn: (options, ctx) async {
      final model = await registry.lookupAction('model', options.model) as Model?;
      if (model == null) {
        throw GenkitException(
          'Model ${options.model} not found',
          statusCode: 404,
        );
      }

      var toolDefs = <ToolDefinition>[];
      if (options.tools != null) {
        for (var toolName in options.tools!) {
          final tool = await registry.lookupAction('tool', toolName) as Tool?;
          if (tool != null) {
            toolDefs.add(toToolDefinition(tool));
          }
        }
      }

      final request = ModelRequest.from(
        messages: options.messages,
        config: options.config,
        tools: toolDefs,
        toolChoice: options.toolChoice,
        output: options.output == null
            ? null
            : OutputConfig.from(
                format: options.output!.format,
                contentType: options.output!.contentType,
                schema: options.output!.jsonSchema,
              ),
      );
      var currentRequest = request;
      var turns = 0;
      while (turns < (options.maxTurns ?? 5)) {
        var response = await model(
          currentRequest,
          onChunk: ctx.streamingRequested ? ctx.sendChunk : null,
        );

        if (options.returnToolRequests ?? false) {
          return response;
        }

        final toolRequests = response.message?.content
            .where((c) => c.toJson().containsKey('toolRequest'))
            .map((c) => c as ToolRequestPart)
            .toList();
        if (toolRequests == null || toolRequests.isEmpty) {
          return response;
        }

        final toolResponses = <Part>[];
        for (final toolRequest in toolRequests) {
          final tool =
              await registry.lookupAction('tool', toolRequest.toolRequest.name) as Tool?;
          if (tool == null) {
            throw GenkitException(
              'Tool ${toolRequest.toolRequest.name} not found',
              statusCode: 404,
            );
          }
          final output = await tool(toolRequest.toolRequest.input);
          toolResponses.add(
            ToolResponsePart.from(
              toolResponse: ToolResponse.from(
                ref: toolRequest.toolRequest.ref,
                name: toolRequest.toolRequest.name,
                output: output,
              ),
            ),
          );
        }

        final newMessages = List<Message>.from(currentRequest.messages)
          ..add(response.message!)
          ..add(Message.from(role: Role.tool, content: toolResponses));

        currentRequest = ModelRequest.from(
          messages: newMessages,
          config: currentRequest.config,
          tools: currentRequest.tools,
          toolChoice: currentRequest.toolChoice,
          output: currentRequest.output,
        );
        turns++;
      }
      throw GenkitException(
        'Reached max turns of ${options.maxTurns ?? 5}',
        statusCode: 400,
      );
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

/// Base class for model-specific configuration.
///
/// Model providers can extend this class to provide their own configuration
/// options.
abstract class GenerateConfig {}

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

Future<ModelResponse> generateHelper<C>(
  Action<GenerateActionOptions, ModelResponse, ModelResponseChunk>
  generateAction, {
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

  return await generateAction(
    GenerateActionOptions.from(
      model: modelName,
      messages: resolvedMessages,
      config: config is Map ? config : (config as dynamic)?.toJson(),
      tools: tools,
      toolChoice: toolChoice,
      returnToolRequests: returnToolRequests,
      maxTurns: maxTurns,
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
