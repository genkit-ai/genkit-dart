import 'dart:js_interop';

@JS('LanguageModel')
external LanguageModelFactory? get languageModel;

@JS()
extension type LanguageModelFactory._(JSObject _) implements JSObject {
  /// Returns the availability of the language model.
  ///
  /// Returns a promise that resolves to "readily", "after-download", or "no".
  external JSPromise<JSString> availability();

  /// Creates a new session with the language model.
  external JSPromise<LanguageModel> create([LanguageModelOptions? options]);
}

@JS()
extension type LanguageModelOptions._(JSObject _) implements JSObject {
  external factory LanguageModelOptions({
    num? temperature,
    num? topK,
    String? systemPrompt,
  });
}

@JS()
extension type LanguageModel._(JSObject _) implements JSObject {
  /// Prompts the model with the given input.
  external JSPromise<JSString> prompt(String input);

  /// Prompts the model with the given input and returns a streaming response.
  external ReadableStream promptStreaming(String input);

  /// Destroys the session.
  external void destroy();

  // Clone is also available but we might not use it yet
  external JSPromise<LanguageModel> clone();
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
