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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

import 'generated/generativelanguage.dart';
import 'interaction_converters.dart' show interactionErrorCodeToGenkitStatus;
import 'interaction_types.dart';

/// The `Api-Revision` header value that selects the Interactions API steps
/// schema (JS `INTERACTIONS_API_REVISION`).
const interactionsApiRevision = '2026-05-20';

/// Parses Interactions SSE [lines] into events.
///
/// An event is the `data:` lines up to a blank line, joined; other SSE
/// fields (`event:`, `id:`, comments) and the final `data: [DONE]` are
/// ignored. Text that isn't SSE
/// (e.g. a plain JSON error body sent with a 200) throws a GenkitException
/// with the error's status, like JS `parseInteractionStreamErrorText`. An
/// `error` event throws too.
Stream<InteractionSseEvent> parseInteractionSse(Stream<String> lines) async* {
  final data = StringBuffer();
  final leftover = StringBuffer();

  InteractionSseEvent? flush() {
    if (data.isEmpty) return null;
    final text = data.toString();
    data.clear();
    // The stream ends with `data: [DONE]` (seen live); not an event.
    if (text.trim() == '[DONE]') return null;
    final decoded = jsonDecode(text);
    if (decoded is! Map || decoded['event_type'] is! String) return null;
    final event = InteractionSseEvent.fromJson(decoded.cast<String, Object?>());
    if (event.eventType == 'error') {
      final error = ErrorEvent.fromJson(event.json).error;
      throw GenkitException(
        'Interaction API returned an error: [${error?.code}] ${error?.message}',
        status:
            interactionErrorCodeToGenkitStatus(error?.code) ??
            StatusCode.internal,
      );
    }
    return event;
  }

  await for (final line in lines) {
    if (line.isEmpty) {
      final event = flush();
      if (event != null) yield event;
    } else if (line.startsWith('data:')) {
      data.write(line.substring(line.startsWith('data: ') ? 6 : 5));
    } else if (!line.startsWith('event:') &&
        !line.startsWith('id:') &&
        !line.startsWith('retry:') &&
        !line.startsWith(':')) {
      leftover.writeln(line);
    }
  }
  final last = flush();
  if (last != null) yield last;

  final rest = leftover.toString().trim();
  if (rest.isNotEmpty) {
    Object? error;
    try {
      final decoded = jsonDecode(rest);
      if (decoded is Map) error = decoded['error'];
    } on FormatException {
      // Not JSON: reported as is below.
    }
    if (error is Map) {
      throw GenkitException(
        'Interaction API returned an error: [${error['code']}] '
        '${error['message']}',
        status:
            interactionErrorCodeToGenkitStatus(error['code']) ??
            StatusCode.internal,
      );
    }
    throw GenkitException(
      'Failed to parse the Interactions stream: $rest',
      status: StatusCode.internal,
    );
  }
}

class GenerativeLanguageBaseClient {
  final String baseUrl;
  final String apiUrlPrefix;
  final http.Client client;

  /// The Interactions API path, relative to [baseUrl]. Defaults to
  /// `${apiUrlPrefix}interactions` (the Gemini API's
  /// `v1beta/interactions`); the Gemini Enterprise Agent Platform's is
  /// under the project and location, not under the publisher models
  /// prefix.
  final String interactionsPath;

  GenerativeLanguageBaseClient({
    required this.baseUrl,
    required this.client,
    this.apiUrlPrefix = 'v1beta/',
    String? interactionsPath,
  }) : interactionsPath = interactionsPath ?? '${apiUrlPrefix}interactions';

  Future<EmbedContentResponse> embedContent(
    EmbedContentRequest request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:embedContent';
    final res = await _call('POST', url, request.toJson());
    return EmbedContentResponse.fromJson(res);
  }

  Future<GenerateContentResponse> generateContent(
    GenerateContentRequest request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:generateContent';
    final res = await _call('POST', url, request.toJson());
    return GenerateContentResponse.fromJson(res);
  }

  Future<ListModelsResponse> listModels({
    int? pageSize,
    String? pageToken,
  }) async {
    var url = '${apiUrlPrefix}models?';
    if (pageSize != null) url += 'pageSize=$pageSize&';
    if (pageToken != null) url += 'pageToken=$pageToken&';
    final res = await _call('GET', url);
    return ListModelsResponse.fromJson(res);
  }

  Future<Map<String, dynamic>> listPublisherModels({
    required String projectId,
  }) async {
    // Vertex AI endpoint for publisher models uses v1beta1 and does not have the 'projects/...' in the path
    // when using this specific endpoint, but it requires the google user project header (or just works with ADC).
    // The base URL for this is https://{location}-aiplatform.googleapis.com
    // And path is /v1beta1/publishers/google/models
    final url = 'v1beta1/publishers/google/models';
    return await _call('GET', url, null, {'x-goog-user-project': projectId});
  }

  Future<Map<String, dynamic>> predict(
    Map<String, dynamic> request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:predict';
    return await _call('POST', url, request);
  }

  Stream<GenerateContentResponse> streamGenerateContent(
    GenerateContentRequest request, {
    required String model,
  }) async* {
    final url = '$apiUrlPrefix$model:streamGenerateContent?alt=sse';
    yield* _callStream(
      'POST',
      url,
      request.toJson(),
    ).map(GenerateContentResponse.fromJson);
  }

  /// Creates an interaction (Interactions API, steps schema).
  ///
  /// Sent with the `Api-Revision` header that selects the steps schema (JS
  /// `INTERACTIONS_API_REVISION`).
  Future<GeminiInteraction> createInteraction(
    CreateInteractionRequest request,
  ) async {
    final res = await _call('POST', interactionsPath, request.json, const {
      'Api-Revision': interactionsApiRevision,
    });
    return GeminiInteraction.fromJson(res);
  }

  /// Creates an interaction and streams its SSE events (`stream: true` is
  /// set on the request).
  Stream<InteractionSseEvent> createInteractionStream(
    CreateInteractionRequest request,
  ) async* {
    final body = {...request.json, 'stream': true};
    final httpRequest =
        http.Request('POST', Uri.parse('$baseUrl$interactionsPath'))
          ..headers['Content-Type'] = 'application/json'
          ..headers['Api-Revision'] = interactionsApiRevision
          ..body = jsonEncode(body);
    final response = await client.send(httpRequest);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final text = await response.stream.bytesToString();
      throw _parseGoogleError(response.statusCode, text);
    }
    yield* parseInteractionSse(
      response.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }

  Future<Map<String, dynamic>> _call(
    String method,
    String url, [
    Map<String, dynamic>? body,
    Map<String, String>? extraHeaders,
  ]) async {
    final uri = Uri.parse('$baseUrl$url');
    http.Response response;
    final headers = <String, String>{};
    if (method == 'POST') {
      headers['Content-Type'] = 'application/json';
    }
    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    if (method == 'GET') {
      response = await client.get(
        uri,
        headers: headers.isEmpty ? null : headers,
      );
    } else if (method == 'POST') {
      response = await client.post(
        uri,
        body: jsonEncode(body),
        headers: headers,
      );
    } else {
      throw Exception('Unsupported method $method');
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw _parseGoogleError(response.statusCode, response.body);
    }
  }

  Stream<Map<String, dynamic>> _callStream(
    String method,
    String url, [
    Map<String, dynamic>? body,
  ]) async* {
    final uri = Uri.parse('$baseUrl$url');
    final request = http.Request(method, uri);
    request.headers['Content-Type'] = 'application/json';
    if (body != null) {
      request.body = jsonEncode(body);
    }
    final response = await client.send(request);
    if (response.statusCode >= 200 && response.statusCode < 300) {
      final stream = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      await for (var line in stream) {
        line = line.trim();
        if (line.isEmpty) continue;
        if (line == '[') continue;
        if (line == ']') continue;
        if (line.startsWith(',')) line = line.substring(1).trim();
        if (line.startsWith('data: ')) line = line.substring(6).trim();
        try {
          yield jsonDecode(line) as Map<String, dynamic>;
        } catch (e) {
          // ignore trailing or broken chunks
        }
      }
    } else {
      final body = await response.stream.bytesToString();
      throw _parseGoogleError(response.statusCode, body);
    }
  }

  GenkitException _parseGoogleError(int statusCode, String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      if (json['error'] is Map) {
        final err = json['error'] as Map;
        final message = err['message'] as String? ?? 'Unknown error';
        final statusStr = err['status'] as String?;
        // Interactions API errors carry a string `code` (e.g.
        // `rate_limit_exceeded`) instead of a gRPC `status`.
        final interactionStatus = statusStr == null
            ? interactionErrorCodeToGenkitStatus(err['code'])
            : null;
        return GenkitException(
          'Google AI Error: $message',
          status: interactionStatus ?? _errorStatus(statusCode, statusStr),
        );
      }
    } catch (_) {}
    return GenkitException(
      'API Error $statusCode: $body',
      status: _errorStatus(statusCode, null),
    );
  }
}

/// Maps a failed Google API response to a Genkit status.
///
/// The gRPC status string in the error body is more specific than the HTTP
/// status (several gRPC codes share 400 or 409), so it wins when recognized.
/// `ok` and `unknown` are never reported for an error: anything unmapped
/// becomes [StatusCode.internal].
StatusCode _errorStatus(int httpStatus, String? grpcStatus) {
  bool usable(StatusCode s) => s != StatusCode.ok && s != StatusCode.unknown;

  if (grpcStatus != null) {
    final fromBody = StatusCode.fromWireName(grpcStatus);
    if (usable(fromBody)) return fromBody;
  }
  final fromHttp = StatusCode.fromHttpStatus(httpStatus);
  return usable(fromHttp) ? fromHttp : StatusCode.internal;
}
