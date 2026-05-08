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

import 'package:dotprompt/dotprompt.dart' as dp;
import 'package:handlebars_dart/handlebars_dart.dart' show HelperFunction;

/// A wrapper around the dotprompt [dp.Dotprompt] instance for integration
/// with the Genkit registry.
///
/// This class manages the lifecycle of the Dotprompt instance, providing
/// methods for parsing, compiling, and rendering prompt templates, as well
/// as registering partials and helpers.
class DotpromptRegistry {
  final dp.Dotprompt _dotprompt;

  DotpromptRegistry([dp.DotpromptOptions? options])
      : _dotprompt = dp.Dotprompt(options);

  /// The underlying [dp.Dotprompt] instance.
  dp.Dotprompt get dotprompt => _dotprompt;

  /// Parses a prompt template source into a [dp.ParsedPrompt].
  dp.ParsedPrompt parse(String source) => _dotprompt.parse(source);

  /// Compiles a template for repeated rendering.
  Future<dp.PromptFunction> compile(String source) =>
      _dotprompt.compile(source);

  /// Renders a prompt template with the provided data.
  Future<dp.RenderedPrompt> render(
    String source,
    dp.DataArgument data, [
    Map<String, dynamic>? options,
  ]) =>
      _dotprompt.render(source, data, options);

  /// Renders metadata for a template without rendering the full template.
  Future<dp.PromptMetadata> renderMetadata(String source) =>
      _dotprompt.renderMetadata(source);

  /// Defines a partial template.
  void definePartial(String name, String source) {
    _dotprompt.definePartial(name, source);
  }

  /// Defines a custom helper function.
  void defineHelper(String name, HelperFunction helper) {
    _dotprompt.defineHelper(name, helper);
  }
}
