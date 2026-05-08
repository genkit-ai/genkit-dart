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

import '../core/registry.dart';
import 'dotprompt_registry.dart';

/// Stub implementation of [loadPromptFolder].
///
/// This is the default fallback used when neither `dart:io` nor
/// `dart:js_interop` is available. It throws [UnimplementedError] because
/// prompt loading from the filesystem is not supported on this platform.
void loadPromptFolder(
  Registry registry,
  DotpromptRegistry dotpromptRegistry, {
  String dir = './prompts',
  String ns = '',
}) {
  throw UnimplementedError(
    'loadPromptFolder is not supported on this platform.',
  );
}
