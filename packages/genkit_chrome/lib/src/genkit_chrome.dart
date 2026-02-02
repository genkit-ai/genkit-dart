import 'package:genkit/core.dart';

import 'chrome_model.dart';

export 'chrome_interop.dart';
export 'chrome_model.dart';

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
