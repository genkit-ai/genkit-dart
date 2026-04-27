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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:genkit/plugin.dart';
import 'package:genkit_google_genai/common.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import 'common.dart';

const _mistralPublisher = 'mistralai';
const _mistralApiVersion = 'v1';

final mistralModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

bool isMistralModelName(String name) {
  final normalized = name.toLowerCase();
  return normalized.startsWith('mistral-') ||
      normalized.startsWith('codestral-');
}

List<ActionMetadata<dynamic, dynamic, dynamic, dynamic>> mistralMetadata(
  String pluginName,
  List<dynamic> publisherModels,
) {
  return publisherModels
      .map(publisherModelName)
      .nonNulls
      .where(isMistralModelName)
      .map(
        (modelName) => modelMetadata(
          '$pluginName/$modelName',
          customOptions: MistralOptions.$schema,
          modelInfo: _mistralModelInfoFor(modelName),
        ),
      )
      .toList();
}

Model createMistralModel({
  required String pluginName,
  required String modelName,
  required Future<GenerativeLanguageBaseClient> Function() getApiClient,
  bool closeClient = true,
}) {
  final modelInfo = _mistralModelInfoFor(modelName);

  return Model(
    name: '$pluginName/$modelName',
    customOptions: MistralOptions.$schema,
    metadata: {'model': modelInfo.toJson()},
    fn: (req, ctx) async {
      final modelRequest = req!;
      final options = modelRequest.config == null
          ? MistralOptions()
          : MistralOptions.$schema.parse(modelRequest.config!);
      final service = await getApiClient();
      final client = _MistralRawPredictClient(service);

      try {
        final body = _toMistralRequest(
          modelRequest,
          options,
          modelName,
          stream: ctx.streamingRequested,
        );

        if (ctx.streamingRequested) {
          return await _handleMistralStream(client, body, modelName, ctx);
        }

        final response = await client.rawPredict(body, model: modelName);
        return _fromMistralResponse(response);
      } catch (e, stack) {
        if (e is GenkitException) rethrow;
        throw GenkitException(
          'Mistral API error: $e',
          status: StatusCodes.INTERNAL,
          underlyingException: e,
          stackTrace: stack,
        );
      } finally {
        if (closeClient) {
          service.client.close();
        }
      }
    },
  );
}

base class MistralOptions {
  factory MistralOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MistralOptions._(this._json);

  MistralOptions({
    String? version,
    double? temperature,
    double? topP,
    int? maxTokens,
    List<String>? stop,
    double? presencePenalty,
    double? frequencyPenalty,
    int? randomSeed,
    bool? safePrompt,
    String? toolChoice,
    Map<String, dynamic>? responseFormat,
  }) {
    _json = {
      'version': ?version,
      'temperature': ?temperature,
      'topP': ?topP,
      'maxTokens': ?maxTokens,
      'stop': ?stop,
      'presencePenalty': ?presencePenalty,
      'frequencyPenalty': ?frequencyPenalty,
      'randomSeed': ?randomSeed,
      'safePrompt': ?safePrompt,
      'toolChoice': ?toolChoice,
      'responseFormat': ?responseFormat,
    };
  }

  late final Map<String, dynamic> _json;

  static final SchemanticType<MistralOptions> $schema = SchemanticType.from(
    jsonSchema: {
      'type': 'object',
      'properties': {
        'version': {'type': 'string'},
        'temperature': {'type': 'number', 'minimum': 0, 'maximum': 1.5},
        'topP': {'type': 'number', 'minimum': 0, 'maximum': 1},
        'maxTokens': {'type': 'integer'},
        'stop': {
          'type': 'array',
          'items': {'type': 'string'},
        },
        'presencePenalty': {'type': 'number', 'minimum': -2, 'maximum': 2},
        'frequencyPenalty': {'type': 'number', 'minimum': -2, 'maximum': 2},
        'randomSeed': {'type': 'integer'},
        'safePrompt': {'type': 'boolean'},
        'toolChoice': {
          'type': 'string',
          'enum': ['auto', 'none', 'any', 'required'],
        },
        'responseFormat': {'type': 'object'},
      },
    },
    parse: (json) => MistralOptions._(Map<String, dynamic>.from(json as Map)),
  );

  String? get version => _json['version'] as String?;

  double? get temperature => (_json['temperature'] as num?)?.toDouble();

  double? get topP => (_json['topP'] as num?)?.toDouble();

  int? get maxTokens => _json['maxTokens'] as int?;

  List<String>? get stop => (_json['stop'] as List?)?.cast<String>();

  double? get presencePenalty => (_json['presencePenalty'] as num?)?.toDouble();

  double? get frequencyPenalty =>
      (_json['frequencyPenalty'] as num?)?.toDouble();

  int? get randomSeed => _json['randomSeed'] as int?;

  bool? get safePrompt => _json['safePrompt'] as bool?;

  String? get toolChoice => _json['toolChoice'] as String?;

  Map<String, dynamic>? get responseFormat =>
      (_json['responseFormat'] as Map?)?.cast<String, dynamic>();

  Map<String, dynamic> toJson() => _json;
}

Future<ModelResponse> _handleMistralStream(
  _MistralRawPredictClient client,
  Map<String, dynamic> body,
  String modelName,
  ActionFnArg<ModelResponseChunk, ModelRequest, void> ctx,
) async {
  final content = StringBuffer();
  Map<String, dynamic>? lastChunk;
  String? finishReason;

  await for (final chunk in client.streamRawPredict(body, model: modelName)) {
    lastChunk = chunk;
    final choices = chunk['choices'] as List?;
    if (choices == null || choices.isEmpty) continue;

    final choice = choices.first as Map<String, dynamic>;
    finishReason = choice['finish_reason'] as String?;
    final delta = choice['delta'] as Map<String, dynamic>?;
    final deltaContent = delta?['content'];
    final text = _contentToText(deltaContent);
    if (text == null || text.isEmpty) continue;

    content.write(text);
    ctx.sendChunk(
      ModelResponseChunk(index: 0, content: [TextPart(text: text)]),
    );
  }

  return ModelResponse(
    finishReason: _mapFinishReason(finishReason),
    message: Message(
      role: Role.model,
      content: [TextPart(text: '$content')],
    ),
    raw: lastChunk,
  );
}

Map<String, dynamic> _toMistralRequest(
  ModelRequest request,
  MistralOptions options,
  String modelName, {
  required bool stream,
}) {
  final isJsonMode =
      request.output?.format == 'json' ||
      request.output?.contentType == 'application/json';

  return {
    'model': _bodyModelName(options.version ?? modelName),
    'messages': _toMistralMessages(request.messages),
    'stream': stream,
    if (options.temperature != null) 'temperature': options.temperature,
    if (options.topP != null) 'top_p': options.topP,
    if (options.maxTokens != null) 'max_tokens': options.maxTokens,
    if (options.stop != null) 'stop': options.stop,
    if (options.presencePenalty != null)
      'presence_penalty': options.presencePenalty,
    if (options.frequencyPenalty != null)
      'frequency_penalty': options.frequencyPenalty,
    if (options.randomSeed != null) 'random_seed': options.randomSeed,
    if (options.safePrompt != null) 'safe_prompt': options.safePrompt,
    if (options.toolChoice != null) 'tool_choice': options.toolChoice,
    if (request.tools?.isNotEmpty == true)
      'tools': request.tools!.map(_toMistralTool).toList(),
    if (options.responseFormat != null)
      'response_format': options.responseFormat
    else if (isJsonMode)
      'response_format': {'type': 'json_object'},
  };
}

String _bodyModelName(String modelName) => modelName.split('@').first;

List<Map<String, dynamic>> _toMistralMessages(List<Message> messages) {
  final converted = <Map<String, dynamic>>[];
  for (final message in messages) {
    if (message.role == Role.tool) {
      final toolResponses = message.content
          .where((part) => part.isToolResponse)
          .map((part) => part.toolResponse!)
          .toList();
      if (toolResponses.isEmpty) {
        throw ArgumentError(
          'Mistral tool messages must contain at least one ToolResponsePart.',
        );
      }
      converted.addAll(toolResponses.map(_toMistralToolResponseMessage));
    } else {
      converted.add(_toMistralMessage(message));
    }
  }
  return converted;
}

Map<String, dynamic> _toMistralMessage(Message message) {
  final role = message.role == Role.model ? 'assistant' : message.role.value;
  final toolCalls = message.content
      .where((part) => part.isToolRequest)
      .map((part) => _toMistralToolCall(part.toolRequest!))
      .toList();

  return {
    'role': role,
    'content': _toMistralContent(message.content),
    if (toolCalls.isNotEmpty) 'tool_calls': toolCalls,
  };
}

Map<String, dynamic> _toMistralToolResponseMessage(ToolResponse response) {
  return {
    'role': 'tool',
    'tool_call_id': response.ref,
    'name': response.name,
    'content': jsonEncode(response.output),
  };
}

Object _toMistralContent(List<Part> parts) {
  final contentParts = parts
      .where((part) => part.isText || part.isReasoning || part.isMedia)
      .map(_toMistralContentPart)
      .toList();

  if (contentParts.isEmpty) {
    return '';
  }
  if (contentParts.length == 1 && contentParts.first['type'] == 'text') {
    return contentParts.first['text'] as String;
  }
  return contentParts;
}

Map<String, dynamic> _toMistralContentPart(Part part) {
  if (part.isText) {
    return {'type': 'text', 'text': part.text};
  }
  if (part.isReasoning) {
    return {'type': 'text', 'text': part.reasoning};
  }
  if (part.isMedia) {
    final media = part.media!;
    if (_isDocumentMedia(media)) {
      return {'type': 'document_url', 'document_url': media.url};
    }
    return {
      'type': 'image_url',
      'image_url': {'url': media.url},
    };
  }
  throw GenkitException(
    'Unsupported Mistral content part: $part',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

bool _isDocumentMedia(Media media) {
  final contentType = media.contentType?.toLowerCase();
  return contentType == 'application/pdf' ||
      media.url.toLowerCase().endsWith('.pdf');
}

Map<String, dynamic> _toMistralTool(ToolDefinition tool) {
  final parameters = tool.inputSchema == null
      ? {'type': 'object', 'properties': <String, dynamic>{}}
      : ({
          if (!tool.inputSchema!.containsKey('type')) 'type': 'object',
          ...tool.inputSchema!,
        });

  return {
    'type': 'function',
    'function': {
      'name': tool.name,
      'description': tool.description,
      'parameters': parameters,
    },
  };
}

Map<String, dynamic> _toMistralToolCall(ToolRequest request) {
  final ref = request.ref;
  if (ref == null || ref.isEmpty) {
    throw ArgumentError(
      'ToolRequest.ref must be a non-empty string for Mistral tool calls.',
    );
  }

  return {
    'id': ref,
    'type': 'function',
    'function': {
      'name': request.name,
      'arguments': jsonEncode(request.input ?? {}),
    },
  };
}

ModelResponse _fromMistralResponse(Map<String, dynamic> response) {
  final choices = response['choices'] as List?;
  if (choices == null || choices.isEmpty) {
    throw GenkitException('Mistral model returned no choices.');
  }

  final choice = choices.first as Map<String, dynamic>;
  final message = choice['message'] as Map<String, dynamic>;

  return ModelResponse(
    finishReason: _mapFinishReason(choice['finish_reason'] as String?),
    message: _fromMistralMessage(message),
    raw: response,
    usage: _extractMistralUsage(response['usage'] as Map<String, dynamic>?),
  );
}

Message _fromMistralMessage(Map<String, dynamic> message) {
  final parts = <Part>[];
  final text = _contentToText(message['content']);
  if (text != null && text.isNotEmpty) {
    parts.add(TextPart(text: text));
  }

  final toolCalls = message['tool_calls'] as List?;
  if (toolCalls != null) {
    for (final toolCall in toolCalls.cast<Map<String, dynamic>>()) {
      parts.add(_fromMistralToolCall(toolCall));
    }
  }

  return Message(role: Role.model, content: parts);
}

String? _contentToText(Object? content) {
  if (content == null) return null;
  if (content is String) return content;
  if (content is List) {
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is Map && part['type'] == 'text') {
        buffer.write(part['text']);
      }
    }
    return '$buffer';
  }
  return content.toString();
}

ToolRequestPart _fromMistralToolCall(Map<String, dynamic> toolCall) {
  final function = toolCall['function'] as Map<String, dynamic>;
  final arguments = function['arguments'];

  return ToolRequestPart(
    toolRequest: ToolRequest(
      ref: toolCall['id'] as String?,
      name: function['name'] as String,
      input: _parseToolArguments(arguments),
    ),
  );
}

Map<String, dynamic>? _parseToolArguments(Object? arguments) {
  if (arguments == null) return null;
  if (arguments is Map<String, dynamic>) return arguments;
  if (arguments is String && arguments.isNotEmpty) {
    return jsonDecode(arguments) as Map<String, dynamic>;
  }
  return null;
}

FinishReason _mapFinishReason(String? reason) {
  return switch (reason) {
    'stop' || 'tool_calls' => FinishReason.stop,
    'length' || 'model_length' => FinishReason.length,
    'content_filter' => FinishReason.blocked,
    _ => FinishReason.unknown,
  };
}

GenerationUsage? _extractMistralUsage(Map<String, dynamic>? usage) {
  if (usage == null) return null;
  return GenerationUsage(
    inputTokens: (usage['prompt_tokens'] as num?)?.toDouble(),
    outputTokens: (usage['completion_tokens'] as num?)?.toDouble(),
    totalTokens: (usage['total_tokens'] as num?)?.toDouble(),
  );
}

ModelInfo _mistralModelInfoFor(String modelName) {
  final normalized = modelName.toLowerCase();
  return ModelInfo(
    label: modelName,
    supports: {
      ...mistralModelInfo.supports!,
      'media': !normalized.startsWith('codestral-'),
    },
  );
}

class _MistralRawPredictClient {
  final GenerativeLanguageBaseClient _service;

  _MistralRawPredictClient(this._service);

  Future<Map<String, dynamic>> rawPredict(
    Map<String, dynamic> request, {
    required String model,
  }) async {
    final url = '${_service.apiUrlPrefix}models/$model:rawPredict';
    final response = await _service.client.post(
      Uri.parse('${_service.baseUrl}$url'),
      headers: {'Content-Type': 'application/json; charset=utf-8'},
      body: jsonEncode(request),
    );
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    }
    throw _parseMistralError(response.statusCode, response.body);
  }

  Stream<Map<String, dynamic>> streamRawPredict(
    Map<String, dynamic> request, {
    required String model,
  }) async* {
    final url = '${_service.apiUrlPrefix}models/$model:streamRawPredict';
    final httpRequest = http.Request(
      'POST',
      Uri.parse('${_service.baseUrl}$url'),
    );
    httpRequest.headers['Content-Type'] = 'application/json; charset=utf-8';
    httpRequest.body = jsonEncode(request);

    final response = await _service.client.send(httpRequest);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw _parseMistralError(response.statusCode, body);
    }

    final stream = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    await for (var line in stream) {
      line = line.trim();
      if (line.isEmpty || line == '[DONE]') continue;
      if (line.startsWith('data: ')) line = line.substring(6).trim();
      if (line == '[DONE]') continue;
      yield jsonDecode(line) as Map<String, dynamic>;
    }
  }

  GenkitException _parseMistralError(int statusCode, String body) {
    var message = body;
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map) {
        message = error['message'] as String? ?? body;
      } else if (error is String) {
        message = error;
      } else {
        message = json['message'] as String? ?? body;
      }
    } catch (_) {}

    return GenkitException(
      'Mistral API Error: $message',
      status: StatusCodes.fromHttpStatus(statusCode),
    );
  }
}

GenerativeLanguageBaseClient mistralApiClient({
  required String baseUrl,
  required http.Client client,
  required String projectId,
  required String location,
}) {
  return GenerativeLanguageBaseClient(
    baseUrl: baseUrl,
    client: client,
    apiUrlPrefix:
        '$_mistralApiVersion/projects/$projectId/locations/$location/'
        'publishers/$_mistralPublisher/',
  );
}
