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
import 'package:genkit/plugin.dart'
    show genkitVersion, getPlatformLanguageVersion;
import 'package:genkit/telemetry.dart' show runInNewSpan;
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
        // The whole event, as JS's `detail`.
        details: text,
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
    Object? decoded;
    try {
      decoded = jsonDecode(rest);
    } on FormatException {
      // Not JSON: reported as is below.
    }
    final error = _errorObjectOf(decoded);
    if (error != null) {
      throw GenkitException(
        'Interaction API returned an error: [${error['code']}] '
        '${error['message']}',
        status:
            interactionErrorCodeToGenkitStatus(error['code']) ??
            StatusCode.internal,
        details: _errorDetails(decoded),
      );
    }
    throw GenkitException(
      'Failed to parse the Interactions stream: $rest',
      status: StatusCode.internal,
    );
  }
}

/// A decoded Google API error body without its list wrapping (JS
/// `unwrapErrorBody`): the body is usually `{"error": {...}}`, but the
/// Interactions API sometimes wraps it in a list (`[{"error": {...}}]`, e.g.
/// for an invalid API key).
Object? _unwrapErrorBody(Object? decoded) =>
    decoded is List && decoded.length == 1 ? decoded.single : decoded;

/// The `error` object of a decoded Google API error body, or null.
Map? _errorObjectOf(Object? decoded) {
  final body = _unwrapErrorBody(decoded);
  if (body is! Map) return null;
  final error = body['error'];
  return error is Map ? error : null;
}

/// The [decoded] error body to keep in `GenkitException.details` (JS
/// `detail`, the whole parsed body), as JSON text without the list
/// wrapping. Only called for bodies that are a Google API error.
String _errorDetails(Object? decoded) => jsonEncode(_unwrapErrorBody(decoded));

/// The `X-Goog-Api-Client` header value sent with every request.
String _apiClientHeader() =>
    'genkit-dart/$genkitVersion gl-dart/${getPlatformLanguageVersion()}';

/// Marks a model call to trace in an `httpRequest` debug span (JS
/// `TraceOptions`), with the model for calls on a model path. Streamed
/// calls go through `_send`, which shows `[Streaming Response]` as the
/// output; the others go through `_call`, which shows the response.
final class _Trace {
  final String? model;

  const _Trace({this.model});
}

/// The client for the Gemini API and the Gemini Enterprise Agent Platform.
///
/// Every request goes through one send method, which builds all of the
/// request's headers (authentication included, like JS `getHeaders`) and
/// maps errors the same way for every API method. [client] only carries the
/// bytes.
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

  /// Sent as `x-goog-api-key` (Gemini API).
  final String? apiKey;

  /// Returns the OAuth access token sent as `Authorization: Bearer`, asked
  /// for before each request (the Gemini Enterprise Agent Platform).
  final FutureOr<String> Function()? accessToken;

  /// Extra headers for every request (googleAI's `customHeaders`, the
  /// platform's PayGo headers). They can't replace the headers this client
  /// sets itself (see [_send]).
  final Map<String, String> headers;

  /// Whether model calls run in an `httpRequest` span with the request and
  /// the response (the plugins' `experimentalDebugTraces`, JS
  /// `experimental_debugTraces`). Model listing isn't traced, as in JS.
  final bool debugTraces;

  GenerativeLanguageBaseClient({
    required this.baseUrl,
    required this.client,
    this.apiUrlPrefix = 'v1beta/',
    String? interactionsPath,
    this.apiKey,
    this.accessToken,
    this.headers = const {},
    this.debugTraces = false,
  }) : interactionsPath = interactionsPath ?? '${apiUrlPrefix}interactions';

  /// Completes when [abortOn]'s token is cancelled; every request carries it
  /// as its abort trigger.
  final Completer<void> _aborted = Completer<void>();

  /// Aborts this client's requests (in flight or later) when [token] is
  /// cancelled, like JS's AbortSignal. Returns a disposer to call when the
  /// operation is done.
  ///
  /// Works with `http`'s own clients (IOClient, BrowserClient), including
  /// an injected one; a client that copies requests without their abort
  /// trigger (e.g. googleapis_auth's) can't be aborted this way, and the
  /// operation then stops at its next cancellation check.
  void Function() abortOn(CancellationToken? token) {
    if (token == null) return () {};
    return token.onCancel(() {
      if (!_aborted.isCompleted) _aborted.complete();
    });
  }

  Future<EmbedContentResponse> embedContent(
    EmbedContentRequest request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:embedContent';
    final res = await _call(
      'POST',
      url,
      body: request.toJson(),
      trace: _Trace(model: model),
    );
    return EmbedContentResponse.fromJson(res);
  }

  Future<GenerateContentResponse> generateContent(
    GenerateContentRequest request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:generateContent';
    final res = await _call(
      'POST',
      url,
      body: request.toJson(),
      trace: _Trace(model: model),
    );
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

  /// Lists the platform's publisher models at
  /// `[apiVersion]/publishers/google/models`, without the project and
  /// location (JS vertexAI listModels), with the project in the
  /// `x-goog-user-project` header.
  Future<Map<String, dynamic>> listPublisherModels({
    required String projectId,
    String apiVersion = 'v1beta1',
  }) async {
    final url = '$apiVersion/publishers/google/models';
    return await _call(
      'GET',
      url,
      extraHeaders: {'x-goog-user-project': projectId},
    );
  }

  Future<Map<String, dynamic>> predict(
    Map<String, dynamic> request, {
    required String model,
  }) async {
    final url = '$apiUrlPrefix$model:predict';
    return await _call(
      'POST',
      url,
      body: request,
      trace: _Trace(model: model),
    );
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
      _Trace(model: model),
    ).map(GenerateContentResponse.fromJson);
  }

  /// Creates an interaction (Interactions API, steps schema).
  ///
  /// Sent with the `Api-Revision` header that selects the steps schema (JS
  /// `INTERACTIONS_API_REVISION`).
  Future<GeminiInteraction> createInteraction(
    CreateInteractionRequest request,
  ) async {
    final res = await _call(
      'POST',
      interactionsPath,
      body: request.json,
      extraHeaders: const {'Api-Revision': interactionsApiRevision},
      // The model is in the body (JS adds `model` for generateContent only).
      trace: const _Trace(),
    );
    return GeminiInteraction.fromJson(res);
  }

  /// Creates an interaction and streams its SSE events (`stream: true` is
  /// set on the request).
  Stream<InteractionSseEvent> createInteractionStream(
    CreateInteractionRequest request,
  ) async* {
    final response = await _send(
      'POST',
      interactionsPath,
      body: {...request.json, 'stream': true},
      extraHeaders: const {'Api-Revision': interactionsApiRevision},
      trace: const _Trace(),
    );
    yield* parseInteractionSse(
      response.stream.transform(utf8.decoder).transform(const LineSplitter()),
    );
  }

  /// Sends one request and returns the response once its status is a
  /// success; an error status throws the parsed Google API error.
  ///
  /// Builds every header of the request: the client's [headers] first, then
  /// the method's [extraHeaders] (e.g. `Api-Revision`), then the ones the
  /// client owns (`X-Goog-Api-Client`, `Content-Type` and the API key or
  /// access token), so neither can replace those. As in JS
  /// (`withoutHeaders`), [headers] named like `x-goog-api-key`,
  /// `x-goog-api-client` or one of the method's own headers are left out in
  /// any letter case, so they're never sent next to the client's.
  ///
  /// With [debugTraces] and a [trace], the call runs in an `httpRequest`
  /// span (JS `maybeTraceRequest`): its input is the endpoint, the request
  /// body and the headers (API key and token hidden), and its output
  /// `[Streaming Response]`: the span ends when the response starts, so the
  /// stream isn't held back (as in JS). [_call] traces non-streamed calls
  /// itself, with the response as the output.
  Future<http.StreamedResponse> _send(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    _Trace? trace,
  }) async {
    final request = await _buildRequest(
      method,
      url,
      body: body,
      extraHeaders: extraHeaders,
    );
    if (!debugTraces || trace == null) return _sendRequest(request);
    late final http.StreamedResponse response;
    await runInNewSpan<Map<String, Object?>, String>('httpRequest', (_) async {
      response = await _sendRequest(request);
      return '[Streaming Response]';
    }, input: _traceInput(request, body, trace));
    return response;
  }

  /// The request for [method] on [url], with every header (see [_send]).
  Future<http.AbortableRequest> _buildRequest(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
  }) async {
    final request = http.AbortableRequest(
      method,
      Uri.parse('$baseUrl$url'),
      abortTrigger: _aborted.future,
    );
    final protected = {
      'x-goog-api-key',
      'x-goog-api-client',
      for (final name in extraHeaders.keys) name.toLowerCase(),
    };
    request.headers
      ..addAll({
        for (final MapEntry(:key, :value) in headers.entries)
          if (!protected.contains(key.toLowerCase())) key: value,
      })
      ..addAll(extraHeaders)
      ..['X-Goog-Api-Client'] = _apiClientHeader();
    if (body != null) {
      // Set before the body: the body's encoding follows the content type.
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    if (apiKey case final key?) request.headers['x-goog-api-key'] = key;
    if (accessToken case final token?) {
      request.headers['Authorization'] = 'Bearer ${(await token()).trim()}';
    }
    return request;
  }

  /// Sends [request]; an error status throws the parsed Google API error.
  Future<http.StreamedResponse> _sendRequest(http.BaseRequest request) async {
    final response = await client.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _parseGoogleError(
        response.statusCode,
        await response.stream.bytesToString(),
      );
    }
    return response;
  }

  /// Sends one request and returns its JSON body (`{}` when empty). With
  /// [debugTraces] and a [trace], the span's output is that body (JS
  /// `maybeTraceRequest`).
  Future<Map<String, dynamic>> _call(
    String method,
    String url, {
    Map<String, dynamic>? body,
    Map<String, String> extraHeaders = const {},
    _Trace? trace,
  }) async {
    final request = await _buildRequest(
      method,
      url,
      body: body,
      extraHeaders: extraHeaders,
    );
    Future<Map<String, dynamic>> call() async {
      final response = await http.Response.fromStream(
        await _sendRequest(request),
      );
      if (response.body.isEmpty) return {};
      return jsonDecode(response.body) as Map<String, dynamic>;
    }

    if (!debugTraces || trace == null) return call();
    return runInNewSpan<Map<String, Object?>, Map<String, dynamic>>(
      'httpRequest',
      (_) => call(),
      input: _traceInput(request, body, trace),
    );
  }

  /// The `httpRequest` span input (JS `buildTraceMetadataInput`): the
  /// endpoint, the request body and the headers, with the API key and the
  /// access token replaced by `<REDACTED> (N characters)`, plus the model
  /// for model-path calls.
  Map<String, Object?> _traceInput(
    http.BaseRequest request,
    Map<String, dynamic>? body,
    _Trace trace,
  ) {
    String redacted(String value) => '<REDACTED> (${value.length} characters)';
    final model = trace.model;
    return {
      'apiEndpoint': '${request.url}',
      'request': body,
      'headers': {
        for (final MapEntry(:key, :value) in request.headers.entries)
          key:
              const {
                'x-goog-api-key',
                'authorization',
              }.contains(key.toLowerCase())
              ? redacted(value)
              : value,
      },
      // Callers pass `models/<name>`; JS shows the bare name.
      if (model != null)
        'model': model.startsWith('models/') ? model.substring(7) : model,
    };
  }

  /// Streams a generateContent SSE response: one JSON object per `data:`
  /// line.
  ///
  /// As in JS (`processStream`), a `data:` line that isn't valid JSON throws,
  /// and so does any other text left in the stream, e.g. a plain JSON error
  /// body sent with a 200 when the API is overloaded (see [_streamErrorFor]).
  /// Blank lines, other SSE fields (`event:`, `id:`, `retry:`, comments) and
  /// the bare `[`, `]` and `,` lines of the JSON array format are skipped.
  Stream<Map<String, dynamic>> _callStream(
    String method,
    String url, [
    Map<String, dynamic>? body,
    _Trace? trace,
  ]) async* {
    final response = await _send(method, url, body: body, trace: trace);
    final lines = response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    final leftover = StringBuffer();
    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty || line == '[' || line == ']' || line == ',') continue;
      if (line.startsWith('data:')) {
        final data = line.substring(5).trim();
        Object? decoded;
        try {
          decoded = jsonDecode(data);
        } on FormatException {
          decoded = null;
        }
        if (decoded is! Map<String, dynamic>) {
          throw GenkitException(
            'Error parsing JSON response: "$data"',
            status: StatusCode.internal,
          );
        }
        yield decoded;
      } else if (!line.startsWith('event:') &&
          !line.startsWith('id:') &&
          !line.startsWith('retry:') &&
          !line.startsWith(':')) {
        leftover.writeln(line);
      }
    }
    final rest = leftover.toString().trim();
    if (rest.isNotEmpty) throw _streamErrorFor(rest);
  }

  /// The error for text left in a generateContent stream (JS
  /// `parseStreamErrorText`): a Google API error body gets its own status
  /// and message (its `code` read as the HTTP status), so the retry
  /// middleware can react; anything else is INTERNAL, cut to 500 characters
  /// (e.g. an HTML page from a proxy).
  GenkitException _streamErrorFor(String text) {
    Map? error;
    try {
      error = _errorObjectOf(jsonDecode(text));
    } on FormatException {
      // Not JSON: reported as is below.
    }
    if (error != null) {
      final code = error['code'];
      final httpStatus = code is int ? code : int.tryParse('$code');
      return _parseGoogleError(httpStatus ?? 500, text);
    }
    final shown = text.length > 500 ? '${text.substring(0, 500)}...' : text;
    return GenkitException(
      'Failed to parse stream: $shown',
      status: StatusCode.internal,
    );
  }

  /// The error for a failed response with [statusCode] and [body]. A Google
  /// API error body gives the message and status, and is kept whole in
  /// `details` (as JS's `detail`); any other body goes into the message.
  GenkitException _parseGoogleError(int statusCode, String body) {
    try {
      final decoded = jsonDecode(body);
      final err = _errorObjectOf(decoded);
      if (err != null) {
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
          details: _errorDetails(decoded),
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
