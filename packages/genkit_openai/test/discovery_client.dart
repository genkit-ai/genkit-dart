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

import 'dart:convert';

import 'package:genkit/genkit.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Serves a `/models` list so discovery has something to find.
///
/// A transport-level fake rather than `FakeOpenAIServer`, because it is the
/// only way to exercise the default OpenAI host: the curated catalog applies
/// when `baseUrl` is unset, and pointing the plugin at a real local server
/// necessarily sets one.
MockClient discoveryClient(List<String> requests, {List<String>? ids}) {
  return MockClient((request) async {
    requests.add('${request.method} ${request.url}');
    if (request.url.path.endsWith('/models')) {
      return http.Response(
        jsonEncode({
          'object': 'list',
          'data': [
            for (final id in ids ?? const ['gpt-5-preview'])
              {'id': id, 'object': 'model', 'created': 0, 'owned_by': 'openai'},
          ],
        }),
        200,
        headers: {'content-type': 'application/json'},
      );
    }
    return http.Response('not found', 404);
  });
}

/// The model names in a listing.
///
/// Filtered by action type: a listing also carries embedders, and a test
/// asserting on an exact set of models should not have to spell them out.
Set<String> modelNames(List<ActionMetadata> metadata) =>
    _namesOf(metadata, ActionType.model);

/// The embedder names in a listing.
Set<String> embedderNames(List<ActionMetadata> metadata) =>
    _namesOf(metadata, ActionType.embedder);

Set<String> _namesOf(List<ActionMetadata> metadata, ActionType actionType) =>
    metadata
        .where((m) => m.actionType == actionType)
        .map((m) => m.name)
        .toSet();
