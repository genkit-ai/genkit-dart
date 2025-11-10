import 'dart:io';

import 'package:genkit/schema.dart';
import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/flow.dart';
import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/registry.dart';

export 'package:genkit/src/o11y/otlp_http_exporter.dart' show configureCollectorExporter;


bool _isDevEnv() {
  return Platform.environment['GENKIT_ENV'] == 'dev';
}

class Genkit {
  final Registry registry = Registry();
  ReflectionServer? _reflectionServer;

  Genkit({bool? isDevEnv}) {
    if (isDevEnv ?? _isDevEnv()) {
      _reflectionServer = ReflectionServer(registry);
      _reflectionServer!.start();
    }
  }

  Future<void> shutdown() async {
    await _reflectionServer?.stop();
  }

  Flow<I, O, S> defineFlow<I, O, S>({
    required String name,
    required ActionFn<I, O, S> fn,
    JsonExtensionType<I>? inputType,
    JsonExtensionType<O>? outputType,
    JsonExtensionType<S>? streamType,
  }) {
    final flow = Flow(
      name: name,
      fn: fn,
      inputType: inputType,
      outputType: outputType,
      streamType: streamType,
    );
    registry.register(flow);
    return flow;
  }
}
