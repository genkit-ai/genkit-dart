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

import 'package:genkit/genkit.dart';

/// Default model info for standard OpenAI models
ModelInfo defaultModelInfo(String model) {
  return ModelInfo(
    label: model,
    supports: {
      'multiturn': true,
      'tools': true,
      'systemRole': true,
      'media': supportsVision(model),
    },
  );
}

/// Model info for o1/o3 reasoning models
ModelInfo o1ModelInfo() {
  return ModelInfo(
    label: 'o1',
    supports: {
      'multiturn': true,
      'tools': false, // o1 doesn't support tools yet
      'systemRole': false, // o1 uses developer messages instead
      'media': false,
    },
  );
}

/// Check if a model supports vision (image inputs)
bool supportsVision(String model) {
  return model.contains('gpt-4o') ||
      model.contains('gpt-4-turbo') ||
      model.contains('gpt-4-vision');
}
