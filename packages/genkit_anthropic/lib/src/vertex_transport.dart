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
import 'package:genkit_vertex_auth/genkit_vertex_auth.dart';
import 'package:http/http.dart' as http;

import 'vertex_config.dart';

const _anthropicVertexVersion = 'vertex-2023-10-16';

/// HTTP transport adapter for Anthropic-on-Vertex requests.
///
/// This helper encapsulates endpoint selection, request serialization,
/// authorization headers, SSE data extraction, and error translation.
class AnthropicVertexTransport {
  final AnthropicVertexConfig config;
  final http.Client httpClient;

  /// Creates a transport with the provided [config] and [httpClient].
  AnthropicVertexTransport({required this.config, required this.httpClient});

  /// Converts an Anthropic request into a Vertex partner-model request body.
  Map<String, dynamic> toRequestBody(sdk.CreateMessageRequest request) {
    final body = request.toJson();
    body.remove('model');
    body['anthropic_version'] = _anthropicVertexVersion;
    return body;
  }

  /// Sends a Vertex request for [modelName].
  ///
  /// When [stream] is true, requests `streamRawPredict`; otherwise uses
  /// `rawPredict`.
  ///
  /// Returns the successful streamed response, or throws [GenkitException] for
  /// non-2xx responses.
  Future<http.StreamedResponse> sendRequest({
    required String modelName,
    required Map<String, dynamic> body,
    required bool stream,
  }) async {
    final token = (await config.resolveAccessToken()).trim();
    final request = http.Request(
      'POST',
      Uri.parse(_endpoint(modelName: modelName, stream: stream)),
    );
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Content-Type'] = 'application/json';
    request.headers['Accept'] = stream
        ? 'text/event-stream'
        : 'application/json';
    request.headers['x-goog-api-client'] = googleApiClientHeaderValue();
    request.body = jsonEncode(body);

    final response = await httpClient.send(request);
    if ((response.statusCode ~/ 100) == 2) {
      return response;
    }

    final errorBody = await response.stream.bytesToString();
    throw _toException(response.statusCode, errorBody);
  }

  /// Extracts non-empty SSE `data:` payload lines from a byte stream.
  Stream<String> sseDataLines(Stream<List<int>> stream) {
    return stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.startsWith('data:'))
        .map((line) => line.substring(5).trim())
        .where((line) => line.isNotEmpty);
  }

  String _endpoint({required String modelName, required bool stream}) {
    final normalizedLocation = config.location.trim().toLowerCase();
    final apiHost = normalizedLocation == 'global'
        ? 'aiplatform.googleapis.com'
        : '$normalizedLocation-aiplatform.googleapis.com';
    final method = stream ? 'streamRawPredict' : 'rawPredict';
    final project = Uri.encodeComponent(config.resolveProjectId());
    final location = Uri.encodeComponent(normalizedLocation);
    final model = Uri.encodeComponent(modelName);
    return 'https://$apiHost/v1/projects/$project/locations/$location/publishers/anthropic/models/$model:$method';
  }

  GenkitException _toException(int statusCode, String body) {
    var message = 'Vertex Anthropic request failed with status $statusCode.';

    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['error'] is Map) {
        final error = decoded['error'] as Map;
        final errorMessage = error['message'];
        if (errorMessage is String && errorMessage.isNotEmpty) {
          message = errorMessage;
        }
      }
    } catch (_) {
      final fallbackMessage = _fallbackMessageFromBody(body);
      if (fallbackMessage != null) {
        message = fallbackMessage;
      }
    }

    return GenkitException(
      message,
      status: StatusCodes.fromHttpStatus(statusCode),
      details: body.isEmpty ? null : body,
    );
  }

  String? _fallbackMessageFromBody(String body) {
    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    final lowerTrimmed = trimmed.toLowerCase();
    if (lowerTrimmed.startsWith('<!doctype html') ||
        lowerTrimmed.startsWith('<html')) {
      return null;
    }

    final firstLine = LineSplitter.split(
      trimmed,
    ).firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');

    if (firstLine.isEmpty) {
      return null;
    }

    const maxLength = 240;
    if (firstLine.length <= maxLength) {
      return firstLine;
    }
    return '${firstLine.substring(0, maxLength)}...';
  }
}
