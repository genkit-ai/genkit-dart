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
import 'dart:math';

import 'package:crypto/crypto.dart';

/// A PKCE (Proof Key for Code Exchange) challenge pair.
final class PkceChallenge {
  final String codeVerifier;
  final String codeChallenge;

  const PkceChallenge({
    required this.codeVerifier,
    required this.codeChallenge,
  });

  /// Generates a cryptographically secure PKCE challenge using the S256 method.
  factory PkceChallenge.generate() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final codeVerifier = base64Url.encode(bytes).replaceAll('=', '');
    final digest = sha256.convert(utf8.encode(codeVerifier));
    final codeChallenge = base64Url.encode(digest.bytes).replaceAll('=', '');
    return PkceChallenge(
      codeVerifier: codeVerifier,
      codeChallenge: codeChallenge,
    );
  }
}
