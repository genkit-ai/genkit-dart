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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_openai/genkit_openai.dart';

const _defaultLocation = 'global';
const _defaultEndpointId = 'openapi';
const _defaultModel = 'zai-org/glm-5-maas';
const _defaultPrompt = 'Reply with exactly: GLM-5 is online.';

void _printUsage() {
  print('OpenAI Vertex AI OpenAI-compatible sample app');
  print('');
  print('Required environment variable (one of):');
  print('  VERTEX_PROJECT_ID=<your-gcp-project-id>');
  print('  GOOGLE_CLOUD_PROJECT=<your-gcp-project-id>');
  print('  GCLOUD_PROJECT=<your-gcp-project-id>');
  print('');
  print('Optional environment variables:');
  print('  VERTEX_LOCATION=global');
  print('  VERTEX_ENDPOINT_ID=openapi');
  print('  VERTEX_OPENAI_MODEL=zai-org/glm-5-maas');
  print('  VERTEX_PROMPT="Prompt if no CLI args are provided"');
  print('  VERTEX_AUTH_MODE=adc|service-account (default: adc)');
  print('  VERTEX_SERVICE_ACCOUNT_PATH=/path/to/service-account.json');
  print('');
  print('Examples:');
  print('  dart run openai_vertex_sample');
  print('  dart run bin/openai_vertex_sample.dart');
  print(
    '  dart run openai_vertex_sample "Summarize transformer attention in 3 bullets."',
  );
}

String? _resolveProjectId() {
  final projectId =
      Platform.environment['VERTEX_PROJECT_ID'] ??
      Platform.environment['GOOGLE_CLOUD_PROJECT'] ??
      Platform.environment['GCLOUD_PROJECT'];
  if (projectId == null || projectId.trim().isEmpty) {
    return null;
  }
  return projectId.trim();
}

OpenAIVertexConfig _buildVertexConfig({
  required String projectId,
  required String location,
  required String endpointId,
}) {
  final authMode = (Platform.environment['VERTEX_AUTH_MODE'] ?? 'adc')
      .toLowerCase();

  switch (authMode) {
    case 'adc':
      return OpenAIVertexConfig.adc(
        projectId: projectId,
        location: location,
        endpointId: endpointId,
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
      return OpenAIVertexConfig.serviceAccount(
        projectId: projectId,
        location: location,
        endpointId: endpointId,
        credentialsJson: credentialsJson,
      );
    default:
      throw ArgumentError(
        'Unsupported VERTEX_AUTH_MODE "$authMode". '
        'Use adc or service-account.',
      );
  }
}

/// Runs the OpenAI Vertex sample application.
Future<void> run(List<String> args) async {
  final projectId = _resolveProjectId();
  if (projectId == null) {
    stderr.writeln(
      'Set VERTEX_PROJECT_ID or GOOGLE_CLOUD_PROJECT to your GCP project ID.',
    );
    _printUsage();
    exitCode = 1;
    return;
  }

  final location = Platform.environment['VERTEX_LOCATION'] ?? _defaultLocation;
  final endpointId =
      Platform.environment['VERTEX_ENDPOINT_ID'] ?? _defaultEndpointId;
  final model = Platform.environment['VERTEX_OPENAI_MODEL'] ?? _defaultModel;
  final prompt = args.isNotEmpty
      ? args.join(' ')
      : (Platform.environment['VERTEX_PROMPT'] ?? _defaultPrompt);

  try {
    final vertexConfig = _buildVertexConfig(
      projectId: projectId,
      location: location,
      endpointId: endpointId,
    );
    final ai = Genkit(plugins: [openAI(vertex: vertexConfig)], isDevEnv: false);

    final response = await ai.generate(
      model: openAI.model(model),
      prompt: prompt,
    );

    print('Project: $projectId');
    print('Location: $location');
    print('Endpoint ID: $endpointId');
    print('Model: $model');
    print('Prompt: $prompt');
    print('');
    print('Response:');
    print(response.text);
  } catch (e) {
    if (e is GenkitException) {
      if (e.status == StatusCodes.NOT_FOUND) {
        stderr.writeln(
          'Hint: model might not be available in this project/location yet.',
        );
      } else if (e.status == StatusCodes.INVALID_ARGUMENT) {
        stderr.writeln(
          'Hint: for OpenAPI endpoint, model should use <publisher>/<model> format.',
        );
      } else if (e.status == StatusCodes.PERMISSION_DENIED) {
        stderr.writeln(
          'Hint: principal may not have Vertex AI permissions in this project.',
        );
      }
      stderr.writeln(
        'OpenAI Vertex sample failed [${e.status.name}]: ${e.message}',
      );
      exitCode = 1;
      return;
    }
    stderr.writeln('OpenAI Vertex sample failed: $e');
    exitCode = 1;
  }
}
