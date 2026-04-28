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

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

@JS('LanguageModel')
external LanguageModelFactory? get languageModelImpl;

@JS()
extension type LanguageModelFactory._(JSObject _) implements JSObject {
  /// Returns the availability of the language model.
  ///
  /// Returns a promise that resolves to "available", "downloadable",
  /// "downloading", or "unavailable".
  external JSPromise<JSString> availability([LanguageModelOptions? options]);

  /// Creates a new session with the language model.
  external JSPromise<LanguageModel> create([LanguageModelOptions? options]);

  /// Returns the limits of the language model.
  ///
  /// Deprecated: only available in extension contexts or with the Prompt API
  /// Sampling Parameters origin trial enabled; resolves to null otherwise.
  external JSPromise<LanguageModelParams?> params();
}

@JS()
extension type LanguageModelParams._(JSObject _) implements JSObject {
  external int get defaultTopK;
  external int get maxTopK;
  external num get defaultTemperature;
  external num get maxTemperature;
}

@JS()
extension type LanguageModelOptions._(JSObject _) implements JSObject {
  factory LanguageModelOptions({
    num? temperature,
    num? topK,
    List<LanguageModelInitialPrompt>? initialPrompts,
    String? systemPrompt,
    List<LanguageModelExpectedInput>? expectedInputs,
    List<LanguageModelExpectedOutput>? expectedOutputs,
    void Function(int loaded, int total)? onDownloadProgress,
  }) {
    final options = JSObject();
    if (temperature != null) options['temperature'] = temperature.toJS;
    if (topK != null) options['topK'] = topK.toJS;

    // Build the final initialPrompts list: system prompt must be first.
    final allPrompts = <LanguageModelInitialPrompt>[];
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      allPrompts.add(
        LanguageModelInitialPrompt(role: 'system', content: systemPrompt),
      );
    }
    if (initialPrompts != null && initialPrompts.isNotEmpty) {
      allPrompts.addAll(initialPrompts);
    }
    if (allPrompts.isNotEmpty) {
      options['initialPrompts'] = allPrompts.toJS;
    }

    if (expectedInputs != null && expectedInputs.isNotEmpty) {
      options['expectedInputs'] = expectedInputs.toJS;
    }
    if (expectedOutputs != null && expectedOutputs.isNotEmpty) {
      options['expectedOutputs'] = expectedOutputs.toJS;
    }

    if (onDownloadProgress != null) {
      final cb = onDownloadProgress;
      void monitorFn(JSAny? monitorObj) {
        if (monitorObj == null) return;
        final m = monitorObj as JSObject;
        void progressFn(JSAny? eventObj) {
          if (eventObj == null) return;
          final e = eventObj as JSObject;
          final loaded = (e['loaded'] as JSNumber?)?.toDartDouble.toInt() ?? 0;
          final total = (e['total'] as JSNumber?)?.toDartDouble.toInt() ?? 0;
          cb(loaded, total);
        }

        m['ondownloadprogress'] = progressFn.toJS;
      }

      options['monitor'] = monitorFn.toJS;
    }

    return options as LanguageModelOptions;
  }

  external num? get temperature;
  external num? get topK;
  external JSArray<LanguageModelInitialPrompt>? get initialPrompts;
  external JSArray<LanguageModelExpectedInput>? get expectedInputs;
  external JSArray<LanguageModelExpectedOutput>? get expectedOutputs;
}

@JS()
extension type LanguageModelExpectedInput._(JSObject _) implements JSObject {
  external factory LanguageModelExpectedInput({
    String type,
    JSArray<JSString>? languages,
  });
}

@JS()
extension type LanguageModelExpectedOutput._(JSObject _) implements JSObject {
  external factory LanguageModelExpectedOutput({
    String type,
    JSArray<JSString>? languages,
  });
}

@JS()
extension type LanguageModelInitialPrompt._(JSObject _) implements JSObject {
  external factory LanguageModelInitialPrompt({String role, String content});
}

@JS()
extension type LanguageModelPromptOptions._(JSObject _) implements JSObject {
  factory LanguageModelPromptOptions({
    JSObject? signal,
    JSAny? responseConstraint,
  }) {
    final options = JSObject();
    if (signal != null) options['signal'] = signal;
    if (responseConstraint != null) {
      options['responseConstraint'] = responseConstraint;
    }
    return options as LanguageModelPromptOptions;
  }
}

@JS()
extension type LanguageModel._(JSObject _) implements JSObject {
  /// Prompts the model with the given input.
  external JSPromise<JSString> prompt(
    String input, [
    LanguageModelPromptOptions? options,
  ]);

  /// Prompts the model with the given input and returns a streaming response.
  external ReadableStream promptStreaming(
    String input, [
    LanguageModelPromptOptions? options,
  ]);

  /// Destroys the session.
  external void destroy();

  external JSPromise<LanguageModel> clone();

  /// Tokens consumed by the current context.
  external double? get contextUsage;

  /// Maximum context window size.
  external double? get contextWindow;
}

@JS()
extension type ReadableStream._(JSObject _) implements JSObject {
  external ReadableStreamDefaultReader getReader();
}

@JS()
extension type ReadableStreamDefaultReader._(JSObject _) implements JSObject {
  external JSPromise<ReadableStreamReadResult> read();
  external void releaseLock();
}

@JS()
extension type ReadableStreamReadResult._(JSObject _) implements JSObject {
  external JSBoolean get done;
  external JSString? get value;
}
