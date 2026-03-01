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

import 'package:genkit_mcp/genkit_mcp.dart';
import 'package:genkit_mcp/src/client/auth/pkce.dart';
import 'package:test/test.dart';

class _MinimalProvider extends OAuthClientProvider {
  @override
  Uri? get redirectUrl => null;

  @override
  OAuthClientMetadata get clientMetadata =>
      const OAuthClientMetadata(redirectUris: []);

  @override
  Future<OAuthClientInformation?> clientInformation() async => null;

  @override
  Future<OAuthTokens?> tokens() async => null;

  @override
  Future<void> saveTokens(OAuthTokens tokens) async {}

  @override
  Future<void> redirectToAuthorization(Uri url) async {}

  @override
  Future<void> saveCodeVerifier(String v) async {}

  @override
  Future<String> codeVerifier() async => '';
}

void main() {
  group('PkceChallenge', () {
    test('generates verifier and challenge with correct length', () {
      final pkce = PkceChallenge.generate();
      expect(pkce.codeVerifier, isNotEmpty);
      expect(pkce.codeChallenge, isNotEmpty);
      expect(pkce.codeVerifier.length, greaterThanOrEqualTo(32));
      expect(pkce.codeChallenge.length, greaterThanOrEqualTo(32));
    });

    test('verifier uses only URL-safe base64 characters', () {
      final pkce = PkceChallenge.generate();
      expect(pkce.codeVerifier, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
      expect(pkce.codeChallenge, matches(RegExp(r'^[A-Za-z0-9_-]+$')));
    });

    test('generates unique challenges', () {
      final a = PkceChallenge.generate();
      final b = PkceChallenge.generate();
      expect(a.codeVerifier, isNot(equals(b.codeVerifier)));
      expect(a.codeChallenge, isNot(equals(b.codeChallenge)));
    });

    test('verifier and challenge are different strings', () {
      final pkce = PkceChallenge.generate();
      expect(pkce.codeVerifier, isNot(equals(pkce.codeChallenge)));
    });
  });

  group('selectClientAuthMethod', () {
    test(
      'returns client_secret_post for client with secret when no methods specified',
      () {
        final info = OAuthClientInformation(
          clientId: 'c1',
          clientSecret: 'secret',
        );
        expect(selectClientAuthMethod(info, []), 'client_secret_post');
      },
    );

    test('returns none for public client when no methods specified', () {
      final info = OAuthClientInformation(clientId: 'c1');
      expect(selectClientAuthMethod(info, []), 'none');
    });

    test('prefers client_secret_basic when supported and secret available', () {
      final info = OAuthClientInformation(
        clientId: 'c1',
        clientSecret: 'secret',
      );
      expect(
        selectClientAuthMethod(info, [
          'client_secret_basic',
          'client_secret_post',
          'none',
        ]),
        'client_secret_basic',
      );
    });

    test('falls back to client_secret_post when basic not supported', () {
      final info = OAuthClientInformation(
        clientId: 'c1',
        clientSecret: 'secret',
      );
      expect(
        selectClientAuthMethod(info, ['client_secret_post', 'none']),
        'client_secret_post',
      );
    });

    test('returns none when supported and no secret', () {
      final info = OAuthClientInformation(clientId: 'c1');
      expect(selectClientAuthMethod(info, ['none']), 'none');
    });

    test('uses method from registration response if supported', () {
      final info = OAuthClientInformation(
        clientId: 'c1',
        clientSecret: 'secret',
        tokenEndpointAuthMethod: 'client_secret_post',
      );
      expect(
        selectClientAuthMethod(info, [
          'client_secret_basic',
          'client_secret_post',
        ]),
        'client_secret_post',
      );
    });

    test('ignores registration method if not in supported list', () {
      final info = OAuthClientInformation(
        clientId: 'c1',
        clientSecret: 'secret',
        tokenEndpointAuthMethod: 'private_key_jwt',
      );
      expect(
        selectClientAuthMethod(info, [
          'client_secret_basic',
          'client_secret_post',
        ]),
        'client_secret_basic',
      );
    });
  });

  group('checkResourceAllowed', () {
    test('matches same origin and path', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://api.example.com/mcp'),
          configured: Uri.parse('https://api.example.com/mcp'),
        ),
        isTrue,
      );
    });

    test('matches subpath of configured resource', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://api.example.com/api/v2/mcp'),
          configured: Uri.parse('https://api.example.com/api'),
        ),
        isTrue,
      );
    });

    test('rejects different origin', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://other.example.com/mcp'),
          configured: Uri.parse('https://api.example.com/mcp'),
        ),
        isFalse,
      );
    });

    test('rejects different port', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://api.example.com:8080/mcp'),
          configured: Uri.parse('https://api.example.com:9090/mcp'),
        ),
        isFalse,
      );
    });

    test('rejects shorter path than configured', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://api.example.com/api'),
          configured: Uri.parse('https://api.example.com/api/v2'),
        ),
        isFalse,
      );
    });

    test('prevents prefix-confusion (api vs api123)', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://example.com/api123'),
          configured: Uri.parse('https://example.com/api'),
        ),
        isFalse,
      );
    });

    test('handles trailing slashes correctly', () {
      expect(
        checkResourceAllowed(
          requested: Uri.parse('https://example.com/api/'),
          configured: Uri.parse('https://example.com/api'),
        ),
        isTrue,
      );
    });
  });

  group('resourceUrlFromServerUrl', () {
    test('strips fragment from URL', () {
      final result = resourceUrlFromServerUrl(
        Uri.parse('https://example.com/mcp#section'),
      );
      expect(result.fragment, isEmpty);
      expect(result.toString(), 'https://example.com/mcp');
    });

    test('preserves path and query', () {
      final result = resourceUrlFromServerUrl(
        Uri.parse('https://example.com/api/mcp?key=val'),
      );
      expect(result.path, '/api/mcp');
      expect(result.query, 'key=val');
    });
  });

  group('OAuthTokens', () {
    test('fromJson parses all fields', () {
      final tokens = OAuthTokens.fromJson({
        'access_token': 'at-123',
        'token_type': 'bearer',
        'expires_in': 3600,
        'scope': 'read write',
        'refresh_token': 'rt-456',
      });
      expect(tokens.accessToken, 'at-123');
      expect(tokens.tokenType, 'bearer');
      expect(tokens.expiresIn, 3600);
      expect(tokens.scope, 'read write');
      expect(tokens.refreshToken, 'rt-456');
    });

    test('fromJson handles optional fields', () {
      final tokens = OAuthTokens.fromJson({
        'access_token': 'at',
        'token_type': 'bearer',
      });
      expect(tokens.expiresIn, isNull);
      expect(tokens.scope, isNull);
      expect(tokens.refreshToken, isNull);
    });

    test('copyWith replaces refresh token', () {
      final original = OAuthTokens(
        accessToken: 'at',
        tokenType: 'bearer',
        refreshToken: 'old',
      );
      final updated = original.copyWith(refreshToken: 'new');
      expect(updated.accessToken, 'at');
      expect(updated.refreshToken, 'new');
    });
  });

  group('OAuthClientInformation', () {
    test('fromJson parses all fields', () {
      final info = OAuthClientInformation.fromJson({
        'client_id': 'cid',
        'client_secret': 'csecret',
        'client_id_issued_at': 1234567890,
        'client_secret_expires_at': 0,
        'token_endpoint_auth_method': 'client_secret_basic',
      });
      expect(info.clientId, 'cid');
      expect(info.clientSecret, 'csecret');
      expect(info.clientIdIssuedAt, 1234567890);
      expect(info.clientSecretExpiresAt, 0);
      expect(info.tokenEndpointAuthMethod, 'client_secret_basic');
    });
  });

  group('OAuthServerMetadata', () {
    test('fromJson parses required and optional fields', () {
      final metadata = OAuthServerMetadata.fromJson({
        'issuer': 'https://auth.example.com',
        'authorization_endpoint': 'https://auth.example.com/authorize',
        'token_endpoint': 'https://auth.example.com/token',
        'registration_endpoint': 'https://auth.example.com/register',
        'response_types_supported': ['code'],
        'token_endpoint_auth_methods_supported': [
          'client_secret_basic',
          'none',
        ],
        'code_challenge_methods_supported': ['S256'],
        'client_id_metadata_document_supported': true,
      });
      expect(metadata.issuer, 'https://auth.example.com');
      expect(
        metadata.registrationEndpoint,
        'https://auth.example.com/register',
      );
      expect(metadata.responseTypesSupported, ['code']);
      expect(metadata.tokenEndpointAuthMethodsSupported, contains('none'));
      expect(metadata.codeChallengeMethodsSupported, ['S256']);
      expect(metadata.clientIdMetadataDocumentSupported, isTrue);
    });
  });

  group('OAuthException', () {
    test('isInvalidClient detects invalid_client', () {
      expect(
        const OAuthException('invalid_client', 'bad').isInvalidClient,
        isTrue,
      );
    });

    test('isInvalidClient detects unauthorized_client', () {
      expect(
        const OAuthException('unauthorized_client', 'bad').isInvalidClient,
        isTrue,
      );
    });

    test('isInvalidGrant detects invalid_grant', () {
      expect(
        const OAuthException('invalid_grant', 'expired').isInvalidGrant,
        isTrue,
      );
    });

    test('isServerError detects server_error', () {
      expect(
        const OAuthException('server_error', 'oops').isServerError,
        isTrue,
      );
    });

    test('fromResponse constructs from OAuthErrorResponse', () {
      final error = OAuthException.fromResponse(
        const OAuthErrorResponse(
          error: 'access_denied',
          errorDescription: 'denied!',
        ),
      );
      expect(error.code, 'access_denied');
      expect(error.message, 'denied!');
    });
  });

  group('OAuthClientMetadata', () {
    test('toJson serializes correctly', () {
      const meta = OAuthClientMetadata(
        redirectUris: ['https://app.example.com/callback'],
        grantTypes: ['authorization_code'],
        clientName: 'My App',
        scope: 'read write',
      );
      final json = meta.toJson();
      expect(json['redirect_uris'], ['https://app.example.com/callback']);
      expect(json['grant_types'], ['authorization_code']);
      expect(json['client_name'], 'My App');
      expect(json['scope'], 'read write');
      expect(json.containsKey('software_id'), isFalse);
    });
  });

  group('isAuthorizationServerUrlAllowed (default)', () {
    late _MinimalProvider provider;

    setUp(() {
      provider = _MinimalProvider();
    });

    test('allows same origin', () async {
      expect(
        await provider.isAuthorizationServerUrlAllowed(
          Uri.parse('https://api.example.com/mcp'),
          Uri.parse('https://api.example.com/oauth'),
        ),
        isTrue,
      );
    });

    test('rejects cross-origin host', () async {
      expect(
        await provider.isAuthorizationServerUrlAllowed(
          Uri.parse('https://api.example.com/mcp'),
          Uri.parse('https://evil.example.com/oauth'),
        ),
        isFalse,
      );
    });

    test('rejects different port', () async {
      expect(
        await provider.isAuthorizationServerUrlAllowed(
          Uri.parse('https://api.example.com/mcp'),
          Uri.parse('https://api.example.com:8443/oauth'),
        ),
        isFalse,
      );
    });

    test('rejects different scheme', () async {
      expect(
        await provider.isAuthorizationServerUrlAllowed(
          Uri.parse('https://api.example.com/mcp'),
          Uri.parse('http://api.example.com/oauth'),
        ),
        isFalse,
      );
    });
  });
}
