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

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import 'span_data.dart';

final _logger = Logger('CollectorHttpSink');

/// A [SpanSink] that POSTs OTLP/JSON spans to the Genkit telemetry server.
///
/// This is the fallback (and, when a user hasn't set up OpenTelemetry, the
/// primary) path: it needs no OTel runtime, it just serializes [GenkitSpanData]
/// and fires it at `$server/api/otlp`. Exports are fire-and-forget so tracing
/// never blocks the traced operation.
class CollectorHttpSink implements SpanSink {
  final Uri _uri;
  final Map<String, String> _headers;
  final http.Client _client;
  bool _isShutdown = false;

  CollectorHttpSink(
    String url, {
    Map<String, String> headers = const {},
    http.Client? client,
  }) : _uri = Uri.parse(url),
       _headers = {...headers},
       _client = client ?? http.Client();

  @override
  void export(List<GenkitSpanData> spans) {
    if (_isShutdown || spans.isEmpty) return;

    final body = {'resourceSpans': encodeResourceSpans(spans)};

    _client
        .post(
          _uri,
          headers: {'Content-Type': 'application/json', ..._headers},
          body: jsonEncode(body),
        )
        .then(
          (_) {},
          onError: (Object e, StackTrace stackTrace) {
            _logger.severe('Failed to export spans: $e', e, stackTrace);
          },
        );
  }

  @override
  void shutdown() {
    _isShutdown = true;
  }
}
