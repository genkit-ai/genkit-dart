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
import 'package:genkit/plugin.dart' show parseRetryAfter;
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'generated/generativelanguage.dart';

class GenerativeLanguageBaseClient {
  final String baseUrl;
  final String apiUrlPrefix;
  final http.Client client;

  GenerativeLanguageBaseClient({
    required this.baseUrl,
    required this.client,
    this.apiUrlPrefix = 'v1beta/',
  });

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
      throw parseGoogleError(
        response.statusCode,
        response.body,
        response.headers,
      );
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
      throw parseGoogleError(response.statusCode, body, response.headers);
    }
  }
}

/// Converts a non-2xx Google API response into a [GenkitException].
///
/// The retry hint comes from the `Retry-After` header, or failing that from a
/// `google.rpc.RetryInfo` entry in `error.details`, which is where Google APIs
/// usually put it.
@visibleForTesting
GenkitException parseGoogleError(
  int statusCode,
  String body, [
  Map<String, String> headers = const {},
]) {
  final headerRetryAfter = parseRetryAfter(headers['retry-after']);
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['error'] is Map) {
      final err = json['error'] as Map;
      final message = err['message'] as String? ?? 'Unknown error';
      final statusStr = err['status'] as String?;
      return GenkitException(
        'Google AI Error: $message',
        status: _errorStatus(statusCode, statusStr),
        retryAfter: headerRetryAfter ?? _retryInfoDelay(err['details']),
      );
    }
  } catch (_) {}
  return GenkitException(
    'API Error $statusCode: $body',
    status: _errorStatus(statusCode, null),
    retryAfter: headerRetryAfter,
  );
}

/// Extracts `retryDelay` (a protobuf Duration in JSON form, e.g. `"37s"` or
/// `"1.5s"`) from a `google.rpc.RetryInfo` detail.
Duration? _retryInfoDelay(Object? details) {
  if (details is! List) return null;
  for (final d in details) {
    if (d is Map &&
        d['@type'] == 'type.googleapis.com/google.rpc.RetryInfo' &&
        d['retryDelay'] is String) {
      final raw = d['retryDelay'] as String;
      if (!raw.endsWith('s')) return null;
      final seconds = double.tryParse(raw.substring(0, raw.length - 1));
      if (seconds == null || seconds.isNaN || seconds < 0) return null;
      return Duration(milliseconds: (seconds * 1000).round());
    }
  }
  return null;
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
