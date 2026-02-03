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
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

import '../utils.dart';

final _logger = Logger('CollectorHttpExporter');

class CollectorHttpExporter implements sdk.SpanExporter {
  final Uri _uri;
  final Map<String, String> _headers;
  final http.Client _client;
  bool _isShutdown = false;

  CollectorHttpExporter(
    String url, {
    Map<String, String> headers = const {},
    http.Client? client,
  }) : _uri = Uri.parse(url),
       _headers = {...headers},
       _client = client ?? http.Client();

  @override
  void export(List<sdk.ReadOnlySpan> spans) {
    if (_isShutdown) {
      return;
    }

    final body = {'resourceSpans': _translateSpans(spans)};

    _client
        .post(
          _uri,
          headers: {'Content-Type': 'application/json', ..._headers},
          body: jsonEncode(body),
        )
        .then(
          (_) {},
          onError: (e, stackTrace) {
            _logger.severe('Failed to export spans: $e', stackTrace);
          },
        );
  }

  @override
  void forceFlush() {
    // This exporter does not buffer spans, so this is a no-op.
  }

  @override
  void shutdown() {
    _isShutdown = true;
  }

  List<Map<String, dynamic>> _translateSpans(List<sdk.ReadOnlySpan> spans) {
    final resourceSpans =
        <
          sdk.Resource,
          Map<sdk.InstrumentationScope, List<Map<String, dynamic>>>
        >{};

    for (final span in spans) {
      final resource = span.resource;
      final scope = span.instrumentationScope;

      final scopeSpans = resourceSpans.putIfAbsent(resource, () => {});
      final spanList = scopeSpans.putIfAbsent(scope, () => []);

      spanList.add(_translateSpan(span));
    }

    return resourceSpans.entries.map((resourceEntry) {
      return {
        'resource': {
          'attributes': _translateAttributes(resourceEntry.key.attributes),
          'droppedAttributesCount': 0,
        },
        'scopeSpans': resourceEntry.value.entries.map((scopeEntry) {
          return {
            'scope': {
              'name': scopeEntry.key.name,
              'version': scopeEntry.key.version,
            },
            'spans': scopeEntry.value,
          };
        }).toList(),
      };
    }).toList();
  }

  Map<String, dynamic> _translateSpan(sdk.ReadOnlySpan span) {
    final map = <String, dynamic>{
      'traceId': span.spanContext.traceId.toString(),
      'spanId': span.spanContext.spanId.toString(),
      'name': span.name,
      'kind': _translateSpanKind(span.kind),
      'startTimeUnixNano': span.startTime.toInt().toString(),
      'endTimeUnixNano': (span.endTime?.toInt() ?? 0).toString(),
      'attributes': _translateAttributes(span.attributes),
      'droppedAttributesCount': 0,
      'events': [],
      'droppedEventsCount': 0,
      'status': _translateStatus(span.status),
      'links': [],
      'droppedLinksCount': 0,
    };
    if (span.parentSpanId.isValid) {
      map['parentSpanId'] = span.parentSpanId.toString();
    }
    return map;
  }

  int _translateSpanKind(api.SpanKind kind) {
    return switch (kind) {
      api.SpanKind.internal => 1,
      api.SpanKind.server => 2,
      api.SpanKind.client => 3,
      api.SpanKind.producer => 4,
      api.SpanKind.consumer => 5,
    };
  }

  List<Map<String, dynamic>> _translateAttributes(sdk.Attributes attributes) {
    final result = <Map<String, dynamic>>[];
    for (var key in attributes.keys) {
      final value = attributes.get(key);
      if (value is String) {
        result.add({
          'key': key,
          'value': {'stringValue': value},
        });
      } else if (value is bool) {
        result.add({
          'key': key,
          'value': {'boolValue': value},
        });
      } else if (value is int) {
        result.add({
          'key': key,
          'value': {'intValue': value},
        });
      } else if (value is double) {
        result.add({
          'key': key,
          'value': {'doubleValue': value},
        });
      } else {
        result.add({
          'key': key,
          'value': {'stringValue': value.toString()},
        });
      }
    }
    return result;
  }

  Map<String, dynamic> _translateStatus(api.SpanStatus status) {
    int code;
    switch (status.code) {
      case api.StatusCode.ok:
        code = 1;
        break;
      case api.StatusCode.error:
        code = 2;
        break;
      case api.StatusCode.unset:
        code = 0;
        break;
    }
    return {'code': code, 'message': status.description};
  }
}

void configureCollectorExporter() {
  // Configure the OTLP HTTP Exporter
  final baseUrl =
      getConfigVar('GENKIT_TELEMETRY_SERVER') ?? 'http://localhost:4041';
  final exporter = CollectorHttpExporter('$baseUrl/api/otlp');
  final processor = sdk.SimpleSpanProcessor(exporter);
  final provider = sdk.TracerProviderBase(processors: [processor]);
  api.registerGlobalTracerProvider(provider);
}
