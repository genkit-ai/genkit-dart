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

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as sdk;
import 'package:genkit/plugin.dart';

import 'converters.dart';
import 'model.dart';

/// Default model capabilities shared by all Anthropic Claude models.
final commonModelInfo = ModelInfo(
  supports: {
    'multiturn': true,
    'media': true,
    'tools': true,
    'toolChoice': true, // Anthropic supports tool choice
    'systemRole': true,
    'constrained':
        true, // Supports JSON schema (via tool/constrained mode usually, or just prompt)
  },
);

/// Core Genkit plugin implementation for Anthropic Claude models.
///
/// Automatically discovers available models from the Anthropic API and
/// registers them in the Genkit action registry.
class AnthropicPluginImpl extends GenkitPlugin {
  /// The static API key used to authenticate requests.
  final String? apiKey;

  /// Extra HTTP headers sent with every request.
  final Map<String, String>? headers;

  /// Custom base URL for the Anthropic API.
  final String? baseUrl;

  sdk.AnthropicClient? _client;

  /// Creates an [AnthropicPluginImpl].
  AnthropicPluginImpl({this.apiKey, this.headers, this.baseUrl});

  @override
  String get name => 'anthropic';

  sdk.AnthropicClient get client {
    if (_client != null) return _client!;
    if (apiKey != null) {
      return _client = sdk.AnthropicClient.withApiKey(
        apiKey!,
        defaultHeaders: headers,
        baseUrl: baseUrl,
      );
    }
    final config = sdk.AnthropicConfig.fromEnvironment();
    return _client = sdk.AnthropicClient(
      config: config.copyWith(defaultHeaders: headers, baseUrl: baseUrl),
    );
  }

  @override
  Future<List<ActionMetadata>> list() async {
    // Attempt to list models from the API if available, otherwise return manual list.
    try {
      final response = await client.models.list();
      return response.data
          .map(
            (m) => modelMetadata(
              'anthropic/${m.id}',
              customOptions: AnthropicOptions.$schema,
            ),
          )
          .toList();
    } catch (e, s) {
      // Fallback or empty if listing fails/not supported as expected
      print('Failed to list Anthropic models: $e\n$s');
      return [];
    }
  }

  @override
  Action? resolve(String actionType, String name) {
    if (actionType != 'model') return null;
    return _createModel(name);
  }

  Model _createModel(String modelName) {
    return _createModelWithClient(modelName, client);
  }

  Model _createModelWithClient(String modelName, sdk.AnthropicClient client) {
    return Model(
      name: 'anthropic/$modelName',
      customOptions: AnthropicOptions.$schema,
      metadata: {'model': commonModelInfo.toJson()},
      fn: (req, ctx) async {
        final options = req!.config == null
            ? AnthropicOptions()
            : AnthropicOptions.$schema.parse(req.config!);

        final requestClient = options.apiKey != null
            ? sdk.AnthropicClient.withApiKey(
                options.apiKey!,
                defaultHeaders: headers,
                baseUrl: baseUrl,
              )
            : client;

        try {
          final createRequest = toAnthropicCreateRequest(
            req,
            modelName,
            options,
          );

          if (ctx.streamingRequested) {
            final stream = requestClient.messages.createStream(createRequest);
            final accumulator = sdk.MessageStreamAccumulator();
            await for (final event in stream) {
              accumulator.add(event);
              handleAnthropicStreamEvent(event, ctx.sendChunk);
            }
            final message = accumulator.toMessage();
            return ModelResponse(
              finishReason: mapFinishReason(message.stopReason),
              message: fromAnthropicMessage(message),
              usage: mapUsage(message.usage),
            );
          } else {
            final response = await requestClient.messages.create(createRequest);
            return ModelResponse(
              finishReason: mapFinishReason(response.stopReason),
              message: fromAnthropicMessage(response),
              usage: mapUsage(response.usage),
              raw: response.toJson(),
            );
          }
        } catch (e, stackTrace) {
          if (e is GenkitException) rethrow;
          StatusCodes? status;
          String? details;
          if (e is sdk.ApiException) {
            status = StatusCodes.fromHttpStatus(e.statusCode);
            details = e.message;
          }
          throw GenkitException(
            'Anthropic API error: $e',
            status: status,
            details: details ?? e.toString(),
            underlyingException: e,
            stackTrace: stackTrace,
          );
        } finally {
          if (options.apiKey != null) {
            requestClient.close();
          }
        }
      },
    );
  }

  void close() {
    _client?.close();
  }
}
