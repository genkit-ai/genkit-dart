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
import 'package:http/http.dart' as http;

Future<String> Function() createAdcTokenProvider({
  required List<String> scopes,
  http.Client? baseClient,
}) {
  return () async {
    throw GenkitException(
      'Anthropic Vertex ADC auth is only supported on Dart IO platforms.',
      status: StatusCodes.UNIMPLEMENTED,
    );
  };
}

Future<String> Function() createServiceAccountTokenProvider({
  required Object credentialsJson,
  required List<String> scopes,
  String? impersonatedUser,
  http.Client? baseClient,
}) {
  return () async {
    throw GenkitException(
      'Anthropic Vertex service account auth is only supported on Dart IO platforms.',
      status: StatusCodes.UNIMPLEMENTED,
    );
  };
}
