import 'dart:async';

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import 'vertex_token_provider_stub.dart'
    if (dart.library.io) 'vertex_token_provider_io.dart'
    as vertex_auth;

/// Signature used to provide an OAuth2 access token for Vertex AI requests.
///
/// Return the raw bearer token value without the `Bearer ` prefix.
typedef AccessTokenProvider = FutureOr<String> Function();

const _cloudPlatformScope = 'https://www.googleapis.com/auth/cloud-platform';

/// Configuration for using Anthropic Claude models on Vertex AI.
class AnthropicVertexConfig {
  /// Google Cloud project ID where Vertex AI is enabled.
  final String projectId;

  /// Vertex region, for example `global` or `us-east5`.
  final String location;

  /// Optional static OAuth2 access token.
  final String? accessToken;

  /// Optional provider used to fetch/refresh OAuth2 access tokens.
  final AccessTokenProvider? accessTokenProvider;

  /// Creates a Vertex Anthropic configuration.
  ///
  /// Provide exactly one of [accessToken] or [accessTokenProvider].
  ///
  /// - Use [accessToken] for short-lived scripts with a pre-fetched token.
  /// - Use [accessTokenProvider] for long-running apps that refresh tokens.
  const AnthropicVertexConfig({
    required this.projectId,
    this.location = 'global',
    this.accessToken,
    this.accessTokenProvider,
  });

  /// Creates Vertex config backed by Application Default Credentials (ADC).
  ///
  /// On Dart IO platforms, ADC looks for credentials in this order:
  /// - `GOOGLE_APPLICATION_CREDENTIALS` file path
  /// - local gcloud ADC file from `gcloud auth application-default login`
  /// - metadata server (for Workload Identity / attached service accounts)
  factory AnthropicVertexConfig.adc({
    required String projectId,
    String location = 'global',
    List<String> scopes = const [_cloudPlatformScope],
    http.Client? baseClient,
  }) {
    return AnthropicVertexConfig(
      projectId: projectId,
      location: location,
      accessTokenProvider: vertex_auth.createAdcTokenProvider(
        scopes: scopes,
        baseClient: baseClient,
      ),
    );
  }

  /// Creates Vertex config backed by service account credentials.
  ///
  /// [credentialsJson] accepts either a decoded JSON map or a JSON string from
  /// a service account key file.
  factory AnthropicVertexConfig.serviceAccount({
    required String projectId,
    required Object credentialsJson,
    String location = 'global',
    List<String> scopes = const [_cloudPlatformScope],
    String? impersonatedUser,
    http.Client? baseClient,
  }) {
    return AnthropicVertexConfig(
      projectId: projectId,
      location: location,
      accessTokenProvider: vertex_auth.createServiceAccountTokenProvider(
        credentialsJson: credentialsJson,
        scopes: scopes,
        impersonatedUser: impersonatedUser,
        baseClient: baseClient,
      ),
    );
  }

  /// Validates required Vertex configuration fields.
  void validate() {
    if (projectId.trim().isEmpty) {
      throw GenkitException(
        'Vertex Anthropic requires a non-empty projectId.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    if (location.trim().isEmpty) {
      throw GenkitException(
        'Vertex Anthropic requires a non-empty location.',
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

  /// Resolves and returns a usable OAuth2 access token.
  ///
  /// Throws [GenkitException] when no token source is configured or when the
  /// configured token resolves to an empty string.
  Future<String> resolveAccessToken() async {
    validate();
    final token = accessTokenProvider != null
        ? await accessTokenProvider!()
        : accessToken;
    if (token == null || token.trim().isEmpty) {
      throw GenkitException(
        'Vertex Anthropic requires an OAuth access token. '
        'Set accessToken or accessTokenProvider.',
        status: StatusCodes.INVALID_ARGUMENT,
      );
    }
    return token;
  }
}
