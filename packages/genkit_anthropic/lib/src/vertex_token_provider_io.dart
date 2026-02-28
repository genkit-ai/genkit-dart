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
