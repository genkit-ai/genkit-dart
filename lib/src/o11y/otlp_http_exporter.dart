import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;

class CollectorHttpExporter implements sdk.SpanExporter {
  final Uri _uri;
  final Map<String, String> _headers;
  final http.Client _client;
  bool _isShutdown = false;

  CollectorHttpExporter(
    String url, {
    Map<String, String> headers = const {},
    http.Client? client,
  })  : _uri = Uri.parse(url),
        _headers = {...headers},
        _client = client ?? http.Client();

  @override
  void export(List<sdk.ReadOnlySpan> spans) {
    if (_isShutdown) {
      return;
    }

    final body = {
      'resourceSpans': _translateSpans(spans),
    };

    _client
        .post(
      _uri,
      headers: {
        'Content-Type': 'application/json',
        ..._headers,
      },
      body: jsonEncode(body),
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
    final resourceSpans = <sdk.Resource,
        Map<sdk.InstrumentationScope, List<Map<String, dynamic>>>>{};

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
      'startTimeUnixNano': (span.startTime.toInt() * 1000).toString(),
      'endTimeUnixNano': ((span.endTime?.toInt() ?? 0) * 1000).toString(),
      'attributes': _translateAttributes(span.attributes),
      'droppedAttributesCount': 0,
      'events': [],
      'droppedEventsCount': 0,
      'status': _translateStatus(span.status),
      'links': [],
      'droppedLinksCount': 0,
    };
    if (span.parentSpanId?.isValid ?? false) {
      map['parentSpanId'] = span.parentSpanId.toString();
    }
    return map;
  }

  int _translateSpanKind(api.SpanKind kind) {
    switch (kind) {
      case api.SpanKind.internal:
        return 1;
      case api.SpanKind.server:
        return 2;
      case api.SpanKind.client:
        return 3;
      case api.SpanKind.producer:
        return 4;
      case api.SpanKind.consumer:
        return 5;
      default:
        return 0;
    }
  }

  List<Map<String, dynamic>> _translateAttributes(sdk.Attributes attributes) {
    final result = <Map<String, dynamic>>[];
    for (var key in attributes.keys) {
      final value = attributes.get(key);
      if (value is String) {
        result.add({
          'key': key,
          'value': {'stringValue': value}
        });
      } else if (value is bool) {
        result.add({
          'key': key,
          'value': {'boolValue': value}
        });
      } else if (value is int) {
        result.add({
          'key': key,
          'value': {'intValue': value}
        });
      } else if (value is double) {
        result.add({
          'key': key,
          'value': {'doubleValue': value}
        });
      } else {
        result.add({
          'key': key,
          'value': {'stringValue': value.toString()}
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
      default:
        code = 0;
        break;
    }
    return {'code': code, 'message': status.description};
  }
}
