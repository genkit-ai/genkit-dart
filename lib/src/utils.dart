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

import 'dart:io' as io;

const bool kIsWeb = bool.fromEnvironment('dart.library.js_util');

String? getEnvVar(String name) {
  if (kIsWeb) {
     if (Uri.base.queryParameters.containsKey(name)) {
      return Uri.base.queryParameters[name];
     }

    return null;
  } else {
    return io.Platform.environment[name];
  }
}

String getPid() {
  return kIsWeb ? 'web' : '${io.pid}';
}
