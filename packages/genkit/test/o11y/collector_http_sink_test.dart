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

// ignore_for_file: avoid_dynamic_calls

import 'dart:convert';

import 'package:genkit/src/o11y/telemetry/collector_http_sink.dart';
import 'package:genkit/src/o11y/telemetry/span_data.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  group('encodeResourceSpans', () {
    test('produces OTLP JSON grouped by resource and scope', () {
      final spans = [
        GenkitSpanData(
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          parentSpanId: 'c' * 16,
          name: 'test-span',
          startTimeUnixNano: 1000,
          endTimeUnixNano: 2000,
          attributes: const {'test-attribute': 'test-value'},
          status: const GenkitSpanStatus(
            code: GenkitStatusCode.error,
            message: 'test-error',
          ),
          scopeName: 'test-tracer',
          scopeVersion: '1.2.3',
          resourceAttributes: const {'service.name': 'test-service'},
        ),
      ];

      final resourceSpans = encodeResourceSpans(spans);
      expect(resourceSpans.length, 1);

      final resourceSpan = resourceSpans[0];
      expect(resourceSpan['resource']['attributes'][0]['key'], 'service.name');
      expect(
        resourceSpan['resource']['attributes'][0]['value']['stringValue'],
        'test-service',
      );

      final scopeSpans = resourceSpan['scopeSpans'] as List;
      expect(scopeSpans.length, 1);

      final scopeSpan = scopeSpans[0];
      expect(scopeSpan['scope']['name'], 'test-tracer');
      expect(scopeSpan['scope']['version'], '1.2.3');

      final encodedSpans = scopeSpan['spans'] as List;
      expect(encodedSpans.length, 1);

      final span = encodedSpans[0];
      expect(span['traceId'], 'a' * 32);
      expect(span['spanId'], 'b' * 16);
      expect(span['parentSpanId'], 'c' * 16);
      expect(span['name'], 'test-span');
      expect(span['kind'], 1); // INTERNAL
      expect(span['startTimeUnixNano'], '1000');
      expect(span['endTimeUnixNano'], '2000');

      final attributes = span['attributes'] as List;
      expect(attributes.length, 1);
      expect(attributes[0]['key'], 'test-attribute');
      expect(attributes[0]['value']['stringValue'], 'test-value');

      expect(span['droppedAttributesCount'], 0);
      expect(span['events'], isEmpty);
      expect(span['status']['code'], 2); // ERROR
      expect(span['status']['message'], 'test-error');
      expect(span['links'], isEmpty);
    });

    test('serializes a null scope version as an empty string', () {
      // The telemetry server maps `scope` to `instrumentationLibrary` and
      // rejects a null `version`.
      final spans = [
        GenkitSpanData(
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          name: 'no-version',
          startTimeUnixNano: 1,
          endTimeUnixNano: 2,
          scopeName: 'genkit-dart',
        ),
      ];

      final scope =
          (encodeResourceSpans(spans)[0]['scopeSpans'] as List)[0]['scope'];
      expect(scope['version'], '');
    });

    test('omits parentSpanId for a root (zero/absent) parent', () {
      final spans = [
        GenkitSpanData(
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          parentSpanId: '0' * 16,
          name: 'root',
          startTimeUnixNano: 1,
          endTimeUnixNano: 2,
        ),
      ];

      final span =
          (encodeResourceSpans(spans)[0]['scopeSpans'] as List)[0]['spans'][0];
      expect(span.containsKey('parentSpanId'), isFalse);
    });
  });

  group('encodeResourceLogs', () {
    test('produces OTLP JSON grouped by resource and scope', () {
      final logs = [
        GenkitLogData(
          timeUnixNano: 1500000,
          severityNumber: 9,
          severityText: 'INFO',
          body: 'hello',
          attributes: const {'loggerName': 'genkit.test'},
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          scopeName: 'genkit-dart',
          scopeVersion: '1.2.3',
          resourceAttributes: const {'service.name': 'test-service'},
        ),
      ];

      final resourceLogs = encodeResourceLogs(logs);
      expect(resourceLogs.length, 1);

      final resourceLog = resourceLogs[0];
      expect(resourceLog['resource']['attributes'][0]['key'], 'service.name');

      final scopeLogs = resourceLog['scopeLogs'] as List;
      expect(scopeLogs.length, 1);
      expect(scopeLogs[0]['scope']['name'], 'genkit-dart');
      expect(scopeLogs[0]['scope']['version'], '1.2.3');

      final records = scopeLogs[0]['logRecords'] as List;
      expect(records.length, 1);
      final record = records[0];
      expect(record['timeUnixNano'], '1500000');
      expect(record['severityNumber'], 9);
      expect(record['severityText'], 'INFO');
      expect(record['body']['stringValue'], 'hello');
      expect(record['traceId'], 'a' * 32);
      expect(record['spanId'], 'b' * 16);
      final attributes = record['attributes'] as List;
      expect(attributes[0]['key'], 'loggerName');
      expect(attributes[0]['value']['stringValue'], 'genkit.test');
    });

    test('JSON-encodes a non-scalar body into a stringValue', () {
      final logs = [
        GenkitLogData(
          timeUnixNano: 1,
          severityNumber: 9,
          severityText: 'INFO',
          body: const {'a': 1},
        ),
      ];

      final record =
          (encodeResourceLogs(logs)[0]['scopeLogs']
              as List)[0]['logRecords'][0];
      expect(record['body']['stringValue'], '{"a":1}');
    });

    test('omits empty trace/span ids', () {
      final logs = [
        GenkitLogData(
          timeUnixNano: 1,
          severityNumber: 9,
          severityText: 'INFO',
          body: 'no-correlation',
        ),
      ];

      final record =
          (encodeResourceLogs(logs)[0]['scopeLogs']
              as List)[0]['logRecords'][0];
      expect(record.containsKey('traceId'), isFalse);
      expect(record.containsKey('spanId'), isFalse);
    });
  });

  group('CollectorHttpSink', () {
    test('POSTs OTLP JSON to the configured endpoint', () async {
      final posted = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        expect(request.headers['Content-Type'], 'application/json');
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', 200);
      });

      final sink = CollectorHttpSink(
        'http://localhost:4318/api/otlp',
        client: client,
      );

      sink.export([
        GenkitSpanData(
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          name: 'exported',
          startTimeUnixNano: 1,
          endTimeUnixNano: 2,
          resourceAttributes: const {'service.name': 'genkit-dart'},
        ),
      ]);

      // The sink posts asynchronously (fire-and-forget); let the microtask/event
      // queue drain before asserting.
      await Future<void>.delayed(Duration.zero);

      expect(posted, isNotEmpty);
      final resourceSpans = posted.single['resourceSpans'] as List;
      expect(resourceSpans, hasLength(1));
    });

    test('POSTs OTLP JSON logs to the configured endpoint', () async {
      final posted = <Map<String, dynamic>>[];
      final client = MockClient((request) async {
        posted.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('', 200);
      });

      final sink = CollectorHttpSink(
        'http://localhost:4318/api/otlp',
        client: client,
      );

      sink.exportLogs([
        GenkitLogData(
          timeUnixNano: 1,
          severityNumber: 9,
          severityText: 'INFO',
          body: 'hello',
          resourceAttributes: const {'service.name': 'genkit-dart'},
        ),
      ]);

      await Future<void>.delayed(Duration.zero);

      expect(posted, isNotEmpty);
      expect(posted.single.containsKey('resourceLogs'), isTrue);
    });

    test('does not export after shutdown', () async {
      var posts = 0;
      final client = MockClient((request) async {
        posts++;
        return http.Response('', 200);
      });

      final sink = CollectorHttpSink(
        'http://localhost:4318/api/otlp',
        client: client,
      )..shutdown();

      sink.export([
        GenkitSpanData(
          traceId: 'a' * 32,
          spanId: 'b' * 16,
          name: 'exported',
          startTimeUnixNano: 1,
          endTimeUnixNano: 2,
        ),
      ]);
      sink.exportLogs([
        GenkitLogData(
          timeUnixNano: 1,
          severityNumber: 9,
          severityText: 'INFO',
          body: 'hello',
        ),
      ]);

      await Future<void>.delayed(Duration.zero);
      expect(posts, 0);
    });
  });
}
