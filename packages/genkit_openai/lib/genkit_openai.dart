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

import 'package:genkit/plugin.dart';
import 'package:genkit_vertex_auth/genkit_vertex_auth.dart' as vertex_auth;
import 'package:http/http.dart' as http;
import 'package:schemantic/schemantic.dart';

import 'src/openai_plugin.dart';

export 'src/converters.dart' show GenkitConverter;
export 'src/models.dart'
    show defaultModelInfo, oSeriesModelInfo, supportsTools, supportsVision;

part 'genkit_openai.g.dart';

@Schematic()
abstract class $OpenAIOptions {
  /// Model version override (e.g., 'gpt-4o-2024-08-06')
  String? get version;

  /// Sampling temperature (0.0 - 2.0)
  @DoubleField(minimum: 0.0, maximum: 2.0)
  double? get temperature;

  /// Nucleus sampling (0.0 - 1.0)
  @DoubleField(minimum: 0.0, maximum: 1.0)
  double? get topP;

  /// Maximum tokens to generate
  int? get maxTokens;

  /// Stop sequences
  List<String>? get stop;

  /// Presence penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get presencePenalty;

  /// Frequency penalty (-2.0 - 2.0)
  @DoubleField(minimum: -2.0, maximum: 2.0)
  double? get frequencyPenalty;

  /// Seed for deterministic sampling
  int? get seed;

  /// User identifier for abuse detection
  String? get user;

  /// JSON mode
  bool? get jsonMode;

  /// Visual detail level for images ('auto', 'low', 'high')
  @StringField(enumValues: ['auto', 'low', 'high'])
  String? get visualDetailLevel;
}

/// Custom model definition for registering models from compatible providers
class CustomModelDefinition {
  final String name;
  final ModelInfo? info;

  const CustomModelDefinition({required this.name, this.info});
}

/// Signature used to provide an OAuth2 access token for Vertex AI requests.
///
/// Return the raw bearer token value without the `Bearer ` prefix.
typedef AccessTokenProvider = vertex_auth.AccessTokenProvider;

/// Configuration for using the Vertex AI OpenAI-compatible endpoint.
final class OpenAIVertexConfig {
  /// Optional Google Cloud project ID where Vertex AI is enabled.
  ///
  /// When omitted, resolution falls back to:
  /// 1. `project_id` from service account credentials (if configured via
  ///    [OpenAIVertexConfig.serviceAccount])
  /// 2. environment variables (`GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`)
  final String? projectId;

  final String? _projectIdFromCredentials;

  /// Vertex region, for example `global` or `us-central1`.
  ///
  /// Must contain only letters, numbers, and hyphens.
  final String location;

  /// Vertex endpoint ID for OpenAI-compatible requests.
  ///
  /// Defaults to `openapi` for Gemini models through the OpenAI-compatible API.
  final String endpointId;

  /// Optional static OAuth2 access token.
  final String? accessToken;

  /// Optional provider used to fetch/refresh OAuth2 access tokens.
  final AccessTokenProvider? accessTokenProvider;

  /// Creates a Vertex OpenAI configuration.
  ///
  /// Provide exactly one of [accessToken] or [accessTokenProvider].
  const OpenAIVertexConfig({
    this.projectId,
    this.location = 'global',
    this.endpointId = 'openapi',
    this.accessToken,
    this.accessTokenProvider,
  }) : _projectIdFromCredentials = null;

  const OpenAIVertexConfig._({
    required this.projectId,
    required String? projectIdFromCredentials,
    required this.location,
    required this.endpointId,
    required this.accessToken,
    required this.accessTokenProvider,
  }) : _projectIdFromCredentials = projectIdFromCredentials;

  /// Creates Vertex config backed by Application Default Credentials (ADC).
  factory OpenAIVertexConfig.adc({
    String? projectId,
    String location = 'global',
    String endpointId = 'openapi',
    List<String> scopes = const [vertex_auth.cloudPlatformScope],
    http.Client? baseClient,
  }) {
    return OpenAIVertexConfig._(
      projectId: projectId,
      projectIdFromCredentials: null,
      location: location,
      endpointId: endpointId,
      accessTokenProvider: vertex_auth.createAdcAccessTokenProvider(
        scopes: scopes,
        baseClient: baseClient,
      ),
      accessToken: null,
    );
  }

  /// Creates Vertex config backed by service account credentials.
  factory OpenAIVertexConfig.serviceAccount({
    String? projectId,
    required Object credentialsJson,
    String location = 'global',
    String endpointId = 'openapi',
    List<String> scopes = const [vertex_auth.cloudPlatformScope],
    String? impersonatedUser,
    http.Client? baseClient,
  }) {
    return OpenAIVertexConfig._(
      projectId: projectId,
      projectIdFromCredentials: vertex_auth
          .extractProjectIdFromServiceAccountJson(credentialsJson),
      location: location,
      endpointId: endpointId,
      accessTokenProvider: vertex_auth.createServiceAccountAccessTokenProvider(
        credentialsJson: credentialsJson,
        scopes: scopes,
        impersonatedUser: impersonatedUser,
        baseClient: baseClient,
      ),
      accessToken: null,
    );
  }

  /// Validates required Vertex configuration fields.
  void validate() {
    if (projectId != null && projectId!.trim().isEmpty) {
      throw GenkitException(
        'Vertex OpenAI requires a non-empty projectId.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    if (location.trim().isEmpty) {
      throw GenkitException(
        'Vertex OpenAI requires a non-empty location.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final locationPattern = RegExp(r'^[A-Za-z0-9-]+$');
    if (!locationPattern.hasMatch(location.trim())) {
      throw GenkitException(
        'Vertex OpenAI location may only contain letters, numbers, and hyphens.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    if (endpointId.trim().isEmpty) {
      throw GenkitException(
        'Vertex OpenAI requires a non-empty endpointId.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    final endpointPattern = RegExp(r'^[A-Za-z0-9_-]+$');
    if (!endpointPattern.hasMatch(endpointId.trim())) {
      throw GenkitException(
        'Vertex OpenAI endpointId may only contain letters, numbers, underscores, and hyphens.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }

    if (accessToken != null && accessTokenProvider != null) {
      throw GenkitException(
        'Provide either accessToken or accessTokenProvider, not both.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
  }

  /// Resolves and returns a usable Google Cloud project ID.
  String resolveProjectId() {
    validate();

    final explicit = projectId?.trim();
    if (explicit != null && explicit.isNotEmpty) {
      return explicit;
    }

    final fromCredentials = _projectIdFromCredentials?.trim();
    if (fromCredentials != null && fromCredentials.isNotEmpty) {
      return fromCredentials;
    }

    final fromEnvironment = vertex_auth.resolveEnvironmentProjectId();
    if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
      return fromEnvironment.trim();
    }

    throw GenkitException(
      'Vertex OpenAI requires a GCP project ID. '
      'Set projectId in OpenAIVertexConfig or set '
      'GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  /// Resolves and returns a non-empty endpoint ID.
  String resolveEndpointId() {
    validate();
    return endpointId.trim();
  }

  /// Resolves and returns the OpenAI-compatible Vertex base URL.
  String resolveBaseUrl() {
    final normalizedLocation = location.trim().toLowerCase();
    final apiHost = normalizedLocation == 'global'
        ? 'aiplatform.googleapis.com'
        : '$normalizedLocation-aiplatform.googleapis.com';
    final project = Uri.encodeComponent(resolveProjectId());
    final locationComponent = Uri.encodeComponent(normalizedLocation);
    final endpoint = Uri.encodeComponent(resolveEndpointId());
    return 'https://$apiHost/v1/projects/$project/locations/$locationComponent/endpoints/$endpoint';
  }

  /// Resolves and returns a usable OAuth2 access token.
  Future<String> resolveAccessToken() async {
    validate();
    final token = accessTokenProvider != null
        ? await accessTokenProvider!()
        : accessToken;
    if (token == null || token.trim().isEmpty) {
      throw GenkitException(
        'Vertex OpenAI requires an OAuth access token. '
        'Set accessToken or accessTokenProvider.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return token;
  }
}

/// Public constant handle for OpenAI-compatible plugin
const OpenAICompatPluginHandle openAI = OpenAICompatPluginHandle();

/// Handle class for OpenAI-compatible plugin
class OpenAICompatPluginHandle {
  const OpenAICompatPluginHandle();

  /// Create the plugin instance
  GenkitPlugin call({
    String? apiKey,
    String? baseUrl,
    List<CustomModelDefinition>? models,
    Map<String, String>? headers,
    OpenAIVertexConfig? vertex,
  }) {
    return OpenAIPlugin(
      apiKey: apiKey,
      baseUrl: baseUrl,
      vertex: vertex,
      customModels: models ?? const [],
      headers: headers,
    );
  }

  /// Reference to a model
  ModelRef<OpenAIOptions> model(String name) {
    return modelRef('openai/$name', customOptions: OpenAIOptions.$schema);
  }
}
