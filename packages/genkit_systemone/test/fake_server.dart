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

/// A fake System One endpoint, the counterpart of Genkit Go's
/// `systemonetest.Server`.
library;

import 'dart:convert';

import 'package:genkit_systemone/genkit_systemone.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Answers whatever questions it is sent, so a test can check the whole path
/// from a Dart type to the wire and back.
///
/// A choice is answered with its first option by name, a score with 1.3, a
/// noul with 0.93, from the model jev-1.13.0 with 312 input tokens and 48
/// output tokens.
final class FakeServer {
  FakeServer({this.models = '', this.usage, this.wrap, this.reply});

  /// The reply to a GET, the model listing. When empty, a GET fails with a
  /// server error.
  String models;

  /// When set, the usage of every answer, in place of 312 input tokens and 48
  /// output tokens.
  Map<String, Object?>? usage;

  /// When set, wraps every answer in a server's envelope.
  Object? Function(Map<String, Object?> reply)? wrap;

  /// When set, answers a POST in place of the fake's own answers.
  Future<http.Response> Function(http.Request request)? reply;

  final List<http.Request> requests = [];
  final List<Map<String, Object?>> bodies = [];
  final List<String> listings = [];

  late final http.Client client = MockClient(_handle);

  /// The last request posted and its JSON body.
  (http.Request, Map<String, Object?>) get last {
    if (requests.isEmpty) throw StateError('the endpoint was never called');
    return (requests.last, bodies.last);
  }

  /// How many requests were posted.
  int get calls => requests.length;

  Future<http.Response> _handle(http.Request req) async {
    if (req.method == 'GET') {
      listings.add(
        req.url.hasQuery ? '${req.url.path}?${req.url.query}' : req.url.path,
      );
      if (models.isEmpty) return http.Response('', 500);
      return http.Response(models, 200);
    }
    final body = (jsonDecode(req.body) as Map).cast<String, Object?>();
    requests.add(req);
    bodies.add(body);
    if (reply case final custom?) return custom(req);

    // A server that wraps the native body, as Workers AI does for a
    // partner's model, carries the questions under input.
    final native = body['input'] is Map
        ? (body['input'] as Map).cast<String, Object?>()
        : body;
    final questions = (native['questions'] as Map? ?? const {})
        .cast<String, Object?>();
    final answers = <String, Object?>{};
    for (final MapEntry(key: id, value: raw) in questions.entries) {
      final q = (raw as Map).cast<String, Object?>();
      switch (q['type']) {
        case 'choice':
          final keys =
              (q['criteria'] as Map? ?? const {}).keys.cast<String>().toList()
                ..sort();
          if (keys.isEmpty) {
            return http.Response(
              '{"error":{"message":"a choice needs criteria"}}',
              400,
            );
          }
          answers[id] = {
            'type': 'choice',
            'choice': keys.first,
            'probabilities': {
              for (final (i, k) in keys.indexed)
                k: i == 0 ? 1 - 0.1 * (keys.length - 1) : 0.1,
            },
            'confidence': 0.6,
          };
        case 'score':
          final levels = q['criteria'] as List? ?? const [];
          answers[id] = {
            'type': 'score',
            'score': 1.3,
            'legend': {for (final (i, l) in levels.indexed) '$i': l},
            'probabilities': {'0': 0.0, '1': 0.7, '2': 0.3},
            'confidence': 0.54,
          };
        case 'noul':
          answers[id] = {'type': 'noul', 'noul': 0.93};
      }
    }
    final answer = <String, Object?>{
      'model': 'jev-1.13.0',
      'answers': answers,
      'usage': usage ?? {'input_tokens': 312, 'output_tokens': 48},
    };
    return http.Response(
      jsonEncode(wrap == null ? answer : wrap!(answer)),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
}

/// Builds a plugin over a fixed environment, so a test does not depend on
/// the developer's shell.
T withEnv<T>(Map<String, String> vars, T Function() build) {
  final saved = SystemOne.environment;
  SystemOne.environment = (name) => vars[name];
  try {
    return build();
  } finally {
    SystemOne.environment = saved;
  }
}
