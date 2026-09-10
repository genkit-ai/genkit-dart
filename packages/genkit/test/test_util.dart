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

import 'package:genkit/src/o11y/telemetry/span_data.dart';

/// A [TelemetrySink] that records exported spans and logs in memory for
/// assertions.
///
/// The direct-HTTP instrumentation exports each span twice: once when it starts
/// (with `endTimeUnixNano == 0`) and once when it finishes. [spans] holds every
/// export; use [finished] to filter to completed spans.
class RecordingSpanSink implements TelemetrySink {
  final List<GenkitSpanData> spans = [];
  final List<GenkitLogData> logs = [];
  var _isShutdown = false;

  @override
  void export(List<GenkitSpanData> spans) {
    if (_isShutdown) return;
    this.spans.addAll(spans);
  }

  @override
  void exportLogs(List<GenkitLogData> logs) {
    if (_isShutdown) return;
    this.logs.addAll(logs);
  }

  void reset() {
    spans.clear();
    logs.clear();
  }

  @override
  void shutdown() => _isShutdown = true;

  /// Only the finished span exports (those with a non-zero end time).
  List<GenkitSpanData> get finished =>
      spans.where((s) => s.endTimeUnixNano > 0).toList();

  /// Returns the single finished span with [name], failing if absent.
  GenkitSpanData byName(String name) =>
      finished.firstWhere((s) => s.name == name);
}
