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

import 'template_helper.dart';

/// Callback type for resolving named schemas.
///
/// Given a schema [name], returns the JSON Schema map if found,
/// or `null` if the schema is not registered.
typedef SchemaResolver = Future<Map<String, dynamic>?> Function(String name);

/// A wrapper around the dotprompt [dp.Dotprompt] instance for integration
/// with the Genkit registry.
///
/// This class manages the lifecycle of the Dotprompt instance, providing
/// methods for parsing, compiling, and rendering prompt templates, as well
/// as registering partials, helpers, and schemas.
class DotpromptRegistry {
  final dp.Dotprompt _dotprompt;

  DotpromptRegistry({
    dp.DotpromptOptions? options,
    SchemaResolver? schemaResolver,
  }) : _dotprompt = dp.Dotprompt(
         dp.DotpromptOptions(
           defaultModel: options?.defaultModel,
           modelConfigs: options?.modelConfigs,
           helpers: options?.helpers,
           partials: options?.partials,
           tools: options?.tools,
           schemas: options?.schemas,
           partialResolver: options?.partialResolver,
           toolResolver: options?.toolResolver,
           schemaResolver: schemaResolver ?? options?.schemaResolver,
           store: options?.store,
         ),
       );

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
  ]) => _dotprompt.render(source, data, options);

  /// Renders metadata for a template without rendering the full template.
  Future<dp.PromptMetadata> renderMetadata(String source) =>
      _dotprompt.renderMetadata(source);

  /// Defines a partial template.
  void definePartial(String name, String source) {
    _dotprompt.definePartial(name, source);
  }

  /// Defines a custom helper function.
  void defineHelper(String name, TemplateHelperFn helper) {
    _dotprompt.defineHelper(name, wrapTemplateHelper(helper));
  }

  /// Registers a named schema for use in prompt templates.
  ///
  /// Named schemas can be referenced by name in Picoschema definitions
  /// within prompt templates (e.g., in `input.schema` or `output.schema`
  /// frontmatter fields).
  void defineSchema(String name, Map<String, dynamic> schema) {
    _dotprompt.defineSchema(name, schema);
  }
}
