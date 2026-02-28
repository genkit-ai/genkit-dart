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

import 'package:schemantic/schemantic.dart';

part 'model.g.dart';

/// Generation options specific to Anthropic models.
@Schematic()
abstract class $AnthropicOptions {
  /// Custom API key to use for this specific request. Overrides plugin config.
  ///
  /// This field is only valid for direct Anthropic API usage and is rejected
  /// when the plugin is configured for Vertex AI.
  String? get apiKey;

  @IntegerField(
    minimum: 1,
    description: 'The maximum number of tokens to generate before stopping.',
  )
  int? get maxTokens;

  @DoubleField(
    minimum: 0.0,
    maximum: 1.0,
    description:
        'Amount of randomness injected into the response. '
        'Ranges from 0.0 to 1.0. Use temperature closer to 0.0 for analytical / '
        'multiple choice, and closer to 1.0 for creative and generative tasks.',
  )
  double? get temperature;

  @DoubleField(
    minimum: 0.0,
    maximum: 1.0,
    description:
        'Use nucleus sampling. '
        'In nucleus sampling, we compute the cumulative distribution over all the '
        'options for each subsequent token in decreasing probability order and '
        'cut it off once it reaches a particular probability specified by top_p.',
  )
  double? get topP;

  @IntegerField(
    minimum: 0,
    description:
        'Only sample from the top K options for each subsequent token.',
  )
  int? get topK;

  /// Stop sequences to use for this generation.
  List<String>? get stopSequences;

  /// Extended thinking configuration for support Anthropic models (like Claude 3.7 Sonnet).
  $ThinkingConfig? get thinking;
}

/// Configuration for Anthropic's extended thinking mode.
@Schematic()
abstract class $ThinkingConfig {
  @IntegerField(
    minimum: 1024,
    description:
        'Determines how many tokens Claude can use for its internal reasoning process. '
        'Larger budgets allow for more extensive thought but increase latency and cost. '
        'The budget must be at least 1024 tokens and cannot exceed the model\'s max_tokens limit.',
  )
  int get budgetTokens;
}
