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

import 'project_id_resolver.dart';
import 'token_provider.dart';

/// Validates common Vertex config fields used by provider-specific configs.
void validateVertexConfigBasics({
  required String providerName,
  required String? projectId,
  required String location,
  required String? accessToken,
  required AccessTokenProvider? accessTokenProvider,
}) {
  if (projectId != null && projectId.trim().isEmpty) {
    throw GenkitException(
      'Vertex $providerName requires a non-empty projectId.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  if (location.trim().isEmpty) {
    throw GenkitException(
      'Vertex $providerName requires a non-empty location.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final locationPattern = RegExp(r'^[A-Za-z0-9-]+$');
  if (!locationPattern.hasMatch(location.trim())) {
    throw GenkitException(
      'Vertex $providerName location may only contain letters, numbers, and hyphens.',
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

/// Resolves a project ID from explicit, credentials, or environment sources.
String resolveVertexProjectId({
  required String providerName,
  required String configTypeName,
  required String? projectId,
  required String? projectIdFromCredentials,
}) {
  final explicit = projectId?.trim();
  if (explicit != null && explicit.isNotEmpty) {
    return explicit;
  }

  final fromCredentials = projectIdFromCredentials?.trim();
  if (fromCredentials != null && fromCredentials.isNotEmpty) {
    return fromCredentials;
  }

  final fromEnvironment = resolveEnvironmentProjectId();
  if (fromEnvironment != null && fromEnvironment.trim().isNotEmpty) {
    return fromEnvironment.trim();
  }

  throw GenkitException(
    'Vertex $providerName requires a GCP project ID. '
    'Set projectId in $configTypeName or set '
    'GOOGLE_CLOUD_PROJECT/GCLOUD_PROJECT.',
    status: StatusCodes.INVALID_ARGUMENT,
  );
}

/// Resolves and validates a non-empty OAuth access token.
Future<String> resolveVertexAccessToken({
  required String providerName,
  required String? accessToken,
  required AccessTokenProvider? accessTokenProvider,
}) async {
  final token = accessTokenProvider != null
      ? await accessTokenProvider()
      : accessToken;
  if (token == null || token.trim().isEmpty) {
    throw GenkitException(
      'Vertex $providerName requires an OAuth access token. '
      'Set accessToken or accessTokenProvider.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
  return token.trim();
}

/// Validates endpoint IDs used by Vertex API endpoint-style paths.
void validateVertexEndpointId({
  required String providerName,
  required String endpointId,
}) {
  if (endpointId.trim().isEmpty) {
    throw GenkitException(
      'Vertex $providerName requires a non-empty endpointId.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final endpointPattern = RegExp(r'^[A-Za-z0-9_-]+$');
  if (!endpointPattern.hasMatch(endpointId.trim())) {
    throw GenkitException(
      'Vertex $providerName endpointId may only contain letters, numbers, underscores, and hyphens.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }
}

/// Returns a normalized Vertex location string for URL construction.
String normalizeVertexLocation(String location) {
  return location.trim().toLowerCase();
}

/// Returns the Vertex API host for a normalized/non-normalized location.
String vertexApiHostForLocation(String location) {
  final normalizedLocation = normalizeVertexLocation(location);
  if (normalizedLocation == 'global') {
    return 'aiplatform.googleapis.com';
  }
  return '$normalizedLocation-aiplatform.googleapis.com';
}
