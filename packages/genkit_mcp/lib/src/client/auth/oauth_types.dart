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

/// OAuth 2.1 token response.
final class OAuthTokens {
  final String accessToken;
  final String tokenType;
  final int? expiresIn;
  final String? scope;
  final String? refreshToken;

  const OAuthTokens({
    required this.accessToken,
    required this.tokenType,
    this.expiresIn,
    this.scope,
    this.refreshToken,
  });

  factory OAuthTokens.fromJson(Map<String, dynamic> json) {
    return OAuthTokens(
      accessToken: json['access_token'] as String,
      tokenType: json['token_type'] as String,
      expiresIn: json['expires_in'] as int?,
      scope: json['scope'] as String?,
      refreshToken: json['refresh_token'] as String?,
    );
  }

  OAuthTokens copyWith({String? refreshToken}) {
    return OAuthTokens(
      accessToken: accessToken,
      tokenType: tokenType,
      expiresIn: expiresIn,
      scope: scope,
      refreshToken: refreshToken ?? this.refreshToken,
    );
  }
}

/// RFC 7591 Dynamic Client Registration metadata.
final class OAuthClientMetadata {
  final List<String> redirectUris;
  final String? tokenEndpointAuthMethod;
  final List<String>? grantTypes;
  final List<String>? responseTypes;
  final String? clientName;
  final String? clientUri;
  final String? scope;
  final String? softwareId;
  final String? softwareVersion;

  const OAuthClientMetadata({
    required this.redirectUris,
    this.tokenEndpointAuthMethod,
    this.grantTypes,
    this.responseTypes,
    this.clientName,
    this.clientUri,
    this.scope,
    this.softwareId,
    this.softwareVersion,
  });

  Map<String, dynamic> toJson() {
    return {
      'redirect_uris': redirectUris,
      if (tokenEndpointAuthMethod != null)
        'token_endpoint_auth_method': tokenEndpointAuthMethod,
      if (grantTypes != null) 'grant_types': grantTypes,
      if (responseTypes != null) 'response_types': responseTypes,
      if (clientName != null) 'client_name': clientName,
      if (clientUri != null) 'client_uri': clientUri,
      if (scope != null) 'scope': scope,
      if (softwareId != null) 'software_id': softwareId,
      if (softwareVersion != null) 'software_version': softwareVersion,
    };
  }
}

/// RFC 7591 client information (registration response).
final class OAuthClientInformation {
  final String clientId;
  final String? clientSecret;
  final int? clientIdIssuedAt;
  final int? clientSecretExpiresAt;
  final String? tokenEndpointAuthMethod;

  const OAuthClientInformation({
    required this.clientId,
    this.clientSecret,
    this.clientIdIssuedAt,
    this.clientSecretExpiresAt,
    this.tokenEndpointAuthMethod,
  });

  factory OAuthClientInformation.fromJson(Map<String, dynamic> json) {
    return OAuthClientInformation(
      clientId: json['client_id'] as String,
      clientSecret: json['client_secret'] as String?,
      clientIdIssuedAt: json['client_id_issued_at'] as int?,
      clientSecretExpiresAt: json['client_secret_expires_at'] as int?,
      tokenEndpointAuthMethod: json['token_endpoint_auth_method'] as String?,
    );
  }
}

/// RFC 8414 OAuth 2.0 Authorization Server Metadata.
final class OAuthServerMetadata {
  final String issuer;
  final String authorizationEndpoint;
  final String tokenEndpoint;
  final String? registrationEndpoint;
  final List<String>? scopesSupported;
  final List<String> responseTypesSupported;
  final List<String>? grantTypesSupported;
  final List<String>? tokenEndpointAuthMethodsSupported;
  final List<String>? codeChallengeMethodsSupported;
  final bool? clientIdMetadataDocumentSupported;

  const OAuthServerMetadata({
    required this.issuer,
    required this.authorizationEndpoint,
    required this.tokenEndpoint,
    this.registrationEndpoint,
    this.scopesSupported,
    required this.responseTypesSupported,
    this.grantTypesSupported,
    this.tokenEndpointAuthMethodsSupported,
    this.codeChallengeMethodsSupported,
    this.clientIdMetadataDocumentSupported,
  });

  factory OAuthServerMetadata.fromJson(Map<String, dynamic> json) {
    return OAuthServerMetadata(
      issuer: json['issuer'] as String,
      authorizationEndpoint: json['authorization_endpoint'] as String,
      tokenEndpoint: json['token_endpoint'] as String,
      registrationEndpoint: json['registration_endpoint'] as String?,
      scopesSupported: _stringList(json['scopes_supported']),
      responseTypesSupported:
          _stringList(json['response_types_supported']) ?? const [],
      grantTypesSupported: _stringList(json['grant_types_supported']),
      tokenEndpointAuthMethodsSupported: _stringList(
        json['token_endpoint_auth_methods_supported'],
      ),
      codeChallengeMethodsSupported: _stringList(
        json['code_challenge_methods_supported'],
      ),
      clientIdMetadataDocumentSupported:
          json['client_id_metadata_document_supported'] as bool?,
    );
  }
}

/// RFC 9728 OAuth 2.0 Protected Resource Metadata.
final class OAuthProtectedResourceMetadata {
  final String resource;
  final List<String>? authorizationServers;
  final List<String>? scopesSupported;

  const OAuthProtectedResourceMetadata({
    required this.resource,
    this.authorizationServers,
    this.scopesSupported,
  });

  factory OAuthProtectedResourceMetadata.fromJson(Map<String, dynamic> json) {
    return OAuthProtectedResourceMetadata(
      resource: json['resource'] as String,
      authorizationServers: _stringList(json['authorization_servers']),
      scopesSupported: _stringList(json['scopes_supported']),
    );
  }
}

/// OAuth 2.1 error response.
final class OAuthErrorResponse {
  final String error;
  final String? errorDescription;
  final String? errorUri;

  const OAuthErrorResponse({
    required this.error,
    this.errorDescription,
    this.errorUri,
  });

  factory OAuthErrorResponse.fromJson(Map<String, dynamic> json) {
    return OAuthErrorResponse(
      error: json['error'] as String,
      errorDescription: json['error_description'] as String?,
      errorUri: json['error_uri'] as String?,
    );
  }
}

/// Possible results from the OAuth authorization flow.
enum AuthResult { authorized, redirect }

/// Scope of credentials to invalidate during error recovery.
enum OAuthInvalidationScope { all, client, tokens, verifier }

/// Exception thrown when an OAuth error occurs.
final class OAuthException implements Exception {
  final String code;
  final String message;

  const OAuthException(this.code, this.message);

  factory OAuthException.fromResponse(OAuthErrorResponse response) {
    return OAuthException(
      response.error,
      response.errorDescription ?? response.error,
    );
  }

  bool get isInvalidClient =>
      code == 'invalid_client' || code == 'unauthorized_client';
  bool get isInvalidGrant => code == 'invalid_grant';
  bool get isServerError => code == 'server_error';

  @override
  String toString() => 'OAuthException($code): $message';
}

/// Exception thrown when authorization is required but not available.
final class UnauthorizedError implements Exception {
  final String message;

  const UnauthorizedError([this.message = 'Unauthorized']);

  @override
  String toString() => 'UnauthorizedError: $message';
}

/// Parameters extracted from a WWW-Authenticate response header.
final class WwwAuthenticateParams {
  final Uri? resourceMetadataUrl;
  final String? scope;
  final String? error;

  const WwwAuthenticateParams({
    this.resourceMetadataUrl,
    this.scope,
    this.error,
  });
}

List<String>? _stringList(Object? value) {
  if (value is List) return value.cast<String>();
  return null;
}
