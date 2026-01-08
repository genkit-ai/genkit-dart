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

import 'package:opentelemetry/sdk.dart' as sdk;

class TextExporter implements sdk.SpanExporter {
  var _isShutdown = false;
  final List<sdk.ReadOnlySpan> spans = [];

  @override
  void export(List<sdk.ReadOnlySpan> spans) {
    if (_isShutdown) {
      return;
    }
    this.spans.addAll(spans);
  }

  void reset() {
    spans.clear();
  }

  @Deprecated(
    'This method will be removed in 0.19.0. Use [SpanProcessor] instead.',
  )
  @override
  void forceFlush() {
    return;
  }

  @override
  void shutdown() {
    _isShutdown = true;
  }
}
