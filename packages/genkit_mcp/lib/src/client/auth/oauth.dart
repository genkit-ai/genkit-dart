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

import '../../util/logging.dart';
import 'oauth_provider.dart';
import 'oauth_types.dart';
import 'pkce.dart';

const _challengeMethod = 'S256';
const _responseType = 'code';

/// Maximum size of an OAuth HTTP response body (1 MB).
const _maxResponseBodySize = 1024 * 1024;

/// Timeout for individual OAuth HTTP requests.
const _requestTimeout = Duration(seconds: 30);

// ---------------------------------------------------------------------------
// Public entry point
// ---------------------------------------------------------------------------

/// Orchestrates the full OAuth authorization flow.
///
/// Handles resource / authorization server discovery, client registration,
/// token exchange, and refresh — with automatic retry on recoverable errors
/// (`invalid_client`, `unauthorized_client`, `invalid_grant`).
///
/// Pass [httpClient] to reuse an existing client and share its lifecycle;
/// when omitted a temporary client is created and closed after the call.
Future<AuthResult> auth(
  OAuthClientProvider provider, {
  required Uri serverUrl,
  String? authorizationCode,
  String? scope,
  Uri? resourceMetadataUrl,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    return await _authInternal(
      provider,
      serverUrl: serverUrl,
      authorizationCode: authorizationCode,
      scope: scope,
      resourceMetadataUrl: resourceMetadataUrl,
      httpClient: client,
    );
  } on OAuthException catch (e) {
    if (e.isInvalidClient) {
      await provider.invalidateCredentials(OAuthInvalidationScope.all);
      return _authInternal(
        provider,
        serverUrl: serverUrl,
        authorizationCode: authorizationCode,
        scope: scope,
        resourceMetadataUrl: resourceMetadataUrl,
        httpClient: client,
      );
    }
    if (e.isInvalidGrant) {
      await provider.invalidateCredentials(OAuthInvalidationScope.tokens);
      return _authInternal(
        provider,
        serverUrl: serverUrl,
        authorizationCode: authorizationCode,
        scope: scope,
        resourceMetadataUrl: resourceMetadataUrl,
        httpClient: client,
      );
    }
    rethrow;
  } finally {
    if (httpClient == null) client.close();
  }
}

Future<AuthResult> _authInternal(
  OAuthClientProvider provider, {
  required Uri serverUrl,
  required HttpClient httpClient,
  String? authorizationCode,
  String? scope,
  Uri? resourceMetadataUrl,
}) async {
  // 1. Validate resource_metadata URL origin (SSRF defence).
  if (resourceMetadataUrl != null) {
    _validateUrlOrigin(resourceMetadataUrl, serverUrl, 'resource_metadata URL');
  }

  // 2. Discover protected resource metadata (RFC 9728).
  OAuthProtectedResourceMetadata? resourceMetadata;
  Uri? authorizationServerUrl;

  try {
    resourceMetadata = await discoverProtectedResourceMetadata(
      serverUrl,
      resourceMetadataUrl: resourceMetadataUrl,
      httpClient: httpClient,
    );
    final servers = resourceMetadata.authorizationServers;
    if (servers != null && servers.isNotEmpty) {
      authorizationServerUrl = Uri.parse(servers.first);
    }
  } catch (_) {
    // Fall back to legacy behaviour: server URL as auth server.
  }

  authorizationServerUrl ??= serverUrl.replace(path: '/');

  // 3. Validate the authorization server URL via the provider.
  final isAllowed = await provider.isAuthorizationServerUrlAllowed(
    serverUrl,
    authorizationServerUrl,
  );
  if (!isAllowed) {
    throw StateError(
      'Authorization server $authorizationServerUrl is not allowed for '
      'MCP server $serverUrl. Override '
      'OAuthClientProvider.isAuthorizationServerUrlAllowed to permit '
      'cross-origin authorization servers.',
    );
  }

  // 4. Select the RFC 8707 resource indicator.
  final resource = await _selectResourceURL(
    serverUrl,
    provider,
    resourceMetadata,
  );

  // 5. Discover authorization server metadata.
  final metadata = await discoverAuthorizationServerMetadata(
    authorizationServerUrl,
    httpClient: httpClient,
  );

  // 5a. Validate that metadata endpoints share the AS origin.
  if (metadata != null) {
    _validateMetadataEndpoints(metadata, authorizationServerUrl);
  }

  // 6. Register client if needed.
  var clientInfo = await provider.clientInformation();
  if (clientInfo == null) {
    if (authorizationCode != null) {
      throw StateError(
        'Existing OAuth client information is required when exchanging '
        'an authorization code',
      );
    }

    final supportsUrlBasedId =
        metadata?.clientIdMetadataDocumentSupported == true;
    final clientMetadataUrl = provider.clientMetadataUrl;
    final shouldUseUrlId =
        supportsUrlBasedId &&
        clientMetadataUrl != null &&
        clientMetadataUrl.isNotEmpty;

    if (shouldUseUrlId) {
      clientInfo = OAuthClientInformation(clientId: clientMetadataUrl);
      await provider.saveClientInformation(clientInfo);
    } else {
      final fullInfo = await registerClient(
        authorizationServerUrl,
        metadata: metadata,
        clientMetadata: provider.clientMetadata,
        httpClient: httpClient,
      );
      await provider.saveClientInformation(fullInfo);
      clientInfo = fullInfo;
    }
  }

  // 7. Non-interactive flow or authorization code exchange.
  final nonInteractive = provider.redirectUrl == null;
  if (authorizationCode != null || nonInteractive) {
    final tokens = await fetchToken(
      provider,
      authorizationServerUrl,
      metadata: metadata,
      resource: resource,
      authorizationCode: authorizationCode,
      httpClient: httpClient,
    );
    await provider.saveTokens(tokens);
    return AuthResult.authorized;
  }

  // 8. Attempt token refresh.
  final existing = await provider.tokens();
  if (existing?.refreshToken != null) {
    try {
      final refreshed = await refreshAuthorization(
        authorizationServerUrl,
        metadata: metadata,
        clientInformation: clientInfo,
        refreshToken: existing!.refreshToken!,
        resource: resource,
        customAuth: provider.customClientAuthentication,
        httpClient: httpClient,
      );
      await provider.saveTokens(refreshed);
      return AuthResult.authorized;
    } on OAuthException catch (e) {
      if (!e.isServerError) rethrow;
    } catch (_) {
      // Unknown error during refresh — fall through to new authorization.
    }
  }

  // 9. Start a new authorization flow (PKCE).
  final state = await provider.state();
  final challenge = await startAuthorization(
    authorizationServerUrl,
    metadata: metadata,
    clientInformation: clientInfo,
    redirectUrl: provider.redirectUrl!,
    scope:
        scope ??
        resourceMetadata?.scopesSupported?.join(' ') ??
        provider.clientMetadata.scope,
    state: state,
    resource: resource,
  );

  await provider.saveCodeVerifier(challenge.codeVerifier);
  if (state != null) {
    await provider.saveState(state);
  }
  await provider.redirectToAuthorization(challenge.authorizationUrl);
  return AuthResult.redirect;
}

// ---------------------------------------------------------------------------
// Discovery
// ---------------------------------------------------------------------------

/// Discovers RFC 9728 OAuth 2.0 Protected Resource Metadata.
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthProtectedResourceMetadata> discoverProtectedResourceMetadata(
  Uri serverUrl, {
  Uri? resourceMetadataUrl,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    final url =
        resourceMetadataUrl ??
        serverUrl.replace(
          path: '/.well-known/oauth-protected-resource${serverUrl.path}',
        );

    final response = await _httpGet(client, url);
    if (response.statusCode == HttpStatus.notFound) {
      throw StateError(
        'Resource server does not implement OAuth 2.0 Protected Resource '
        'Metadata.',
      );
    }
    if (response.statusCode != HttpStatus.ok) {
      throw StateError(
        'HTTP ${response.statusCode} loading protected resource metadata.',
      );
    }
    final body = await _readResponseBody(response);
    return OAuthProtectedResourceMetadata.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Discovers OAuth 2.0 / OpenID Connect authorization server metadata.
///
/// Tries RFC 8414 (`oauth-authorization-server`) first, then falls back to
/// OpenID Connect Discovery (`openid-configuration`).
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthServerMetadata?> discoverAuthorizationServerMetadata(
  Uri authorizationServerUrl, {
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    for (final endpoint in _buildDiscoveryUrls(authorizationServerUrl)) {
      try {
        final response = await _httpGet(client, endpoint);
        if (!_isSuccess(response.statusCode)) {
          await _drain(response);
          if (response.statusCode >= 400 && response.statusCode < 500) {
            continue;
          }
          throw StateError(
            'HTTP ${response.statusCode} loading authorization server '
            'metadata from $endpoint',
          );
        }
        final body = await _readResponseBody(response);
        return OAuthServerMetadata.fromJson(
          jsonDecode(body) as Map<String, dynamic>,
        );
      } catch (e) {
        if (e is StateError) rethrow;
        mcpLogger.fine('[OAuth] Discovery failed for $endpoint: $e');
        continue;
      }
    }
    return null;
  } finally {
    if (httpClient == null) client.close();
  }
}

// ---------------------------------------------------------------------------
// Authorization flow
// ---------------------------------------------------------------------------

/// Result of [startAuthorization] containing the authorization URL and
/// the PKCE code verifier to persist.
final class AuthorizationStartResult {
  final Uri authorizationUrl;
  final String codeVerifier;

  const AuthorizationStartResult({
    required this.authorizationUrl,
    required this.codeVerifier,
  });
}

/// Generates a PKCE challenge and builds the authorization URL.
Future<AuthorizationStartResult> startAuthorization(
  Uri authorizationServerUrl, {
  OAuthServerMetadata? metadata,
  required OAuthClientInformation clientInformation,
  required Uri redirectUrl,
  String? scope,
  String? state,
  Uri? resource,
}) async {
  Uri authorizationUrl;
  if (metadata != null) {
    authorizationUrl = Uri.parse(metadata.authorizationEndpoint);
    if (!metadata.responseTypesSupported.contains(_responseType)) {
      throw StateError(
        'Incompatible auth server: does not support response type '
        '$_responseType',
      );
    }
    final challengeMethods = metadata.codeChallengeMethodsSupported;
    if (challengeMethods != null &&
        !challengeMethods.contains(_challengeMethod)) {
      throw StateError(
        'Incompatible auth server: does not support code challenge method '
        '$_challengeMethod',
      );
    }
  } else {
    authorizationUrl = authorizationServerUrl.replace(path: '/authorize');
  }

  final pkce = PkceChallenge.generate();
  final params = <String, String>{
    'response_type': _responseType,
    'client_id': clientInformation.clientId,
    'code_challenge': pkce.codeChallenge,
    'code_challenge_method': _challengeMethod,
    'redirect_uri': redirectUrl.toString(),
    'state': ?state,
    'scope': ?scope,
    if (resource != null) 'resource': resource.toString(),
  };
  authorizationUrl = authorizationUrl.replace(
    queryParameters: {...authorizationUrl.queryParameters, ...params},
  );

  return AuthorizationStartResult(
    authorizationUrl: authorizationUrl,
    codeVerifier: pkce.codeVerifier,
  );
}

// ---------------------------------------------------------------------------
// Token exchange
// ---------------------------------------------------------------------------

/// Exchanges an authorization code for tokens.
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthTokens> exchangeAuthorization(
  Uri authorizationServerUrl, {
  OAuthServerMetadata? metadata,
  required OAuthClientInformation clientInformation,
  required String authorizationCode,
  required String codeVerifier,
  required Uri redirectUri,
  Uri? resource,
  OAuthClientAuthenticator? customAuth,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    final params = {
      'grant_type': 'authorization_code',
      'code': authorizationCode,
      'code_verifier': codeVerifier,
      'redirect_uri': redirectUri.toString(),
    };
    return _executeTokenRequest(
      authorizationServerUrl,
      httpClient: client,
      metadata: metadata,
      params: params,
      clientInformation: clientInformation,
      customAuth: customAuth,
      resource: resource,
    );
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Refreshes tokens using a refresh token.
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthTokens> refreshAuthorization(
  Uri authorizationServerUrl, {
  OAuthServerMetadata? metadata,
  required OAuthClientInformation clientInformation,
  required String refreshToken,
  Uri? resource,
  OAuthClientAuthenticator? customAuth,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    final params = {
      'grant_type': 'refresh_token',
      'refresh_token': refreshToken,
    };
    final tokens = await _executeTokenRequest(
      authorizationServerUrl,
      httpClient: client,
      metadata: metadata,
      params: params,
      clientInformation: clientInformation,
      customAuth: customAuth,
      resource: resource,
    );
    return tokens.refreshToken != null
        ? tokens
        : tokens.copyWith(refreshToken: refreshToken);
  } finally {
    if (httpClient == null) client.close();
  }
}

/// Unified token fetching that works with any grant type via the provider's
/// [OAuthClientProvider.prepareTokenRequest].
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthTokens> fetchToken(
  OAuthClientProvider provider,
  Uri authorizationServerUrl, {
  OAuthServerMetadata? metadata,
  Uri? resource,
  String? authorizationCode,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    final scope = provider.clientMetadata.scope;
    var params = await provider.prepareTokenRequest(scope);

    if (params == null) {
      if (authorizationCode == null) {
        throw StateError(
          'Either provider.prepareTokenRequest() or authorizationCode is '
          'required',
        );
      }
      if (provider.redirectUrl == null) {
        throw StateError('redirectUrl is required for authorization_code flow');
      }
      final verifier = await provider.codeVerifier();
      params = {
        'grant_type': 'authorization_code',
        'code': authorizationCode,
        'code_verifier': verifier,
        'redirect_uri': provider.redirectUrl.toString(),
      };
    }

    final clientInfo = await provider.clientInformation();
    return _executeTokenRequest(
      authorizationServerUrl,
      httpClient: client,
      metadata: metadata,
      params: params,
      clientInformation: clientInfo,
      customAuth: provider.customClientAuthentication,
      resource: resource,
    );
  } finally {
    if (httpClient == null) client.close();
  }
}

// ---------------------------------------------------------------------------
// Client registration
// ---------------------------------------------------------------------------

/// Performs RFC 7591 Dynamic Client Registration.
///
/// Pass [httpClient] to reuse an existing client; when omitted a temporary
/// client is created and closed after the call.
Future<OAuthClientInformation> registerClient(
  Uri authorizationServerUrl, {
  OAuthServerMetadata? metadata,
  required OAuthClientMetadata clientMetadata,
  HttpClient? httpClient,
}) async {
  final client = httpClient ?? HttpClient();
  try {
    Uri registrationUrl;
    if (metadata?.registrationEndpoint != null) {
      registrationUrl = Uri.parse(metadata!.registrationEndpoint!);
    } else {
      registrationUrl = authorizationServerUrl.replace(path: '/register');
    }

    final response = await _httpPost(
      client,
      registrationUrl,
      contentType: ContentType.json,
      body: jsonEncode(clientMetadata.toJson()),
    );
    if (!_isSuccess(response.statusCode)) {
      throw await _parseErrorResponse(response);
    }
    final body = await _readResponseBody(response);
    return OAuthClientInformation.fromJson(
      jsonDecode(body) as Map<String, dynamic>,
    );
  } finally {
    if (httpClient == null) client.close();
  }
}

// ---------------------------------------------------------------------------
// WWW-Authenticate parsing
// ---------------------------------------------------------------------------

/// Extracts `resource_metadata`, `scope`, and `error` from a
/// `WWW-Authenticate: Bearer ...` header.
WwwAuthenticateParams extractWwwAuthenticateParams(
  HttpClientResponse response,
) {
  final header = response.headers.value('www-authenticate');
  if (header == null) return const WwwAuthenticateParams();

  final spaceIndex = header.indexOf(' ');
  if (spaceIndex == -1) return const WwwAuthenticateParams();

  final type = header.substring(0, spaceIndex);
  if (type.toLowerCase() != 'bearer') return const WwwAuthenticateParams();

  Uri? resourceMetadataUrl;
  final rmMatch = _extractField(header, 'resource_metadata');
  if (rmMatch != null) {
    try {
      resourceMetadataUrl = Uri.parse(rmMatch);
    } catch (_) {}
  }

  return WwwAuthenticateParams(
    resourceMetadataUrl: resourceMetadataUrl,
    scope: _extractField(header, 'scope'),
    error: _extractField(header, 'error'),
  );
}

// ---------------------------------------------------------------------------
// Client auth method selection
// ---------------------------------------------------------------------------

/// Selects the best client authentication method based on server support
/// and available credentials.
String selectClientAuthMethod(
  OAuthClientInformation clientInfo,
  List<String> supportedMethods,
) {
  final hasSecret = clientInfo.clientSecret != null;

  if (supportedMethods.isEmpty) {
    return hasSecret ? 'client_secret_post' : 'none';
  }

  final regMethod = clientInfo.tokenEndpointAuthMethod;
  if (regMethod != null && supportedMethods.contains(regMethod)) {
    return regMethod;
  }

  if (hasSecret && supportedMethods.contains('client_secret_basic')) {
    return 'client_secret_basic';
  }
  if (hasSecret && supportedMethods.contains('client_secret_post')) {
    return 'client_secret_post';
  }
  if (supportedMethods.contains('none')) return 'none';

  return hasSecret ? 'client_secret_post' : 'none';
}

// ---------------------------------------------------------------------------
// Resource URL helpers
// ---------------------------------------------------------------------------

/// Converts a server URL to a resource URL by stripping the fragment
/// (RFC 8707 §2).
Uri resourceUrlFromServerUrl(Uri url) => url.removeFragment();

/// Checks whether [requested] matches [configured] per RFC 8707.
bool checkResourceAllowed({required Uri requested, required Uri configured}) {
  if (requested.origin != configured.origin) return false;
  if (requested.path.length < configured.path.length) return false;

  final rPath = requested.path.endsWith('/')
      ? requested.path
      : '${requested.path}/';
  final cPath = configured.path.endsWith('/')
      ? configured.path
      : '${configured.path}/';
  return rPath.startsWith(cPath);
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

Future<Uri?> _selectResourceURL(
  Uri serverUrl,
  OAuthClientProvider provider,
  OAuthProtectedResourceMetadata? metadata,
) async {
  final defaultResource = resourceUrlFromServerUrl(serverUrl);

  final validator = provider.resourceURLValidator;
  if (validator != null) {
    return validator(defaultResource, metadata?.resource);
  }

  if (metadata == null) return null;

  final configuredResource = Uri.parse(metadata.resource);
  if (!checkResourceAllowed(
    requested: defaultResource,
    configured: configuredResource,
  )) {
    throw StateError(
      'Protected resource ${metadata.resource} does not match expected '
      '$defaultResource',
    );
  }
  return configuredResource;
}

/// Validates that [url] shares the same origin as [expectedOrigin].
void _validateUrlOrigin(Uri url, Uri expectedOrigin, String label) {
  if (url.origin != expectedOrigin.origin) {
    throw StateError(
      '$label origin ${url.origin} does not match expected '
      '${expectedOrigin.origin}',
    );
  }
}

/// Validates that metadata endpoint URLs share the authorization server's
/// origin, preventing SSRF via malicious metadata responses.
void _validateMetadataEndpoints(
  OAuthServerMetadata metadata,
  Uri authorizationServerUrl,
) {
  _validateEndpointUrl(
    metadata.authorizationEndpoint,
    authorizationServerUrl,
    'authorization_endpoint',
  );
  _validateEndpointUrl(
    metadata.tokenEndpoint,
    authorizationServerUrl,
    'token_endpoint',
  );
  if (metadata.registrationEndpoint != null) {
    _validateEndpointUrl(
      metadata.registrationEndpoint!,
      authorizationServerUrl,
      'registration_endpoint',
    );
  }
}

void _validateEndpointUrl(
  String endpoint,
  Uri authorizationServerUrl,
  String label,
) {
  final endpointUri = Uri.parse(endpoint);
  if (endpointUri.origin != authorizationServerUrl.origin) {
    throw StateError(
      'Authorization server metadata $label origin '
      '${endpointUri.origin} does not match authorization server '
      '${authorizationServerUrl.origin}',
    );
  }
}

List<Uri> _buildDiscoveryUrls(Uri authServerUrl) {
  final hasPath = authServerUrl.path != '/';
  final origin = authServerUrl.origin;

  if (!hasPath) {
    return [
      Uri.parse('$origin/.well-known/oauth-authorization-server'),
      Uri.parse('$origin/.well-known/openid-configuration'),
    ];
  }

  var path = authServerUrl.path;
  if (path.endsWith('/')) path = path.substring(0, path.length - 1);
  return [
    Uri.parse('$origin/.well-known/oauth-authorization-server$path'),
    Uri.parse('$origin/.well-known/openid-configuration$path'),
    Uri.parse('$origin$path/.well-known/openid-configuration'),
  ];
}

Future<OAuthTokens> _executeTokenRequest(
  Uri authorizationServerUrl, {
  required HttpClient httpClient,
  OAuthServerMetadata? metadata,
  required Map<String, String> params,
  OAuthClientInformation? clientInformation,
  OAuthClientAuthenticator? customAuth,
  Uri? resource,
}) async {
  final tokenUrl = metadata?.tokenEndpoint != null
      ? Uri.parse(metadata!.tokenEndpoint)
      : authorizationServerUrl.replace(path: '/token');

  final headers = <String, String>{
    'content-type': 'application/x-www-form-urlencoded',
    'accept': 'application/json',
  };

  final body = Map<String, String>.from(params);
  if (resource != null) {
    body['resource'] = resource.toString();
  }

  if (customAuth != null) {
    await customAuth(headers, body, tokenUrl, metadata);
  } else if (clientInformation != null) {
    final supported = metadata?.tokenEndpointAuthMethodsSupported ?? [];
    final method = selectClientAuthMethod(clientInformation, supported);
    _applyClientAuth(method, clientInformation, headers, body);
  }

  final response = await _httpPost(
    httpClient,
    tokenUrl,
    headers: headers,
    body: _encodeFormParams(body),
  );
  if (!_isSuccess(response.statusCode)) {
    throw await _parseErrorResponse(response);
  }
  final responseBody = await _readResponseBody(response);
  final json = jsonDecode(responseBody);
  if (json is Map<String, dynamic> && json.containsKey('error')) {
    throw OAuthException.fromResponse(OAuthErrorResponse.fromJson(json));
  }
  return OAuthTokens.fromJson(json as Map<String, dynamic>);
}

void _applyClientAuth(
  String method,
  OAuthClientInformation info,
  Map<String, String> headers,
  Map<String, String> params,
) {
  switch (method) {
    case 'client_secret_basic':
      if (info.clientSecret == null) {
        throw StateError('client_secret_basic requires a client_secret');
      }
      final credentials = base64Encode(
        utf8.encode('${info.clientId}:${info.clientSecret}'),
      );
      headers['authorization'] = 'Basic $credentials';
    case 'client_secret_post':
      params['client_id'] = info.clientId;
      if (info.clientSecret != null) {
        params['client_secret'] = info.clientSecret!;
      }
    case 'none':
      params['client_id'] = info.clientId;
    default:
      throw StateError('Unsupported auth method: $method');
  }
}

String _encodeFormParams(Map<String, String> params) {
  return params.entries
      .map(
        (e) =>
            '${Uri.encodeQueryComponent(e.key)}='
            '${Uri.encodeQueryComponent(e.value)}',
      )
      .join('&');
}

String? _extractField(String header, String fieldName) {
  final pattern = RegExp('$fieldName=(?:"([^"]+)"|([^\\s,]+))');
  final match = pattern.firstMatch(header);
  return match?.group(1) ?? match?.group(2);
}

Future<OAuthException> _parseErrorResponse(HttpClientResponse response) async {
  final body = await _readResponseBody(response);
  try {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return OAuthException.fromResponse(OAuthErrorResponse.fromJson(json));
  } catch (_) {
    return OAuthException('server_error', 'HTTP ${response.statusCode}: $body');
  }
}

// ---------------------------------------------------------------------------
// HTTP helpers
// ---------------------------------------------------------------------------

Future<HttpClientResponse> _httpGet(HttpClient client, Uri url) async {
  final request = await client.getUrl(url);
  request.headers.set('accept', 'application/json');
  return request.close().timeout(_requestTimeout);
}

Future<HttpClientResponse> _httpPost(
  HttpClient client,
  Uri url, {
  ContentType? contentType,
  Map<String, String>? headers,
  String? body,
}) async {
  final request = await client.postUrl(url);
  if (contentType != null) {
    request.headers.contentType = contentType;
  }
  if (headers != null) {
    for (final entry in headers.entries) {
      request.headers.set(entry.key, entry.value);
    }
  }
  if (body != null) request.write(body);
  return request.close().timeout(_requestTimeout);
}

Future<String> _readResponseBody(HttpClientResponse response) async {
  var totalSize = 0;
  final chunks = <String>[];
  await for (final chunk in response.transform(utf8.decoder)) {
    totalSize += chunk.length;
    if (totalSize > _maxResponseBodySize) {
      throw StateError(
        'OAuth response body exceeds '
        '${_maxResponseBodySize ~/ 1024} KB limit',
      );
    }
    chunks.add(chunk);
  }
  return chunks.join();
}

Future<void> _drain(HttpClientResponse response) {
  return response.drain<void>();
}

bool _isSuccess(int statusCode) => statusCode >= 200 && statusCode < 300;
