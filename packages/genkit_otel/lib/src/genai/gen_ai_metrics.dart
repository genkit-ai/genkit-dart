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

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart' as otel;

import 'gen_ai_attributes.dart';

/// The two spec-defined GenAI client metrics, recorded per model operation.
///
/// See the spec:
/// https://github.com/open-telemetry/semantic-conventions-genai
///
/// Instruments are created lazily from the meter so nothing is allocated until
/// the first model call, and so this stays a no-op when the SDK is not
/// initialized (the meter returns non-recording instruments).
class GenAiMetrics {
  GenAiMetrics(this._meter);

  final otel.APIMeter _meter;

  // Explicit token-count buckets recommended by the spec for the token-usage
  // histogram; the duration histogram uses the default seconds buckets.
  static const _tokenBuckets = <double>[
    1,
    4,
    16,
    64,
    256,
    1024,
    4096,
    16384,
    65536,
    262144,
    1048576,
    4194304,
    16777216,
    67108864,
  ];

  late final otel.APIHistogram<int> _tokenUsage = _meter.createHistogram<int>(
    name: GenAiMetric.tokenUsage,
    unit: '{token}',
    description: 'Number of input and output tokens used by the model.',
    boundaries: _tokenBuckets,
  );

  late final otel.APIHistogram<double> _operationDuration = _meter
      .createHistogram<double>(
        name: GenAiMetric.operationDuration,
        unit: 's',
        description: 'Duration of a GenAI model operation.',
      );

  /// Records input/output token counts, one point per non-null count, tagged
  /// with `gen_ai.token.type`.
  void recordTokenUsage({
    required Map<String, Object> baseAttributes,
    int? inputTokens,
    int? outputTokens,
  }) {
    if (inputTokens != null) {
      _tokenUsage.recordWithMap(inputTokens, {
        ...baseAttributes,
        GenAiAttr.tokenType: 'input',
      });
    }
    if (outputTokens != null) {
      _tokenUsage.recordWithMap(outputTokens, {
        ...baseAttributes,
        GenAiAttr.tokenType: 'output',
      });
    }
  }

  /// Records the operation duration in seconds. Recorded for both successful
  /// and failed operations (failures carry `error.type` in [attributes]).
  void recordDuration(double seconds, Map<String, Object> attributes) {
    _operationDuration.recordWithMap(seconds, attributes);
  }
}
