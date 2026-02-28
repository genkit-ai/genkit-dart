import 'dart:async';
import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;

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
        // Map HTTP / Google statuses to Genkit status
        var status = StatusCodes.INTERNAL;
        if (statusCode == 400 || statusStr == 'INVALID_ARGUMENT') {
          status = StatusCodes.INVALID_ARGUMENT;
        }
        if (statusCode == 401 || statusStr == 'UNAUTHENTICATED') {
          status = StatusCodes.UNAUTHENTICATED;
        }
        if (statusCode == 403 || statusStr == 'PERMISSION_DENIED') {
          status = StatusCodes.PERMISSION_DENIED;
        }
        if (statusCode == 404 || statusStr == 'NOT_FOUND') {
          status = StatusCodes.NOT_FOUND;
        }
        if (statusCode == 429 || statusStr == 'RESOURCE_EXHAUSTED') {
          status = StatusCodes.RESOURCE_EXHAUSTED;
        }

        return GenkitException('Google AI Error: $message', status: status);
      }
    } catch (_) {}
    return GenkitException(
      'API Error $statusCode: $body',
      status: StatusCodes.INTERNAL,
    );
  }
}
