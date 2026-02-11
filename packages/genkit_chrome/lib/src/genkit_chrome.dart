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

import 'chrome_model.dart';

export 'chrome_interop.dart' show LanguageModelParams;
export 'chrome_model.dart' show ChromeModel;

const ChromeAIPluginHandle chromeAI = ChromeAIPluginHandle();

class ChromeAIPluginHandle {
  const ChromeAIPluginHandle();

  ChromeAIPlugin call() => ChromeAIPlugin();
}

class ChromeAIPlugin extends GenkitPlugin {
  @override
  String get name => 'chrome';

  @override
  Future<List<ActionMetadata>> list() async {
    // We can check availability here
    // But listing usually just returns what *could* be available.
    return [
      modelMetadata(
        'chrome/gemini-nano',
        modelInfo: ModelInfo(supports: {'multiturn': true, 'systemRole': true}),
      ),
    ];
  }

  @override
  ChromeModel? resolve(String actionType, String name) {
    if (actionType == 'model' && name == 'gemini-nano') {
      return ChromeModel();
    }
    return null;
  }
}
