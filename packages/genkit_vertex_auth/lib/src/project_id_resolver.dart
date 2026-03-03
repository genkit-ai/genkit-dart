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

import '_project_id_resolver_stub.dart'
    if (dart.library.io) '_project_id_resolver_io.dart'
    as project_id;

/// Resolves a project ID from common Google Cloud environment variables.
String? resolveEnvironmentProjectId() {
  return project_id.resolveEnvironmentProjectId();
}

/// Extracts `project_id` from service account credentials JSON.
///
/// Returns null when [credentialsJson] is not parseable or does not include a
/// non-empty `project_id` string.
String? extractProjectIdFromServiceAccountJson(Object credentialsJson) {
  Map<String, dynamic>? json;
  if (credentialsJson is Map) {
    json = Map<String, dynamic>.from(credentialsJson);
  } else if (credentialsJson is String) {
    try {
      final decoded = jsonDecode(credentialsJson);
      if (decoded is Map) {
        json = Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return null;
    }
  }

  final projectId = json?['project_id'];
  if (projectId is String && projectId.trim().isNotEmpty) {
    return projectId.trim();
  }
  return null;
}
