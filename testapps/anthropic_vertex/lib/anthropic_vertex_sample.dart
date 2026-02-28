import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

const _defaultLocation = 'global';
const _defaultModel = 'claude-sonnet-4-5';
const _defaultPrompt = 'Reply with: Vertex Claude is online.';

void _printUsage() {
  print('Anthropic Vertex AI sample app');
  print('');
  print('Required environment variable (one of):');
  print('  VERTEX_PROJECT_ID=<your-gcp-project-id>');
  print('  GOOGLE_CLOUD_PROJECT=<your-gcp-project-id>');
  print('  GCLOUD_PROJECT=<your-gcp-project-id>');
  print('');
  print('Optional environment variables:');
  print('  VERTEX_LOCATION=global');
  print('  VERTEX_ANTHROPIC_MODEL=claude-sonnet-4-5');
  print('  VERTEX_PROMPT="Prompt if no CLI args are provided"');
  print('  VERTEX_AUTH_MODE=adc|service-account (default: adc)');
  print('  VERTEX_SERVICE_ACCOUNT_PATH=/path/to/service-account.json');
  print('');
  print('Examples:');
  print('  dart run anthropic_vertex_sample');
  print('  dart run bin/anthropic_vertex_sample.dart');
  print(
    '  dart run bin/anthropic_vertex_sample.dart "Explain transformers in 3 bullets."',
  );
}

String? _resolveProjectId() {
  return Platform.environment['VERTEX_PROJECT_ID'] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      Platform.environment['GCLOUD_PROJECT'];
}

AnthropicVertexConfig _buildVertexConfig({
  required String projectId,
  required String location,
}) {
  final authMode = (Platform.environment['VERTEX_AUTH_MODE'] ?? 'adc')
      .toLowerCase();

  switch (authMode) {
    case 'adc':
      return AnthropicVertexConfig.adc(
        projectId: projectId,
        location: location,
      );
    case 'service-account':
      final keyPath =
          Platform.environment['VERTEX_SERVICE_ACCOUNT_PATH'] ??
          Platform.environment['GOOGLE_APPLICATION_CREDENTIALS'];
      if (keyPath == null || keyPath.trim().isEmpty) {
        throw ArgumentError(
          'VERTEX_AUTH_MODE=service-account requires '
          'VERTEX_SERVICE_ACCOUNT_PATH or GOOGLE_APPLICATION_CREDENTIALS.',
        );
      }

      final credentialsJson =
          jsonDecode(File(keyPath).readAsStringSync()) as Object;
      return AnthropicVertexConfig.serviceAccount(
        projectId: projectId,
        location: location,
        credentialsJson: credentialsJson,
      );
    default:
      throw ArgumentError(
        'Unsupported VERTEX_AUTH_MODE "$authMode". Use adc or service-account.',
      );
  }
}

/// Runs the Anthropic Vertex sample application.
///
/// Configuration is read from environment variables documented in the sample
/// README. Command arguments are treated as the prompt text.
Future<void> run(List<String> args) async {
  final projectId = _resolveProjectId();
  if (projectId == null || projectId.trim().isEmpty) {
    stderr.writeln(
      'Set VERTEX_PROJECT_ID or GOOGLE_CLOUD_PROJECT to your GCP project ID.',
    );
    _printUsage();
    exit(1);
  }

  final location = Platform.environment['VERTEX_LOCATION'] ?? _defaultLocation;
  final model = Platform.environment['VERTEX_ANTHROPIC_MODEL'] ?? _defaultModel;
  final prompt = args.isNotEmpty
      ? args.join(' ')
      : (Platform.environment['VERTEX_PROMPT'] ?? _defaultPrompt);

  try {
    final vertexConfig = _buildVertexConfig(
      projectId: projectId,
      location: location,
    );
    final ai = Genkit(
      plugins: [anthropic(vertex: vertexConfig)],
      isDevEnv: false,
    );

    final response = await ai.generate(
      model: anthropic.model(model),
      prompt: prompt,
    );

    print('Project: $projectId');
    print('Location: $location');
    print('Model: $model');
    print('Prompt: $prompt');
    print('');
    print('Response:');
    print(response.text);
  } catch (e) {
    if (e is GenkitException) {
      if (e.status == StatusCodes.RESOURCE_EXHAUSTED) {
        stderr.writeln(
          'Hint: Vertex quota is exhausted. Check partner-model quotas for Claude in this project/location.',
        );
      } else if (e.status == StatusCodes.NOT_FOUND) {
        stderr.writeln(
          'Hint: Model name or access might be invalid. Ensure the Claude model is enabled for this project in Model Garden.',
        );
      }
      stderr.writeln(
        'Vertex Claude sample failed [${e.status.name}]: ${e.message}',
      );
      exitCode = 1;
      return;
    }
    stderr.writeln('Vertex Claude sample failed: $e');
    exitCode = 1;
  }
}
