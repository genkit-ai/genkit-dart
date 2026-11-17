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
import 'package:genkit/src/o11y/instrumentation.dart' show resetInstrumentation;
import 'package:genkit/telemetry.dart';
import 'package:genkit_google_genai/common.dart'
    show CreateInteractionRequest, resetDroppedConfigFieldWarnings;
import 'package:genkit_vertex_auth/genkit_vertex_auth.dart'
    show googleApiClientHeaderValue;
import 'package:genkit_vertexai/src/vertex_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:test/test.dart';

import 'test_http_client.dart';

void main() {
  group('Vertex AI Plugin', () {
    test('uses correct endpoint for regional location', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us-central1',
        authClient: mockClient,
      );

      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      await model.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://us-central1-aiplatform.googleapis.com/v1beta1/projects/my-project/locations/us-central1/publishers/google/models/gemini-2.5-pro:generateContent',
      );
    });

    test('uses correct endpoint for global location', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        authClient: mockClient,
      );

      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      final req = ModelRequest(
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'hello')],
          ),
        ],
      );

      await model.run(req);

      expect(mockClient.lastUrl, isNotNull);
      expect(
        mockClient.lastUrl.toString(),
        'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/publishers/google/models/gemini-2.5-pro:generateContent',
      );
    });

    test('does not send store on generateContent (the platform has no such '
        'field)', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        authClient: mockClient,
      );
      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;

      for (final store in [true, false]) {
        await model.run(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
            config: {'store': store},
          ),
        );
        final body = jsonDecode(mockClient.lastBody!) as Map;
        expect(body, isNot(contains('store')), reason: 'store: $store');
      }
    });

    test('does not warn about its own options', () async {
      final warnings = <String>[];
      final subscription = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(subscription.cancel);
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        authClient: MockHttpClient(),
      );
      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      await model.run(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
          config: {
            'labels': {'team': 'genkit'},
            'payGo': 'flex',
          },
        ),
      );
      expect(warnings, isEmpty);
    });
  });

  group('API hosts and paths', () {
    test('vertexBaseUrl: global, multi-regional and regional hosts', () {
      expect(vertexBaseUrl('global'), 'https://aiplatform.googleapis.com/');
      // Multi-regions have their own host (used to be us-aiplatform...).
      expect(vertexBaseUrl('us'), 'https://aiplatform.us.rep.googleapis.com/');
      expect(vertexBaseUrl('eu'), 'https://aiplatform.eu.rep.googleapis.com/');
      expect(
        vertexBaseUrl('us-central1'),
        'https://us-central1-aiplatform.googleapis.com/',
      );
    });

    test('generateContent on a multi-region uses the rep host', () async {
      final mockClient = MockHttpClient();
      final plugin = VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'us',
        authClient: mockClient,
      );
      final model = plugin.resolve(.model, 'gemini-2.5-pro') as Action;
      await model.run(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        ),
      );
      expect(
        mockClient.lastUrl.toString(),
        'https://aiplatform.us.rep.googleapis.com/v1beta1/projects/my-project/locations/us/publishers/google/models/gemini-2.5-pro:generateContent',
      );
    });

    for (final (location, host) in [
      ('global', 'aiplatform.googleapis.com'),
      ('us', 'aiplatform.us.rep.googleapis.com'),
    ]) {
      test('Interactions path is under the project and location '
          '($location)', () async {
        final mockClient = MockHttpClient();
        final service = await VertexAiPluginImpl(
          projectId: 'my-project',
          location: location,
          authClient: mockClient,
        ).getApiClient();
        await service.createInteraction(
          CreateInteractionRequest(model: 'gemini-3.8-flash', input: 'Hi'),
        );
        expect(
          mockClient.lastUrl.toString(),
          'https://$host/v1beta1/projects/my-project/locations/$location/interactions',
        );
      });
    }
  });

  group('apiVersion (JS vertexAI calculateRequestOptions)', () {
    Future<Uri> urlFor(
      String modelName, {
      String? pluginVersion,
      Map<String, dynamic>? config,
    }) async {
      final mockClient = MockHttpClient();
      await VertexAiPluginImpl(
            projectId: 'my-project',
            location: 'global',
            apiVersion: pluginVersion,
            authClient: mockClient,
          )
          .resolve(.model, modelName)!
          .run(
            ModelRequest(
              messages: [
                Message(
                  role: Role.user,
                  content: [TextPart(text: 'hello')],
                ),
              ],
              config: config,
            ),
          );
      return mockClient.lastUrl!;
    }

    const base = 'https://aiplatform.googleapis.com';
    const parent = 'projects/my-project/locations/global';

    test('the plugin apiVersion replaces v1beta1 on both APIs', () async {
      expect(
        '${await urlFor('gemini-2.5-pro', pluginVersion: 'v1')}',
        '$base/v1/$parent/publishers/google/models/gemini-2.5-pro:generateContent',
      );
      expect(
        '${await urlFor('gemini-3.8-flash', pluginVersion: 'v1')}',
        '$base/v1/$parent/interactions',
      );
    });

    test("a request's apiVersion wins over the plugin's", () async {
      expect(
        '${await urlFor('gemini-3.8-flash', pluginVersion: 'v1beta1', config: {'apiVersion': 'v1'})}',
        '$base/v1/$parent/interactions',
      );
    });

    test('model listing uses the plugin apiVersion', () async {
      final mockClient = MockHttpClient();
      await VertexAiPluginImpl(
        projectId: 'my-project',
        location: 'global',
        apiVersion: 'v1',
        authClient: mockClient,
      ).list();
      expect(
        mockClient.requestUrls.map((u) => u.path),
        contains('/v1/publishers/google/models'),
      );
    });

    test("a request's baseUrl is dropped with a warning", () async {
      resetDroppedConfigFieldWarnings();
      final warnings = <String>[];
      final subscription = Logger.root.onRecord
          .where((r) => r.level == Level.WARNING)
          .listen((r) => warnings.add(r.message));
      addTearDown(subscription.cancel);
      final url = await urlFor(
        'gemini-3.8-flash',
        config: {'baseUrl': 'https://proxy.test'},
      );
      expect(url.host, 'aiplatform.googleapis.com');
      expect(warnings.single, contains('baseUrl'));
    });
  });

  test('vertexAI(experimentalDebugTraces: true) traces a model call, token '
      'hidden', () async {
    final spans = <SpanMetadata>[];
    configureInstrumentation(_SpanRecorder(spans));
    addTearDown(resetInstrumentation);
    await VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'global',
          experimentalDebugTraces: true,
          authClient: MockHttpClient(),
        )
        .resolve(.model, 'gemini-3.8-flash')!
        .run(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
          ),
        );
    final input = (spans.single.input! as Map).cast<String, Object?>();
    expect(
      input['apiEndpoint'],
      'https://aiplatform.googleapis.com/v1beta1/projects/my-project/locations/global/interactions',
    );
    expect(
      (input['headers']! as Map)['Authorization'],
      startsWith('<REDACTED> ('),
    );
  });

  group('request headers', () {
    // The mock serves the token endpoints (metadata server or OAuth), so
    // the token is whatever it returns; only its shape is checked here.
    final bearer = matches(RegExp(r'^Bearer \S+$'));

    for (final (label, modelName) in [
      ('generateContent', 'gemini-2.5-pro'),
      ('Interactions', 'gemini-3.8-flash'),
    ]) {
      test('$label: bearer token and api client, no API key', () async {
        final mockClient = MockHttpClient();
        final model = VertexAiPluginImpl(
          projectId: 'my-project',
          location: 'global',
          authClient: mockClient,
        ).resolve(.model, modelName)!;
        await model.run(
          ModelRequest(
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'hello')],
              ),
            ],
            config: {'payGo': 'flex'},
          ),
        );
        final headers = mockClient.lastHeaders!;
        expect(headers['Authorization'], bearer);
        expect(headers['X-Goog-Api-Client'], googleApiClientHeaderValue());
        expect(headers['X-Vertex-AI-LLM-Shared-Request-Type'], 'flex');
        expect(headers, isNot(contains('x-goog-api-key')));
      });
    }
  });

  group('injected client lifecycle', () {
    VertexAiPluginImpl pluginWith(MockHttpClient client) => VertexAiPluginImpl(
      projectId: 'my-project',
      location: 'us-central1',
      authClient: client,
    );

    test('list does not close the injected client', () async {
      final mockClient = MockHttpClient();

      await pluginWith(mockClient).list();

      expect(mockClient.closed, isFalse);
    });

    test('generate does not close the injected client', () async {
      final mockClient = MockHttpClient();
      final model = pluginWith(mockClient).resolve(.model, 'gemini-2.5-pro')!;

      await model.run(
        ModelRequest(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hello')],
            ),
          ],
        ),
      );

      expect(mockClient.closed, isFalse);
    });

    test(
      'generate cancelled mid-request throws once the request returns',
      () async {
        final controller = CancellationController();
        final mockClient = _CancelOnGenerateClient(controller);
        final model = pluginWith(mockClient).resolve(.model, 'gemini-2.5-pro')!;

        await expectLater(
          model.run(
            ModelRequest(
              messages: [
                Message(
                  role: Role.user,
                  content: [TextPart(text: 'hello')],
                ),
              ],
            ),
            cancel: controller.token,
          ),
          throwsA(isA<CancelledException>()),
        );
        expect(mockClient.closed, isFalse);
      },
    );

    for (final modelName in ['gemini-2.5-pro', 'gemini-3.8-flash']) {
      test('cancelling aborts the request in flight ($modelName)', () async {
        final mockClient = _HangOnModelCallClient();
        final controller = CancellationController();
        final run = pluginWith(mockClient)
            .resolve(.model, modelName)!
            .run(
              ModelRequest(
                messages: [
                  Message(
                    role: Role.user,
                    content: [TextPart(text: 'hello')],
                  ),
                ],
              ),
              cancel: controller.token,
            );
        await mockClient.modelCallReceived;
        controller.cancel();

        await expectLater(run, throwsA(isA<CancelledException>()));
        expect(mockClient.closed, isFalse);
      });
    }

    test('embedder does not close the injected client', () async {
      final mockClient = MockHttpClient();
      final embedder =
          pluginWith(mockClient).resolve(.embedder, 'text-embedding-005')!
              as Action<EmbedRequest, EmbedResponse, void, void>;

      await embedder.run(
        EmbedRequest(
          input: [
            DocumentData(content: [TextPart(text: 'hello')]),
          ],
        ),
      );

      expect(mockClient.closed, isFalse);
    });
  });
}

/// Records the metadata of every `httpRequest` span.
class _SpanRecorder implements Instrumentation {
  _SpanRecorder(this.spans);

  final List<SpanMetadata> spans;

  @override
  Future<O> runInNewSpan<O>(
    SpanMetadata metadata,
    Future<O> Function([SpanContext? span]) next,
  ) {
    if (metadata.name == 'httpRequest') spans.add(metadata);
    return next();
  }
}

/// Cancels [controller] while serving a generateContent request, standing in
/// for a user cancelling while the request is in flight.
class _CancelOnGenerateClient extends MockHttpClient {
  _CancelOnGenerateClient(this.controller);

  final CancellationController controller;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    if (request.url.path.endsWith(':generateContent')) controller.cancel();
    return super.send(request);
  }
}

/// Serves the token requests, but holds a model call (generateContent or
/// Interactions) until its abort trigger fires, then fails it the way
/// `http`'s own clients do.
class _HangOnModelCallClient extends MockHttpClient {
  final Completer<void> _received = Completer<void>();

  /// Completes once the model call has arrived.
  Future<void> get modelCallReceived => _received.future;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final path = request.url.path;
    if (!path.endsWith(':generateContent') && !path.endsWith('/interactions')) {
      return super.send(request);
    }
    if (!_received.isCompleted) _received.complete();
    if (request case http.Abortable(:final abortTrigger?)) {
      await abortTrigger;
      throw http.RequestAbortedException(request.url);
    }
    throw StateError('request has no abort trigger: ${request.url}');
  }
}
