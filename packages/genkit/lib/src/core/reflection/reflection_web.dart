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

import '../reflection.dart';
import '../registry.dart';
import 'reflection_v2.dart';

const _v2ServerEnvKey = 'GENKIT_REFLECTION_V2_SERVER';
const _runtimeIdEnvKey = 'GENKIT_RUNTIME_ID';

ReflectionServerHandle startReflectionServer(Registry registry, {int? port}) {
  const v2ServerUrl = String.fromEnvironment(
    _v2ServerEnvKey,
    defaultValue: '',
  );
  const runtimeId = String.fromEnvironment(
    _runtimeIdEnvKey,
    defaultValue: '',
  );
  if (v2ServerUrl == '') {
    throw UnimplementedError(
      'GENKIT_REFLECTION_V2_SERVER environment variable is not set',
    );
  }
  final server = ReflectionServerV2(
    registry,
    url: v2ServerUrl,
    runtimeId: runtimeId,
  );
  server.start();
  return ReflectionServerHandle(server.stop);
}
