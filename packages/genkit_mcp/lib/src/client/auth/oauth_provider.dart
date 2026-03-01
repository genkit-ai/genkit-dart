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

import 'oauth_types.dart';

/// Callback for applying custom client authentication to token requests.
///
/// Implementations modify [headers] and/or [params] to include client
/// credentials (e.g., JWT bearer assertions, custom schemes).
typedef OAuthClientAuthenticator =
    Future<void> Function(
      Map<String, String> headers,
      Map<String, String> params,
      Uri url,
      OAuthServerMetadata? metadata,
    );

/// Callback for validating and selecting the RFC 8707 resource indicator URL.
typedef OAuthResourceURLValidator =
    Future<Uri?> Function(Uri serverUrl, String? resource);

/// Implements an end-to-end OAuth client for use with one MCP server.
///
/// This provider relies upon a concept of an authorized "session," the exact
/// meaning of which is application-defined. Tokens, authorization codes, and
/// code verifiers should not cross different sessions.
///
/// Modeled after the TypeScript MCP SDK's `OAuthClientProvider`.
abstract class OAuthClientProvider {
  /// The URL to redirect the user agent to after authorization.
  ///
  /// Return `null` for non-interactive flows that don't require user
  /// interaction (e.g., `client_credentials`, `jwt-bearer`).
  Uri? get redirectUrl;

  /// Metadata about this OAuth client, used for dynamic registration.
  OAuthClientMetadata get clientMetadata;

  /// Loads saved client information (from prior registration), or returns
  /// `null` if the client has not been registered yet.
  Future<OAuthClientInformation?> clientInformation();

  /// Loads any existing OAuth tokens for the current session, or returns
  /// `null` if there are no saved tokens.
  Future<OAuthTokens?> tokens();

  /// Stores new OAuth tokens after a successful authorization.
  Future<void> saveTokens(OAuthTokens tokens);

  /// Invoked to redirect the user agent to begin the authorization flow.
  Future<void> redirectToAuthorization(Uri authorizationUrl);

  /// Saves a PKCE code verifier before redirecting to authorization.
  Future<void> saveCodeVerifier(String codeVerifier);

  /// Loads the PKCE code verifier for the current session.
  Future<String> codeVerifier();

  // --- Optional overrides with defaults ---

  /// External URL the server should use to fetch a client metadata document.
  String? get clientMetadataUrl => null;

  /// Returns an OAuth 2.0 `state` parameter value for CSRF protection.
  Future<String?> state() async => null;

  /// Saves client information received from dynamic registration.
  ///
  /// Override this to persist client information.  The default is a no-op.
  Future<void> saveClientInformation(OAuthClientInformation info) async {}

  /// Invalidates stored credentials after a recoverable OAuth error.
  ///
  /// Override to clear cached credentials.  The default is a no-op.
  Future<void> invalidateCredentials(OAuthInvalidationScope scope) async {}

  /// Prepares grant-specific parameters for a token request.
  ///
  /// Return a map of parameters including `grant_type`, or `null` to use
  /// the default `authorization_code` flow.
  Future<Map<String, String>?> prepareTokenRequest(String? scope) async => null;

  /// Optional custom client authentication callback.
  ///
  /// When non-null, this is called instead of the default authentication
  /// logic for token requests.
  OAuthClientAuthenticator? get customClientAuthentication => null;

  /// Optional resource URL validator.
  ///
  /// When non-null, overrides the default RFC 8707 resource indicator
  /// selection and validation.
  OAuthResourceURLValidator? get resourceURLValidator => null;
}
