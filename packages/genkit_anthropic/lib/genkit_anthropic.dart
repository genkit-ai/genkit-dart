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
import 'src/model.dart';
import 'src/plugin_impl.dart';
import 'src/vertex_config.dart';

export 'src/model.dart';
export 'src/vertex_config.dart';

/// An instance of [AnthropicPluginHandle] that provides entry points into the plugin.
const AnthropicPluginHandle anthropic = AnthropicPluginHandle();

/// Plugin handle for the Genkit Anthropic integration.
class AnthropicPluginHandle {
  /// Internal constructor. Use the exported [anthropic] instance.
  const AnthropicPluginHandle();

  /// Initializes the Anthropic plugin for use with Genkit.
  ///
  /// You can optionally provide an [apiKey]. If omitted, it will be mapped
  /// to the standard `ANTHROPIC_API_KEY` environment variable.
  ///
  /// To use Claude models hosted on Vertex AI, provide [vertex].
  GenkitPlugin call({String? apiKey, AnthropicVertexConfig? vertex}) {
    return AnthropicPluginImpl(apiKey: apiKey, vertex: vertex);
  }

  /// Returns a [ModelRef] for the specified Anthropic model [name].
  ModelRef<AnthropicOptions> model(String name) {
    return modelRef('anthropic/$name', customOptions: AnthropicOptions.$schema);
  }
}
