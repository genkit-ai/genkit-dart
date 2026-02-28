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

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;

import 'project_id_resolver_stub.dart'
    if (dart.library.io) 'project_id_resolver_io.dart'
    as project_id;
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
  /// Optional Google Cloud project ID where Vertex AI is enabled.
  ///
  /// When omitted, resolution falls back to:
  /// 1. `project_id` from service account credentials (if configured via
  ///    [AnthropicVertexConfig.serviceAccount])
  /// 2. environment variables (`GOOGLE_CLOUD_PROJECT`, `GCLOUD_PROJECT`)
  final String? projectId;

  final String? _projectIdFromCredentials;

  /// Vertex region, for example `global` or `us-east5`.
  ///
  /// Must contain only letters, numbers, and hyphens.
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
  /// - [projectId] is optional if it can be inferred from service account
  ///   credentials or environment variables.
  const AnthropicVertexConfig({
    this.projectId,
    this.location = 'global',
    this.accessToken,
    this.accessTokenProvider,
  }) : _projectIdFromCredentials = null;

  const AnthropicVertexConfig._({
    required this.projectId,
    required String? projectIdFromCredentials,
    required this.location,
    required this.accessToken,
    required this.accessTokenProvider,
  }) : _projectIdFromCredentials = projectIdFromCredentials;

  /// Creates Vertex config backed by Application Default Credentials (ADC).
  ///
  /// On Dart IO platforms, ADC looks for credentials in this order:
  /// - `GOOGLE_APPLICATION_CREDENTIALS` file path
  /// - local gcloud ADC file from `gcloud auth application-default login`
  /// - metadata server (for Workload Identity / attached service accounts)
  ///
  /// [projectId] is optional and can be resolved from environment variables.
  factory AnthropicVertexConfig.adc({
    String? projectId,
    String location = 'global',
    List<String> scopes = const [_cloudPlatformScope],
    http.Client? baseClient,
  }) {
    return AnthropicVertexConfig._(
      projectId: projectId,
      projectIdFromCredentials: null,
      location: location,
      accessTokenProvider: vertex_auth.createAdcTokenProvider(
        scopes: scopes,
        baseClient: baseClient,
      ),
      accessToken: null,
    );
  }

  /// Creates Vertex config backed by service account credentials.
  ///
  /// [credentialsJson] accepts either a decoded JSON map or a JSON string from
  /// a service account key file.
  ///
  /// [projectId] is optional and can be inferred from `project_id` in
  /// [credentialsJson].
  factory AnthropicVertexConfig.serviceAccount({
    String? projectId,
    required Object credentialsJson,
    String location = 'global',
    List<String> scopes = const [_cloudPlatformScope],
    String? impersonatedUser,
    http.Client? baseClient,
  }) {
    return AnthropicVertexConfig._(
      projectId: projectId,
      projectIdFromCredentials: _extractProjectId(credentialsJson),
      location: location,
      accessTokenProvider: vertex_auth.createServiceAccountTokenProvider(
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
    final locationPattern = RegExp(r'^[A-Za-z0-9-]+$');
    if (!locationPattern.hasMatch(location.trim())) {
      throw GenkitException(
        'Vertex Anthropic location may only contain letters, numbers, and hyphens.',
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
  ///
  /// Resolution order:
  /// 1. explicit [projectId]
  /// 2. service account `project_id` (if configured via service account)
  /// 3. environment variables `GOOGLE_CLOUD_PROJECT` and `GCLOUD_PROJECT`
  ///
  /// Throws [GenkitException] if no project ID can be resolved.
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

    final fromEnvironment = project_id.resolveEnvironmentProjectId();
    if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
      return fromEnvironment.trim();
    }

    throw GenkitException(
      'Vertex Anthropic requires a GCP project ID. '
      'Set projectId in AnthropicVertexConfig or set '
      'GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
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

String? _extractProjectId(Object credentialsJson) {
  Map<String, dynamic>? json;
  if (credentialsJson is Map) {
    json = Map<String, dynamic>.from(credentialsJson);
  } else if (credentialsJson is String) {
    try {
      final decoded = jsonDecode(credentialsJson);
      if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }

  final projectId = json?['project_id'];
  if (projectId is String && projectId.trim().isNotEmpty) {
    return projectId.trim();
  }
  return null;
}
