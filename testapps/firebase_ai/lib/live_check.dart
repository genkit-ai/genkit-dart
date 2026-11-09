// Live check for #612: does each backend accept responseJsonSchema?
//
// Copy to testapps/firebase_ai/lib/live_check.dart and run with
// `flutter run -t lib/live_check.dart -d macos`.

import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_firebase_ai/genkit_firebase_ai.dart';
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import 'firebase_options.dart';

/// Uses what the old converter dropped: enum, $ref/$defs, an optional field
/// and additionalProperties.
final _pick = SchemanticType.from<Map<String, dynamic>>(
  jsonSchema: {
    r'$schema': 'https://json-schema.org/draft/2020-12/schema',
    r'$ref': r'#/$defs/Pick',
    r'$defs': {
      'Pick': {
        'type': 'object',
        'properties': {
          'colour': {
            'type': 'string',
            'enum': ['red', 'green', 'blue'],
          },
          'reason': {'type': 'string'},
          'count': {'type': 'integer', 'minimum': 1, 'maximum': 3},
        },
        'required': ['colour'],
        'additionalProperties': false,
      },
    },
  },
  parse: (json) => json as Map<String, dynamic>,
);

/// Prints the generationConfig of each request and the status of each reply.
class _LoggingClient extends http.BaseClient {
  final _inner = http.Client();

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request is http.Request) {
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      print('  -> ${request.url.path}');
      print('     generationConfig: ${jsonEncode(body['generationConfig'])}');
    }
    final response = await _inner.send(request);
    print('  <- HTTP ${response.statusCode}');
    return response;
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  final providers = {
    'googleAI': const FirebaseAiProvider.googleAI(),
    'agentPlatform': const FirebaseAiProvider.agentPlatform(),
  };
  var failures = 0;

  for (final MapEntry(key: name, value: provider) in providers.entries) {
    final ai = Genkit(
      isDevEnv: false,
      plugins: [firebaseAI(provider: provider, httpClient: _LoggingClient())],
    );
    for (final streaming in [false, true]) {
      print('\n== $name, streaming: $streaming');
      final response = await ai.generate(
        model: firebaseAI.gemini('gemini-2.5-flash'),
        prompt: 'Pick a colour for a fire truck.',
        outputSchema: _pick,
        onChunk: streaming ? (_) {} : null,
      );
      if (response.finishReason == FinishReason.failed) {
        failures++;
        print('  FAILED: ${response.error?.status} ${response.error?.message}');
      } else {
        print('  output: ${jsonEncode(response.output)}');
      }
    }
    await ai.shutdown();
  }

  print(failures == 0 ? '\nALL PASSED' : '\n$failures FAILED');
}
