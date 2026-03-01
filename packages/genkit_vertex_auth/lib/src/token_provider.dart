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

import 'package:http/http.dart' as http;

import '_token_provider_stub.dart'
    if (dart.library.io) '_token_provider_io.dart'
    as token_provider;

/// Signature used to provide an OAuth2 access token for Vertex AI requests.
///
/// Return the raw bearer token value without the `Bearer ` prefix.
typedef AccessTokenProvider = FutureOr<String> Function();

/// OAuth scope used by most Vertex AI OpenAPI calls.
const cloudPlatformScope = 'https://www.googleapis.com/auth/cloud-platform';

/// Creates an access token provider backed by Application Default Credentials.
AccessTokenProvider createAdcAccessTokenProvider({
  List<String> scopes = const [cloudPlatformScope],
  http.Client? baseClient,
}) {
  return token_provider.createAdcAccessTokenProvider(
    scopes: scopes,
    baseClient: baseClient,
  );
}

/// Creates an access token provider backed by service account credentials.
AccessTokenProvider createServiceAccountAccessTokenProvider({
  required Object credentialsJson,
  List<String> scopes = const [cloudPlatformScope],
  String? impersonatedUser,
  http.Client? baseClient,
}) {
  return token_provider.createServiceAccountAccessTokenProvider(
    credentialsJson: credentialsJson,
    scopes: scopes,
    impersonatedUser: impersonatedUser,
    baseClient: baseClient,
  );
}
