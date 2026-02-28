import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

Future<String> Function() createAdcTokenProvider({
  required List<String> scopes,
  http.Client? baseClient,
}) {
  return () async {
    throw GenkitException(
      'Anthropic Vertex ADC auth is only supported on Dart IO platforms.',
      status: StatusCodes.UNIMPLEMENTED,
    );
  };
}

Future<String> Function() createServiceAccountTokenProvider({
  required Object credentialsJson,
  required List<String> scopes,
  String? impersonatedUser,
  http.Client? baseClient,
}) {
  return () async {
    throw GenkitException(
      'Anthropic Vertex service account auth is only supported on Dart IO platforms.',
      status: StatusCodes.UNIMPLEMENTED,
    );
  };
}
