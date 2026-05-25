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

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as sdk;
import 'package:genkit/plugin.dart';
import 'package:genkit_anthropic/common.dart' as anthropic;
import 'package:genkit_google_genai/common.dart';
import 'package:http/http.dart' as http;

const _vertexAnthropicVersion = 'vertex-2023-10-16';
const _structuredOutputToolName = '__genkit_output__';

final claudeModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true,
    'systemRole': true,
    'constrained': true,
  },
);

bool isClaudeModel(String name) => name.startsWith('claude-');

ActionMetadata<dynamic, dynamic, dynamic, dynamic> claudeModelMetadata(
  String pluginName,
  String modelName,
) {
  return modelMetadata(
    '$pluginName/$modelName',
    customOptions: anthropic.AnthropicOptions.$schema,
    modelInfo: claudeModelInfo,
  );
}

class VertexClaudeModelFactory {
  VertexClaudeModelFactory({
    required this.pluginName,
    required this.getApiClient,
    required this.resolvedProjectId,
    required this.resolvedLocation,
    required this.shouldCloseClient,
    required this.handleException,
  });

  final String pluginName;
  final Future<GenerativeLanguageBaseClient> Function() getApiClient;
  final String Function() resolvedProjectId;
  final String Function() resolvedLocation;
  final bool Function() shouldCloseClient;
  final GenkitException Function(Object e, StackTrace stack) handleException;

  Model createModel(String modelName) {
    return Model(
      name: '$pluginName/$modelName',
      customOptions: anthropic.AnthropicOptions.$schema,
      metadata: {'model': claudeModelInfo.toJson()},
      fn: (req, ctx) async {
        final modelRequest = req!;
        final options = modelRequest.config == null
            ? anthropic.AnthropicOptions()
            : anthropic.AnthropicOptions.$schema.parse(modelRequest.config!);

        if (options.apiKey != null) {
          throw ArgumentError(
            'apiKey is not supported for Vertex AI Claude models. '
            'Use Application Default Credentials instead.',
          );
        }

        final service = await getApiClient();

        try {
          final createRequest = _buildCreateRequest(
            modelRequest,
            modelName,
            options,
          );

          if (ctx.streamingRequested) {
            final stream = _streamMessage(service, modelName, createRequest);
            final accumulator = sdk.MessageStreamAccumulator();
            await for (final event in stream) {
              accumulator.add(event);
              anthropic.handleAnthropicStreamEvent(event, ctx.sendChunk);
            }
            final message = accumulator.toMessage();
            return ModelResponse(
              finishReason: anthropic.mapFinishReason(message.stopReason),
              message: anthropic.fromAnthropicMessage(
                message,
                structuredOutputToolName: _structuredOutputToolName,
              ),
              usage: anthropic.mapUsage(message.usage),
            );
          }

          final response = await _createMessage(
            service,
            modelName,
            createRequest,
          );
          return ModelResponse(
            finishReason: anthropic.mapFinishReason(response.stopReason),
            message: anthropic.fromAnthropicMessage(
              response,
              structuredOutputToolName: _structuredOutputToolName,
            ),
            usage: anthropic.mapUsage(response.usage),
            raw: response.toJson(),
          );
        } catch (e, stack) {
          if (e is GenkitException) rethrow;
          throw handleException(e, stack);
        } finally {
          if (shouldCloseClient()) {
            service.client.close();
          }
        }
      },
    );
  }

  sdk.MessageCreateRequest _buildCreateRequest(
    ModelRequest req,
    String modelName,
    anthropic.AnthropicOptions options,
  ) {
    return anthropic.toAnthropicCreateRequest(
      req,
      modelName,
      options,
      structuredOutputToolName: _structuredOutputToolName,
      mediaConverter: _convertVertexMedia,
      toolOutputFormatter: _toolOutputText,
    );
  }

  Future<sdk.Message> _createMessage(
    GenerativeLanguageBaseClient service,
    String modelName,
    sdk.MessageCreateRequest request,
  ) async {
    final response = await service.client.post(
      Uri.parse('${service.baseUrl}${_endpointPath(modelName)}'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(_toVertexBody(request, stream: false)),
    );

    if (!_isSuccessStatus(response.statusCode)) {
      throw _parseVertexError(response.statusCode, response.body);
    }

    return sdk.Message.fromJson(
      jsonDecode(response.body) as Map<String, dynamic>,
    );
  }

  Stream<sdk.MessageStreamEvent> _streamMessage(
    GenerativeLanguageBaseClient service,
    String modelName,
    sdk.MessageCreateRequest request,
  ) async* {
    final httpRequest =
        http.Request(
            'POST',
            Uri.parse(
              '${service.baseUrl}${_endpointPath(modelName, stream: true)}',
            ),
          )
          ..headers['Content-Type'] = 'application/json'
          ..body = jsonEncode(_toVertexBody(request, stream: true));

    final response = await service.client.send(httpRequest);

    if (!_isSuccessStatus(response.statusCode)) {
      final body = await response.stream.bytesToString();
      throw _parseVertexError(response.statusCode, body);
    }

    final parser = sdk.SseParser();
    await for (final event in parser.parse(response.stream)) {
      yield sdk.MessageStreamEvent.fromJson(event);
    }
  }

  String _endpointPath(String modelName, {bool stream = false}) {
    final safeProjectId = Uri.encodeComponent(resolvedProjectId());
    final safeLocation = Uri.encodeComponent(resolvedLocation());
    final safeModelName = Uri.encodeComponent(modelName);
    final method = stream ? 'streamRawPredict' : 'rawPredict';

    return 'v1/projects/$safeProjectId/locations/$safeLocation/'
        'publishers/anthropic/models/$safeModelName:$method';
  }

  Map<String, dynamic> _toVertexBody(
    sdk.MessageCreateRequest request, {
    required bool stream,
  }) {
    final body = request.toJson()
      ..remove('model')
      ..['anthropic_version'] = _vertexAnthropicVersion;

    if (stream) {
      body['stream'] = true;
    } else {
      body.remove('stream');
    }

    return body;
  }
}

List<sdk.InputContentBlock> _convertVertexMedia(
  String url,
  String? contentType,
) {
  if (url.startsWith('data:')) {
    final base64Data = anthropic.extractBase64DataUrlData(url);
    final mimeType = contentType ?? 'image/png';
    return [
      sdk.InputContentBlock.image(
        sdk.ImageSource.base64(
          data: base64Data,
          mediaType: anthropic.mapImageMediaType(mimeType),
        ),
      ),
    ];
  }

  throw GenkitException(
    'Vertex AI Claude models require media URLs to be data URLs with base64 '
    'image data.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

String _toolOutputText(dynamic output) {
  return output is String ? output : jsonEncode(output);
}

bool _isSuccessStatus(int statusCode) => statusCode >= 200 && statusCode < 300;

GenkitException _parseVertexError(int statusCode, String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      if (decoded['error'] is Map<String, dynamic>) {
        final error = decoded['error'] as Map<String, dynamic>;
        final message = error['message'] as String? ?? 'Unknown error';
        return GenkitException(
          'Vertex AI error: $message',
          status: StatusCodes.fromHttpStatus(statusCode),
          details: body,
        );
      }
    }
  } catch (_) {}

  return GenkitException(
    'Vertex AI error: $body',
    status: StatusCodes.fromHttpStatus(statusCode),
    details: body,
  );
}
