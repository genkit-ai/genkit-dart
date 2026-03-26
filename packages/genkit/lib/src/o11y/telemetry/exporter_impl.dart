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

// ignore_for_file: invalid_use_of_visible_for_testing_member

import 'dart:async';
import 'dart:convert';

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

final _logger = Logger('CollectorHttpExporter');

void setupExporter(String baseUrl) {
  try {
    final exporter = CollectorHttpExporter('$baseUrl/api/otlp');
    final processor = RealtimeSpanProcessor(exporter);

    OTelFactory.otelFactory ??= otelSDKFactoryFactoryFunction(
      apiEndpoint: baseUrl,
      apiServiceName: 'genkit-dart',
      apiServiceVersion: '0.12.0',
    );

    OTel.tracerProvider().addSpanProcessor(processor);
  } catch (e, stackTrace) {
    _logger.warning(
      'Failed to configure telemetry exporter: $e',
      e,
      stackTrace,
    );
  }
}

class CollectorHttpExporter implements SpanExporter {
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
  Future<void> export(List<Span> spans) async {
    if (_isShutdown) {
      return;
    }

    final body = {'resourceSpans': _translateSpans(spans)};

    try {
      await _client.post(
        _uri,
        headers: {'Content-Type': 'application/json', ..._headers},
        body: jsonEncode(body),
      );
    } catch (e, stackTrace) {
      _logger.severe('Failed to export spans: $e', stackTrace);
    }
  }

  @override
  Future<void> forceFlush() async {
    // This exporter does not buffer spans, so this is a no-op.
  }

  @override
  Future<void> shutdown() async {
    _isShutdown = true;
  }

  List<Map<String, dynamic>> _translateSpans(List<Span> spans) {
    final resourceGroups =
        <
          Resource?,
          Map<String, (InstrumentationScope, List<Map<String, dynamic>>)>
        >{};

    for (final span in spans) {
      final resource = span.resource;
      final scope = span.instrumentationScope;
      final scopeKey = '${scope.name}:${scope.version}:${scope.schemaUrl}';

      final scopeSpans = resourceGroups.putIfAbsent(resource, () => {});
      final scopeEntry = scopeSpans.putIfAbsent(scopeKey, () => (scope, []));

      scopeEntry.$2.add(_translateSpan(span));
    }

    return resourceGroups.entries.map((resourceEntry) {
      final resource = resourceEntry.key;
      return {
        'resource': {
          'attributes': resource != null
              ? _translateAttributes(resource.attributes)
              : [],
          'droppedAttributesCount': 0,
        },
        'scopeSpans': resourceEntry.value.values.map((scopeGroup) {
          final scope = scopeGroup.$1;
          return {
            'scope': {'name': scope.name, 'version': scope.version},
            'spans': scopeGroup.$2,
          };
        }).toList(),
      };
    }).toList();
  }

  Map<String, dynamic> _translateSpan(Span span) {
    final map = <String, dynamic>{
      'traceId': span.spanContext.traceId.toString(),
      'spanId': span.spanContext.spanId.toString(),
      'name': span.name,
      'kind': _translateSpanKind(span.kind),
      'startTimeUnixNano': (span.startTime.microsecondsSinceEpoch * 1000)
          .toString(),
      'endTimeUnixNano': (span.endTime != null)
          ? (span.endTime!.microsecondsSinceEpoch * 1000).toString()
          : '0',
      'attributes': _translateAttributes(span.attributes),
      'droppedAttributesCount': 0,
      'events': _translateEvents(span.spanEvents),
      'droppedEventsCount': 0,
      'status': _translateStatus(span.status, span.statusDescription),
      'links': _translateLinks(span.spanLinks),
      'droppedLinksCount': 0,
    };
    final parentSpanId = span.spanContext.parentSpanId;
    if (parentSpanId != null && parentSpanId.isValid) {
      map['parentSpanId'] = parentSpanId.toString();
    }
    return map;
  }

  int _translateSpanKind(SpanKind kind) {
    return switch (kind) {
      SpanKind.internal => 1,
      SpanKind.server => 2,
      SpanKind.client => 3,
      SpanKind.producer => 4,
      SpanKind.consumer => 5,
    };
  }

  List<Map<String, dynamic>> _translateAttributes(Attributes attributes) {
    final result = <Map<String, dynamic>>[];
    for (var attr in attributes.toList()) {
      final value = attr.value;
      if (value is String) {
        result.add({
          'key': attr.key,
          'value': {'stringValue': value},
        });
      } else if (value is bool) {
        result.add({
          'key': attr.key,
          'value': {'boolValue': value},
        });
      } else if (value is int) {
        result.add({
          'key': attr.key,
          'value': {'intValue': value},
        });
      } else if (value is double) {
        result.add({
          'key': attr.key,
          'value': {'doubleValue': value},
        });
      } else {
        result.add({
          'key': attr.key,
          'value': {'stringValue': value.toString()},
        });
      }
    }
    return result;
  }

  Map<String, dynamic> _translateStatus(
    SpanStatusCode status,
    String? message,
  ) {
    final code = switch (status) {
      SpanStatusCode.Ok => 1,
      SpanStatusCode.Error => 2,
      SpanStatusCode.Unset => 0,
    };
    return {'code': code, 'message': message ?? ''};
  }

  List<Map<String, dynamic>> _translateEvents(List<SpanEvent>? events) {
    if (events == null) return [];
    return events
        .map(
          (e) => {
            'timeUnixNano': (e.timestamp.microsecondsSinceEpoch * 1000)
                .toString(),
            'name': e.name,
            'attributes': e.attributes != null
                ? _translateAttributes(e.attributes!)
                : [],
            'droppedAttributesCount': 0,
          },
        )
        .toList();
  }

  List<Map<String, dynamic>> _translateLinks(List<SpanLink>? links) {
    if (links == null) return [];
    return links
        .map(
          (l) => {
            'traceId': l.spanContext.traceId.toString(),
            'spanId': l.spanContext.spanId.toString(),
            'attributes': _translateAttributes(l.attributes),
            'droppedAttributesCount': 0,
          },
        )
        .toList();
  }
}

class RealtimeSpanProcessor implements SpanProcessor {
  final SpanExporter _exporter;

  RealtimeSpanProcessor(this._exporter);

  @override
  Future<void> onStart(Span span, Context? parentContext) async {
    await _exporter.export([span]);
  }

  @override
  Future<void> onEnd(Span span) async {
    await _exporter.export([span]);
  }

  @override
  Future<void> shutdown() async {
    await _exporter.shutdown();
  }

  @override
  Future<void> forceFlush() async {
    await _exporter.forceFlush();
  }

  @override
  Future<void> onNameUpdate(Span span, String newName) async {
    // ignore
  }
}
