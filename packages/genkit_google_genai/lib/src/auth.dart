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

import 'package:genkit_vertex_auth/genkit_vertex_auth.dart';
import 'package:http/http.dart' as http;

class VertexAuthClient extends http.BaseClient {
  final AccessTokenProvider _tokenProvider;
  final http.BaseClient _inner;

  VertexAuthClient(
    this._tokenProvider, {
    http.BaseClient? inner,
  }) : _inner = inner ?? http.Client();
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final token = await _tokenProvider();
    request.headers['Authorization'] = 'Bearer ${token.trim()}';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
  }
}
