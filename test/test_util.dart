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
