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

import 'package:genkit/src/o11y/telemetry/exporter_impl.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:opentelemetry/api.dart' as api;
import 'package:opentelemetry/sdk.dart' as sdk;
import 'package:test/test.dart';

void main() {
  group('CollectorHttpExporter', () {
    test('should send spans in OTLP JSON format', () async {
      http.Client client = MockClient((request) async {
        final body = jsonDecode(request.body);
        final resourceSpans = body['resourceSpans'];
        expect(resourceSpans, isA<List>());
        expect(resourceSpans.length, 1);

        final resourceSpan = resourceSpans[0];
        expect(
          resourceSpan['resource']['attributes'][0]['key'],
          'service.name',
        );
        expect(
          resourceSpan['resource']['attributes'][0]['value']['stringValue'],
          'test-service',
        );

        final scopeSpans = resourceSpan['scopeSpans'];
        expect(scopeSpans.length, 1);

        final scopeSpan = scopeSpans[0];
        expect(scopeSpan['scope']['name'], 'test-tracer');
        expect(scopeSpan['scope']['version'], '1.2.3');

        final spans = scopeSpan['spans'];
        expect(spans.length, 1);

        final span = spans[0];
        expect(span['traceId'], isA<String>());
        expect(span['spanId'], isA<String>());
        expect(span['parentSpanId'], isA<String>());
        expect(span['name'], 'test-span');
        expect(span['kind'], 1); // INTERNAL
        expect(span['startTimeUnixNano'], isA<String>());
        expect(span['endTimeUnixNano'], isA<String>());
        final attributes = span['attributes'];
        expect(attributes, isA<List>());
        expect(attributes.length, 1);
        expect(attributes[0]['key'], 'test-attribute');
        expect(attributes[0]['value']['stringValue'], 'test-value');
        expect(span['droppedAttributesCount'], 0);
        expect(span['events'], isEmpty);
        expect(span['droppedEventsCount'], 0);
        expect(span['status']['code'], 2); // ERROR
        expect(span['status']['message'], 'test-error');
        expect(span['links'], isEmpty);
        expect(span['droppedLinksCount'], 0);

        return http.Response('', 200);
      });

      final exporter = CollectorHttpExporter(
        'http://localhost:4318/v1/traces',
        client: client,
      );

      final processor = sdk.SimpleSpanProcessor(exporter);
      final provider = sdk.TracerProviderBase(
        processors: [processor],
        resource: sdk.Resource([
          api.Attribute.fromString('service.name', 'test-service'),
        ]),
      );
      final tracer = provider.getTracer('test-tracer', version: '1.2.3');

      final parentSpan = tracer.startSpan('parent-span');

      final context = api.contextWithSpan(api.Context.current, parentSpan);

      final span = tracer.startSpan('test-span', context: context);
      span.setAttribute(
        api.Attribute.fromString('test-attribute', 'test-value'),
      );
      span.setStatus(api.StatusCode.error, 'test-error');
      span.end();

      processor.forceFlush();
    });
  });
}
