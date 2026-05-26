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

import 'package:handlebars_dart/handlebars_dart.dart' as hb;

/// Options passed to template helper functions during rendering.
///
/// Contains hash arguments, block content functions, and context data
/// available to helpers.
///
/// ## Block Helper Example
///
/// ```dart
/// ai.defineHelper('list', (args, options) {
///   final items = args[0] as List;
///   final buffer = StringBuffer('<ul>');
///   for (final item in items) {
///     buffer.write('<li>${options.fn(item)}</li>');
///   }
///   buffer.write('</ul>');
///   return buffer.toString();
/// });
/// ```
class TemplateHelperOptions {
  /// Named hash arguments: `{{helper key="value" other=123}}`.
  ///
  /// Accessed as `options.hash['key']` and `options.hash['other']`.
  final Map<String, dynamic> hash;

  /// The block content function for block helpers.
  ///
  /// Call `fn(context)` to render the block content with a given context.
  /// For non-block helpers, this returns an empty string.
  ///
  /// Example: `{{#each items}}...{{/each}}`
  final String Function(dynamic context) fn;

  /// The inverse/else block content function.
  ///
  /// Call `inverse(context)` to render the `{{else}}` content.
  /// Returns empty string if no else block is present.
  ///
  /// Example: `{{#if condition}}...{{else}}...{{/if}}`
  final String Function(dynamic context) inverse;

  /// Private data for the current rendering frame.
  ///
  /// Contains special variables like `@root`, `@first`, `@last`, `@index`.
  final Map<String, dynamic> data;

  /// The current context (this) value for the helper.
  final dynamic context;

  /// Creates template helper options.
  TemplateHelperOptions({
    required this.hash,
    required this.fn,
    required this.inverse,
    required this.data,
    required this.context,
  });

  /// Creates a [TemplateHelperOptions] from the internal
  /// [hb.HelperOptions] type.
  TemplateHelperOptions._fromHandlebars(hb.HelperOptions options)
    : hash = options.hash,
      fn = options.fn,
      inverse = options.inverse,
      data = options.data,
      context = options.context;
}

/// Function signature for custom Handlebars helper functions.
///
/// Helpers receive:
/// - [args]: Positional arguments from the template
/// - [options]: Hash arguments, block functions, and context
///
/// Helpers should return a value that will be inserted into the template
/// output.
///
/// ## Example
///
/// ```dart
/// ai.defineHelper('loud', (args, options) {
///   return args[0].toString().toUpperCase();
/// });
/// // Usage in template: {{loud name}}
/// ```
typedef TemplateHelperFn =
    dynamic Function(List<dynamic> args, TemplateHelperOptions options);

/// Wraps a Genkit-owned [TemplateHelperFn] into the internal
/// [hb.HelperFunction] type expected by the Handlebars engine.
hb.HelperFunction wrapTemplateHelper(TemplateHelperFn helper) {
  return (List<dynamic> args, hb.HelperOptions options) {
    return helper(args, TemplateHelperOptions._fromHandlebars(options));
  };
}
