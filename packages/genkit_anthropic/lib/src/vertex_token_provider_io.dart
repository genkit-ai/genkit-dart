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

import 'package:googleapis_auth/auth_io.dart' as auth;
import 'package:http/http.dart' as http;

Future<String> Function() createAdcTokenProvider({
  required List<String> scopes,
  http.Client? baseClient,
}) {
  return _cachedTokenProvider(() async {
    final client = await auth.clientViaApplicationDefaultCredentials(
      scopes: scopes,
      baseClient: baseClient,
    );
    try {
      return client.credentials.accessToken;
    } finally {
      client.close();
    }
  });
}

Future<String> Function() createServiceAccountTokenProvider({
  required Object credentialsJson,
  required List<String> scopes,
  String? impersonatedUser,
  http.Client? baseClient,
}) {
  return _cachedTokenProvider(() async {
    final credentials = auth.ServiceAccountCredentials.fromJson(
      credentialsJson,
      impersonatedUser: impersonatedUser,
    );
    final client = await auth.clientViaServiceAccount(
      credentials,
      scopes,
      baseClient: baseClient,
    );
    try {
      return client.credentials.accessToken;
    } finally {
      client.close();
    }
  });
}

const _tokenRefreshSkew = Duration(minutes: 1);

Future<String> Function() _cachedTokenProvider(
  Future<auth.AccessToken> Function() fetchAccessToken,
) {
  auth.AccessToken? cachedToken;
  Future<auth.AccessToken>? pendingToken;

  bool isTokenFresh(auth.AccessToken token) {
    return DateTime.now().toUtc().isBefore(
      token.expiry.subtract(_tokenRefreshSkew),
    );
  }

  Future<auth.AccessToken> getToken() async {
    final token = cachedToken;
    if (token != null && isTokenFresh(token)) {
      return token;
    }

    pendingToken ??= fetchAccessToken();
    try {
      cachedToken = await pendingToken;
      return cachedToken!;
    } catch (_) {
      pendingToken = null;
      rethrow;
    } finally {
      pendingToken = null;
    }
  }

  return () async {
    final token = await getToken();
    return token.data;
  };
}
