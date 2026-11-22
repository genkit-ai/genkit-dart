// Copyright 2026 Google LLC
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

/// The HTTP side of the System One protocol: one endpoint, its retries, and
/// how its failures map onto Genkit statuses.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart' show parseHttpDate;

import 'json.dart';
import 'questions.dart';
import 'state.dart';

/// Builds one model's request when it is not the native one.
///
/// Gets the model ID and the native body, which it may change, and returns a
/// suffix to the path, which is joined with a slash when it does not start
/// with one, and the body to send.
typedef RouteFn =
    ({String path, Object? body}) Function(
      String model,
      Map<String, Object?> body,
    );

/// Extracts the native response from an endpoint's envelope.
typedef UnwrapFn = String Function(String body);

/// How a server takes System One requests: the paths, and the hooks for a
/// server whose wire is not the native one.
final class Endpoint {
  Endpoint({
    required this.name,
    required this.path,
    this.modelsPath = '',
    this.route,
    this.unwrap,
  });

  /// Names the endpoint in errors.
  final String name;

  /// The request path under the base URL.
  final String path;

  /// The path of the model listing under the base URL, empty when the
  /// endpoint has none.
  final String modelsPath;

  /// Builds one model's request when it is not the native one. Per model,
  /// because one host can serve models on different routes, as Workers AI
  /// does. When null, the native body goes to [path].
  final RouteFn? route;

  /// Extracts the native response from the endpoint's envelope. When null,
  /// the response is the native body. An error it throws is reported under
  /// [name], with its status kept when it is a [GenkitException], or as
  /// UNKNOWN: the server answered with a success code, so neither the
  /// request nor the server is known to be at fault.
  final UnwrapFn? unwrap;
}

/// The top-level fields a request builds itself, which an extra field cannot
/// replace: a different model or questions would detach the request from the
/// model that was called and the questions that were compiled from the
/// output type.
const reservedFields = [
  'model',
  'state',
  'questions',
  'images',
  'audio',
  'videos',
];

/// The native request body, before the endpoint's envelope.
final class DecideRequest {
  DecideRequest({
    required this.state,
    required this.media,
    required this.questions,
    this.extra,
  });

  final Object? state;

  /// Sent in the images, audio, and videos fields, which the servers place
  /// before the state. Each field is sent only when it has media, since a
  /// server that does not read a kind can refuse its field.
  final RequestMedia media;

  final Map<String, WireQuestion> questions;

  /// Merged into the top-level fields, which is the escape hatch to a field
  /// this package does not model. It cannot replace a field the request
  /// builds itself.
  final Map<String, Object?>? extra;

  /// The native JSON body.
  Map<String, Object?> body(String model) => {
    for (final e in (extra ?? const <String, Object?>{}).entries)
      if (!reservedFields.contains(e.key)) e.key: e.value,
    'model': model,
    'state': state,
    'questions': {for (final e in questions.entries) e.key: e.value.toJson()},
    if (media.images.isNotEmpty) 'images': media.images,
    if (media.audio.isNotEmpty) 'audio': media.audio,
    if (media.videos.isNotEmpty) 'videos': media.videos,
  };
}

/// The native response body. Provider, ID, and the cost are gateway
/// additions, absent from a model vendor's own responses.
final class DecideResponse {
  DecideResponse({
    required this.model,
    this.provider,
    this.id,
    required this.answers,
    this.inputTokens = 0,
    this.outputTokens = 0,
    this.cost,
  });

  final String model;
  final String? provider;
  final String? id;
  final Map<String, Map<String, Object?>> answers;
  final int inputTokens;
  final int outputTokens;
  final double? cost;
}

/// One entry of a models listing. A listing names a model by its name, or,
/// as OpenRouter's does, by its ID with a display name beside it; [model] is
/// whichever names the model.
final class ListedModel {
  ListedModel({this.id, this.name});

  final String? id;
  final String? name;

  /// The ID a request names the model by.
  String get model => (id?.isNotEmpty ?? false) ? id! : (name ?? '');
}

/// Retry policy, matching the vendor SDK's defaults: two retries after the
/// first attempt, half a second doubling to five, a quarter of jitter, and
/// the server's Retry-After honored when it sends one.
const maxRetries = 2;
const _retryBase = Duration(milliseconds: 500);
const _retryCap = Duration(seconds: 5);
const _retryAfterCap = Duration(seconds: 30);
const _maxBodyBytes = 8 << 20;

/// Bounds one attempt.
const requestTimeout = Duration(seconds: 30);

/// Waits for a delay between attempts. Injectable so tests do not wait.
typedef Sleep = Future<void> Function(Duration delay);

/// Posts questions to one endpoint.
final class DecideClient {
  DecideClient({
    required this.httpClient,
    required this.baseUrl,
    required this.endpoint,
    this.apiKey = '',
    this.headers = const {},
    this.timeout,
    Sleep? sleep,
    Random? random,
  }) : _sleep = sleep ?? Future<void>.delayed,
       _random = random ?? Random();

  /// Sends the requests.
  final http.Client httpClient;

  /// The origin the endpoint's paths are joined to.
  final String baseUrl;

  /// Sent as a bearer token. A local server, such as Ollama, takes none, and
  /// no authorization header is sent without one.
  final String apiKey;

  /// Sent on every request, before the authorization header.
  final Map<String, String> headers;

  final Endpoint endpoint;

  /// Bounds one attempt; null leaves it to [httpClient].
  final Duration? timeout;

  final Sleep _sleep;
  final Random _random;

  /// Posts one request and decodes the answers.
  Future<DecideResponse> decide(
    String model,
    DecideRequest req, {
    CancellationToken? cancel,
  }) async {
    final native = req.body(model);
    Object? body = native;
    var suffix = '';
    if (endpoint.route case final route?) {
      final routed = route(model, native);
      suffix = routed.path;
      body = routed.body;
      if (suffix.isNotEmpty && !suffix.startsWith('/')) suffix = '/$suffix';
    }
    final String payload;
    try {
      payload = encodeJson(body);
      // An extra field or a route's body can hold a value with no JSON form.
      // ignore: avoid_catching_errors
    } on JsonUnsupportedObjectError catch (e) {
      throw GenkitException(
        '${endpoint.name}: request is not JSON: ${e.unsupportedObject}',
        status: StatusCode.invalidArgument,
      );
    }
    var raw = await _do(
      'POST',
      '$baseUrl${endpoint.path}$suffix',
      payload,
      cancel,
    );
    if (endpoint.unwrap case final unwrap?) {
      try {
        raw = unwrap(raw);
      } catch (e) {
        throw GenkitException(
          '${endpoint.name}: ${e is GenkitException ? e.message : e}',
          status: e is GenkitException ? e.status : StatusCode.unknown,
          cause: e,
        );
      }
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException catch (e) {
      throw _notAnAnswer(e.message);
    }
    if (decoded is! Map) throw _notAnAnswer('not an object');
    final answers = decoded['answers'];
    if (answers == null) {
      throw GenkitException(
        '${endpoint.name}: response carries no answers',
        status: StatusCode.internal,
      );
    }
    if (answers is! Map || answers.values.any((a) => a is! Map)) {
      throw _notAnAnswer('answers is not an object of answers');
    }
    final usage = decoded['usage'] is Map ? decoded['usage'] as Map : const {};
    final model_ = decoded['model'];
    return DecideResponse(
      model: model_ is String ? model_ : '',
      provider: decoded['provider'] is String
          ? decoded['provider'] as String
          : null,
      id: decoded['id'] is String ? decoded['id'] as String : null,
      answers: {
        for (final e in answers.entries)
          e.key.toString(): (e.value as Map).cast<String, Object?>(),
      },
      inputTokens: _number(usage['input_tokens'])?.toInt() ?? 0,
      outputTokens: _number(usage['output_tokens'])?.toInt() ?? 0,
      cost: _number(usage['cost'])?.toDouble(),
    );
  }

  GenkitException _notAnAnswer(String detail) => GenkitException(
    '${endpoint.name}: response is not a System One answer: $detail',
    status: StatusCode.internal,
  );

  /// Fetches the endpoint's model listing.
  ///
  /// Sent once, with no retries: the listing serves the Dev UI, and the
  /// caller falls back to the known models when it fails. The listing's
  /// envelope is not pinned down by the API reference, so a bare array and
  /// the usual wrapping keys are all accepted.
  Future<List<ListedModel>> listModels({Duration? timeout}) async {
    if (endpoint.modelsPath.isEmpty) {
      throw GenkitException(
        '${endpoint.name}: no model listing',
        status: StatusCode.unimplemented,
      );
    }
    final String body;
    try {
      body = (await _once(
        'GET',
        '$baseUrl${endpoint.modelsPath}',
        null,
        null,
        timeout ?? this.timeout,
      )).body;
    } on _AttemptFailed catch (failure) {
      throw failure.error;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException catch (e) {
      throw GenkitException(
        '${endpoint.name}: model listing is not JSON: ${e.message}',
        status: StatusCode.internal,
      );
    }
    List<ListedModel>? models(Object? list) {
      if (list is! List) return null;
      return [
        for (final m in list.whereType<Map>())
          ListedModel(
            id: m['id'] is String ? m['id'] as String : null,
            name: m['name'] is String ? m['name'] as String : null,
          ),
      ];
    }

    if (models(decoded) case final list?) return list;
    if (decoded is Map) {
      for (final key in ['models', 'data']) {
        if (models(decoded[key]) case final list?) return list;
      }
    }
    throw GenkitException(
      '${endpoint.name}: model listing has no models array',
      status: StatusCode.internal,
    );
  }

  /// Sends one request with retries and returns the response body. A request
  /// that fails to connect, times out, is rate limited, or hits a server
  /// error other than 501 and 505 is retried; anything else is the caller's
  /// problem.
  Future<String> _do(
    String method,
    String url,
    String? payload,
    CancellationToken? cancel,
  ) async {
    for (var attempt = 0; ; attempt++) {
      cancel?.throwIfCancelled();
      try {
        return (await _once(method, url, payload, cancel, timeout)).body;
      } on _AttemptFailed catch (failure) {
        if (cancel?.isCancelled ?? false) {
          throw _stopped(cancel!, failure.error);
        }
        if (attempt >= maxRetries || !failure.retry) throw failure.error;
        var delay = _backoff(attempt);
        if (failure.retryAfter case final retryAfter?) {
          delay = retryAfter > _retryAfterCap ? _retryAfterCap : retryAfter;
        }
        final slept = _sleep(delay);
        if (cancel == null) {
          await slept;
        } else {
          // Through onCancel, whose disposer detaches the listener, so a
          // token reused across many calls does not collect one per retry.
          final woke = Completer<void>();
          final stopListening = cancel.onCancel(() {
            if (!woke.isCompleted) woke.complete();
          });
          try {
            await Future.any([slept, woke.future]);
          } finally {
            stopListening();
          }
          if (cancel.isCancelled) throw _stopped(cancel, failure.error);
        }
      }
    }
  }

  /// The error for a request whose caller cancelled it: a cancellation, so
  /// the caller sees that rather than the retryable failure it interrupted.
  /// The last attempt's failure is kept as text only, since its status would
  /// make the call read as worth retrying.
  CancelledException _stopped(CancellationToken cancel, Object last) {
    final reason = cancel.reason;
    return CancelledException(
      reason:
          '${reason is String ? reason : 'Operation was cancelled'} '
          '(last attempt: ${last is GenkitException ? last.message : last})',
      token: cancel,
    );
  }

  /// Sends one attempt. A failure is an [_AttemptFailed] that says whether it
  /// is worth a retry, which is a failure to reach the endpoint, a timeout, a
  /// rate limit, or a server error, and the Retry-After the server asked
  /// for; that is null when the server did not send one, since zero is a
  /// request to retry at once.
  Future<({String body, bool retry, Duration? retryAfter})> _once(
    String method,
    String url,
    String? payload,
    CancellationToken? cancel,
    Duration? timeout,
  ) async {
    final Uri uri;
    try {
      uri = Uri.parse(url);
    } on FormatException catch (e) {
      throw GenkitException(
        '${endpoint.name}: ${e.message}',
        status: StatusCode.invalidArgument,
      );
    }
    final abort = Completer<void>();
    final req = http.AbortableRequest(method, uri, abortTrigger: abort.future);
    req.headers.addAll(headers);
    if (apiKey.isNotEmpty) req.headers['Authorization'] = 'Bearer $apiKey';
    req.headers['Accept'] = 'application/json';
    if (payload != null) {
      req.headers['Content-Type'] = 'application/json';
      req.bodyBytes = utf8.encode(payload);
    }
    // A cancel aborts the request on a client that supports aborting, and
    // ends the wait on any client, so an answer that arrives after the caller
    // gave up is dropped.
    final cancelled = Completer<Never>();
    final stopListening = cancel?.onCancel(() {
      if (!abort.isCompleted) abort.complete();
      if (!cancelled.isCompleted) {
        cancelled.completeError(CancelledException(token: cancel));
      }
    });
    final int status;
    final String body;
    final Map<String, String> responseHeaders;
    try {
      var attempt = _send(req);
      if (timeout != null) {
        attempt = attempt.timeout(
          timeout,
          onTimeout: () {
            if (!abort.isCompleted) abort.complete();
            throw TimeoutException('no response in $timeout');
          },
        );
      }
      (status, body, responseHeaders) = await (cancel == null
          ? attempt
          : Future.any([attempt, cancelled.future]));
    } catch (e) {
      throw _AttemptFailed(
        GenkitException(
          '${endpoint.name}: $e',
          status: StatusCode.unavailable,
          cause: e,
        ),
        retry: true,
      );
    } finally {
      stopListening?.call();
    }
    if (status ~/ 100 == 2) {
      return (body: body, retry: false, retryAfter: null);
    }
    final retry =
        status == 408 ||
        status == 429 ||
        (status >= 500 && status != 501 && status != 505);
    throw _AttemptFailed(
      httpError(endpoint.name, status, body),
      retry: retry,
      retryAfter: parseRetryAfter(responseHeaders['retry-after']),
    );
  }

  /// Sends [req] and reads at most [_maxBodyBytes] of the response.
  Future<(int, String, Map<String, String>)> _send(http.BaseRequest req) async {
    final resp = await httpClient.send(req);
    final bytes = <int>[];
    await for (final chunk in resp.stream) {
      final room = _maxBodyBytes - bytes.length;
      if (chunk.length >= room) {
        bytes.addAll(chunk.take(room));
        break;
      }
      bytes.addAll(chunk);
    }
    return (
      resp.statusCode,
      utf8.decode(bytes, allowMalformed: true),
      resp.headers,
    );
  }

  Duration _backoff(int attempt) {
    var delay = _retryBase * (1 << attempt);
    if (delay > _retryCap) delay = _retryCap;
    final jitter = delay * (_random.nextDouble() * 0.25);
    return delay - jitter;
  }
}

/// A usage counter, or null when the server sent none or not a number:
/// usage is reporting, and a gateway's odd field must not cost the answers.
num? _number(Object? value) => value is num ? value : null;

/// One attempt that failed, and whether it is worth another.
final class _AttemptFailed implements Exception {
  _AttemptFailed(this.error, {required this.retry, this.retryAfter});

  final GenkitException error;
  final bool retry;
  final Duration? retryAfter;
}

/// Maps an error response onto a Genkit status: the canonical HTTP mapping,
/// with the codes the endpoints give their own meaning handled first. The
/// body is searched for the message under the shapes the endpoints use.
GenkitException httpError(String endpoint, int code, String body) {
  final StatusCode status;
  if (code == 402) {
    // Out of credit at a gateway: a quota, not a bad request.
    status = StatusCode.resourceExhausted;
  } else if (code == 408 || code == 504 || code == 524) {
    // 524 is Cloudflare's origin timeout.
    status = StatusCode.deadlineExceeded;
  } else if (code == 501 || code == 505) {
    // A server without the path or the protocol: a setup to fix, not a
    // failure to wait out.
    status = StatusCode.unimplemented;
  } else if (code > 500) {
    // Every other server-side failure reads as transient.
    status = StatusCode.unavailable;
  } else {
    final mapped = StatusCode.fromHttpStatus(code);
    // A client error the mapping does not name, such as 422, is the
    // request's fault.
    status = mapped == StatusCode.unknown ? StatusCode.invalidArgument : mapped;
  }
  var message = errorMessage(body);
  if (message.isEmpty) message = _statusText[code] ?? 'empty response';
  return GenkitException(
    '$endpoint: HTTP $code: $message',
    status: status,
    details: body.isEmpty ? null : body,
  );
}

const _statusText = {
  400: 'Bad Request',
  401: 'Unauthorized',
  402: 'Payment Required',
  403: 'Forbidden',
  404: 'Not Found',
  408: 'Request Timeout',
  422: 'Unprocessable Entity',
  429: 'Too Many Requests',
  500: 'Internal Server Error',
  501: 'Not Implemented',
  502: 'Bad Gateway',
  503: 'Service Unavailable',
  504: 'Gateway Timeout',
  505: 'HTTP Version Not Supported',
};

/// Reads the message out of an error body.
///
/// The endpoints use four shapes: `{error: {message}}` or `{error: "..."}`, a
/// `{message}`, a Cloudflare `{errors: [{code, message}]}` envelope, and a
/// validation list, which TypeSafe's API sends under `detail` as `{loc, msg}`
/// records and OpenRouter sends as the bare array of `{path, message}`
/// records. A body in none of these shapes is quoted as it came, cut at 200
/// characters, and an empty one gives "".
String errorMessage(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    decoded = null;
  }
  if (_validationErrors(decoded) case final msg? when msg.isNotEmpty) {
    return msg;
  }
  if (decoded is Map) {
    final error = decoded['error'];
    if (error is Map && error['message'] is String && error['message'] != '') {
      return error['message'] as String;
    }
    if (error is String && error.isNotEmpty) return error;
    final message = decoded['message'];
    if (message is String && message.isNotEmpty) return message;
    if (_validationErrors(decoded['errors']) case final msg?
        when msg.isNotEmpty) {
      return msg;
    }
    final detail = decoded['detail'];
    if (detail != null) {
      if (_validationErrors(detail) case final msg? when msg.isNotEmpty) {
        return msg;
      }
      if (detail is String && detail.isNotEmpty) return detail;
      return jsonEncode(detail);
    }
  }
  var msg = body.trim();
  if (msg.length > 200) msg = '${msg.substring(0, 200)}...';
  return msg;
}

/// Joins a list of validation records into one line, each as its path and
/// message, or returns null when the value is not such a list.
String? _validationErrors(Object? value) {
  if (value is! List || value.isEmpty) return null;
  final msgs = <String>[];
  for (final record in value) {
    if (record is! Map) return null;
    final message = record['message'] ?? record['msg'];
    if (message is! String || message.isEmpty) continue;
    final path = [
      ...(record['path'] is List ? record['path'] as List : const []),
      ...(record['loc'] is List ? record['loc'] as List : const []),
    ];
    msgs.add(path.isEmpty ? message : '${path.join('.')}: $message');
  }
  return msgs.join('; ');
}

/// Reads a Retry-After header, given either as seconds or as an HTTP date.
/// It is null when there is no usable header, and zero when the server asks
/// for an immediate retry.
Duration? parseRetryAfter(String? header) {
  if (header == null || header.isEmpty) return null;
  final seconds = int.tryParse(header.trim());
  if (seconds != null) {
    return seconds < 0 ? Duration.zero : Duration(seconds: seconds);
  }
  try {
    final wait = parseHttpDate(header).difference(DateTime.now());
    return wait.isNegative ? Duration.zero : wait;
  } on FormatException {
    return null;
  }
}
