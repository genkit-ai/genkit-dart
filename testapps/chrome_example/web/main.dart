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
import 'package:genkit/genkit.dart';
import 'package:genkit_chrome/genkit_chrome.dart' as genkit_chrome;
import 'package:markdown/markdown.dart';
import 'package:web/web.dart' as web;

// JSON.parse — used to convert a JSON Schema string into a JS object.
@JS('JSON.parse')
external JSAny _jsonParse(JSString json);

// JS RegExp constructor — used to build a regex constraint.
@JS('RegExp')
extension type _JSRegExp._(JSObject _) implements JSObject {
  external factory _JSRegExp(JSString pattern);
}

final _validationError =
    web.document.querySelector('#validation-error') as web.HTMLDivElement;

// Model params — null when params() is unavailable (requires an extension
// context or the Prompt API Sampling Parameters origin trial).
int? _defaultTopK;
int? _maxTopK;
double? _defaultTemperature;
double? _maxTemperature;

void main() async {
  final ai = Genkit(plugins: [genkit_chrome.ChromeAIPlugin()]);

  // params() is only available in extension contexts or with the Prompt API
  // Sampling Parameters origin trial enabled; resolves to null otherwise.
  // Be defensive: treat null as "params unavailable".
  try {
    final params = await genkit_chrome.ChromeModel.getParams();
    if (params != null) {
      _defaultTopK = params.defaultTopK;
      _maxTopK = params.maxTopK;
      _defaultTemperature = params.defaultTemperature.toDouble();
      _maxTemperature = params.maxTemperature.toDouble();

      _topKInput.placeholder = 'default: $_defaultTopK (1-$_maxTopK)';
      _topKInput.max = '$_maxTopK';

      _temperatureInput.placeholder =
          'default: $_defaultTemperature (0.0-${_maxTemperature!.toStringAsFixed(1)})';
      _temperatureInput.max = '$_maxTemperature';

      web.document
          .querySelector('label[for="topK"] .help-icon')
          ?.setAttribute(
            'title',
            'Controls diversity. Lower values limit the token pool. '
                'Valid range: 1-$_maxTopK. Default: $_defaultTopK.',
          );
      web.document
          .querySelector('label[for="temperature"] .help-icon')
          ?.setAttribute(
            'title',
            'Controls randomness. Lower values are more deterministic. '
                'Valid range: 0-$_maxTemperature. Default: $_defaultTemperature.',
          );
    } else {
      // params() is unavailable (no extension context or origin trial) —
      // disable the fields so users can't set values the browser would reject.
      _topKInput.disabled = true;
      _topKInput.placeholder = 'unavailable';
      _temperatureInput.disabled = true;
      _temperatureInput.placeholder = 'unavailable';
    }
  } catch (e) {
    print('Error fetching model params: $e');
  }

  _generateBtn.onClick.listen((event) => _submit(ai));
  _stopBtn.onClick.listen((_) => _currentController?.abort());
  _resetBtn.onClick.listen((_) => _resetSession());
  _resetSettingsBtn.onClick.listen((_) => _resetSettings());

  _promptInput.onKeyDown.listen((event) {
    if (event.key == 'Enter' && !event.shiftKey) {
      event.preventDefault();
      _submit(ai);
    }
  });

  // Validation listeners
  _temperatureInput.onInput.listen((_) => _validateInputs());
  _topKInput.onInput.listen((_) => _validateInputs());

  // Session-hint listeners: system prompt and language selectors affect the
  // session and require a reset to take effect mid-conversation.
  _systemPromptInput.onInput.listen((_) => _updateSessionHint());
  _expectedInputLanguages.onChange.listen((_) => _updateSessionHint());
  _expectedOutputLanguages.onChange.listen((_) => _updateSessionHint());

  // Constraint listeners: show/hide textarea, update placeholder, validate.
  _constraintType.onChange.listen((_) {
    if (_constraintType.value != 'none') {
      _constraintInput.placeholder = _constraintType.value == 'json'
          ? '{"type":"object","properties":{"answer":{"type":"string"}},"required":["answer"]}'
          : r'^[A-Za-z ]+$';
    }
    _validateConstraint();
  });
  _constraintInput.onInput.listen((_) => _validateConstraint());

  // Focus input on load
  _promptInput.disabled = false;
  _generateBtn.disabled = false;
  _promptInput.placeholder = 'Type a message... (Shift+Enter for newline)';
  _promptInput.focus();
}

void _validateInputs() {
  final tempStr = _temperatureInput.value;
  final topKStr = _topKInput.value;

  String? error;

  if (tempStr.isNotEmpty) {
    final temp = double.tryParse(tempStr);
    if (temp == null ||
        temp < 0 ||
        (_maxTemperature != null && temp > _maxTemperature!)) {
      error = 'Temperature must be between 0 and $_maxTemperature';
      _temperatureInput.classList.add('invalid');
    } else {
      _temperatureInput.classList.remove('invalid');
    }
  } else {
    _temperatureInput.classList.remove('invalid');
  }

  if (topKStr.isNotEmpty) {
    final topK = int.tryParse(topKStr);
    if (topK == null) {
      if (double.tryParse(topKStr) != null) {
        error = 'Top K must be an integer';
      } else {
        error = 'Top K must be a valid integer';
      }
      _topKInput.classList.add('invalid');
    } else if (topK < 1 || (_maxTopK != null && topK > _maxTopK!)) {
      error = 'Top K must be between 1 and $_maxTopK';
      _topKInput.classList.add('invalid');
    } else {
      _topKInput.classList.remove('invalid');
    }
  } else {
    _topKInput.classList.remove('invalid');
  }

  // Cross-validation: enforce both or neither
  if (error == null) {
    if (tempStr.isNotEmpty && topKStr.isEmpty) {
      error = 'Both Temperature and Top K must be set if one is used.';
      _topKInput.classList.add('invalid');
    } else if (topKStr.isNotEmpty && tempStr.isEmpty) {
      error = 'Both Temperature and Top K must be set if one is used.';
      _temperatureInput.classList.add('invalid');
    }
  }

  if (error != null) {
    _validationError.innerText = error;
    _validationError.style.display = 'block';
    _generateBtn.disabled = true;
  } else {
    _validationError.style.display = 'none';
    _generateBtn.disabled = _constraintHasError;
  }
}

bool _running = false;
web.AbortController? _currentController;

final _outputDiv =
    web.document.querySelector('#chat-container') as web.HTMLDivElement;
final _promptInput =
    web.document.querySelector('#prompt') as web.HTMLTextAreaElement;
final _generateBtn =
    web.document.querySelector('#generate') as web.HTMLButtonElement;
final _stopBtn = web.document.querySelector('#stop') as web.HTMLButtonElement;
final _resetBtn = web.document.querySelector('#reset') as web.HTMLButtonElement;
final _resetSettingsBtn =
    web.document.querySelector('#reset-settings') as web.HTMLButtonElement;
final _sessionHint =
    web.document.querySelector('#session-hint') as web.HTMLDivElement;
final _tokenText =
    web.document.querySelector('#token-text') as web.HTMLSpanElement;
final _tokenFill =
    web.document.querySelector('#token-fill') as web.HTMLDivElement;
final _downloadProgress =
    web.document.querySelector('#download-progress') as web.HTMLDivElement;
final _downloadText =
    web.document.querySelector('#download-text') as web.HTMLSpanElement;
final _downloadFill =
    web.document.querySelector('#download-bar-fill') as web.HTMLDivElement;

final _systemPromptInput =
    web.document.querySelector('#systemPrompt') as web.HTMLTextAreaElement;
final _temperatureInput =
    web.document.querySelector('#temperature') as web.HTMLInputElement;
final _topKInput = web.document.querySelector('#topK') as web.HTMLInputElement;
final _expectedInputLanguages =
    web.document.querySelector('#expectedInputLanguages')
        as web.HTMLSelectElement;
final _expectedOutputLanguages =
    web.document.querySelector('#expectedOutputLanguages')
        as web.HTMLSelectElement;
final _constraintType =
    web.document.querySelector('#constraintType') as web.HTMLSelectElement;
final _constraintInput =
    web.document.querySelector('#constraintInput') as web.HTMLTextAreaElement;
final _constraintError =
    web.document.querySelector('#constraint-error') as web.HTMLDivElement;

final List<Message> _history = [];

// Settings committed at the start of the current session (first message sent
// or after a manual reset). Used to detect when a new session is needed.
String _sessionSystemPrompt = '';
List<String> _sessionInputLangs = [];
List<String> _sessionOutputLangs = [];

List<String> _parseSelectedLangs(web.HTMLSelectElement selectElement) {
  final selected = <String>[];
  final options = selectElement.selectedOptions;
  for (var i = 0; i < options.length; i++) {
    selected.add((options.item(i) as web.HTMLOptionElement).value);
  }
  return selected;
}

void _updateSessionHint() {
  if (_history.isEmpty) {
    _sessionHint.style.display = 'none';
    return;
  }
  final changed =
      _systemPromptInput.value.trim() != _sessionSystemPrompt ||
      _parseSelectedLangs(_expectedInputLanguages).join(',') !=
          _sessionInputLangs.join(',') ||
      _parseSelectedLangs(_expectedOutputLanguages).join(',') !=
          _sessionOutputLangs.join(',');
  _sessionHint.style.display = changed ? 'block' : 'none';
}

bool _constraintHasError = false;

void _validateConstraint() {
  final type = _constraintType.value;

  if (type == 'none') {
    _constraintInput.style.display = 'none';
    _constraintError.style.display = 'none';
    _constraintInput.classList.remove('invalid');
    _constraintHasError = false;
    _validateInputs();
    return;
  }

  _constraintInput.style.display = 'block';
  final text = _constraintInput.value.trim();

  if (text.isEmpty) {
    _constraintError.style.display = 'none';
    _constraintInput.classList.remove('invalid');
    _constraintHasError = false;
    _validateInputs();
    return;
  }

  String? err;
  try {
    if (type == 'json') {
      _jsonParse(text.toJS);
    } else {
      _JSRegExp(text.toJS);
    }
  } catch (_) {
    err = type == 'json' ? 'Invalid JSON.' : 'Invalid regular expression.';
  }

  _constraintHasError = err != null;
  if (err != null) {
    _constraintError.innerText = err;
    _constraintError.style.display = 'block';
    _constraintInput.classList.add('invalid');
  } else {
    _constraintError.style.display = 'none';
    _constraintInput.classList.remove('invalid');
  }
  _validateInputs();
}

JSAny? _buildConstraint() {
  final type = _constraintType.value;
  if (type == 'none') return null;
  final text = _constraintInput.value.trim();
  if (text.isEmpty) return null;
  if (type == 'json') return _jsonParse(text.toJS);
  return _JSRegExp(text.toJS);
}

void _updateTokenStats(GenerationUsage? usage) {
  final used = usage?.inputTokens?.toInt();
  final max = (usage?.custom?['contextWindow'] as num?)?.toInt();
  if (used == null) return;

  final text = max != null && max > 0
      ? 'Context: $used / $max tokens'
      : 'Context: $used tokens';
  _tokenText.innerText = text;

  if (max != null && max > 0) {
    final pct = (used / max * 100).clamp(0.0, 100.0);
    _tokenFill.style.width = '$pct%';
    _tokenFill.className = pct >= 90
        ? 'danger'
        : pct >= 75
        ? 'warn'
        : '';
  }
}

void _resetTokenStats() {
  _tokenText.innerText = 'Context: — tokens';
  _tokenFill.style.width = '0%';
  _tokenFill.className = '';
}

void _showDownloadProgress(int loaded, int total) {
  _downloadProgress.style.display = 'block';
  if (total > 0) {
    final pct = (loaded / total * 100).clamp(0.0, 100.0);
    _downloadText.innerText = 'Downloading model: ${pct.toStringAsFixed(0)}%';
    _downloadFill.style.width = '${pct.toStringAsFixed(1)}%';
    _downloadFill.classList.remove('indeterminate');
  } else {
    _downloadText.innerText = 'Downloading model...';
    _downloadFill.style.width = '0%';
    _downloadFill.classList.add('indeterminate');
  }
}

void _hideDownloadProgress() {
  _downloadProgress.style.display = 'none';
  _downloadFill.style.width = '0%';
  _downloadFill.classList.remove('indeterminate');
}

void _resetSettings() {
  _systemPromptInput.value = '';

  // Only clear if the fields are enabled (i.e. params() was available).
  if (!_temperatureInput.disabled) _temperatureInput.value = '';
  if (!_topKInput.disabled) _topKInput.value = '';

  // Reset language selects to English only.
  for (final select in [_expectedInputLanguages, _expectedOutputLanguages]) {
    final options = select.options;
    for (var i = 0; i < options.length; i++) {
      final opt = options.item(i) as web.HTMLOptionElement;
      opt.selected = opt.value == 'en';
    }
  }

  // Reset response constraint.
  _constraintType.value = 'none';
  _constraintInput.value = '';
  _constraintInput.style.display = 'none';
  _constraintError.style.display = 'none';
  _constraintInput.classList.remove('invalid');
  _constraintHasError = false;

  _validateInputs();
  _updateSessionHint();
}

void _resetSession() {
  _currentController?.abort();
  _history.clear();
  while (_outputDiv.firstChild != null) {
    _outputDiv.removeChild(_outputDiv.firstChild!);
  }
  _sessionHint.style.display = 'none';
  _resetTokenStats();
}

Future<void> _submit(Genkit ai) async {
  final prompt = _promptInput.value.trim();
  if (prompt.isEmpty) return;
  if (_running) return;

  // Re-validate to be safe (though button should be disabled)
  _validateInputs();
  if (_validationError.style.display == 'block') return;

  _running = true;
  _currentController = web.AbortController();
  _promptInput.disabled = true;
  _generateBtn.disabled = true;
  _stopBtn.style.display = 'block';

  try {
    _appendMessage('User', prompt);
    _history.add(
      Message(
        role: Role.user,
        content: [TextPart(text: prompt)],
      ),
    );
    _promptInput.value = '';

    // Read settings
    final systemPrompt = _systemPromptInput.value.trim();
    final temperature = double.tryParse(_temperatureInput.value);
    final topK = int.tryParse(_topKInput.value);
    final inputLangs = _parseSelectedLangs(_expectedInputLanguages);
    final outputLangs = _parseSelectedLangs(_expectedOutputLanguages);

    // Commit session settings on the first message so we can detect drift.
    if (_history.length == 1) {
      _sessionSystemPrompt = systemPrompt;
      _sessionInputLangs = inputLangs;
      _sessionOutputLangs = outputLangs;
      _sessionHint.style.display = 'none';
    }

    try {
      final settingsList = <String>[];
      if (systemPrompt.isNotEmpty) {
        settingsList.add('System Prompt: $systemPrompt');
      }
      if (temperature != null) {
        settingsList.add('Temperature: $temperature');
      }
      if (topK != null) {
        settingsList.add('Top K: $topK');
      }
      if (inputLangs.isNotEmpty) {
        settingsList.add('Input Langs: ${inputLangs.join(", ")}');
      }
      if (outputLangs.isNotEmpty) {
        settingsList.add('Output Langs: ${outputLangs.join(", ")}');
      }

      final constraint = _buildConstraint();
      final constraintTypeValue = _constraintType.value;
      final constraintText = _constraintInput.value.trim();
      if (constraint != null) {
        settingsList.add('Constraint ($constraintTypeValue): $constraintText');
      }

      final contentDiv = _appendMessage(
        'Model',
        '',
        settingsInfo: settingsList.isEmpty ? null : settingsList.join('\n'),
      );
      final buffer = StringBuffer();
      // Placeholder while waiting for first chunk
      final loadingSpan =
          web.document.createElement('span') as web.HTMLSpanElement
            ..innerText = ' ...';
      contentDiv.appendChild(loadingSpan);
      _scrollToBottom();

      try {
        final response = await ai.generate(
          model: modelRef('chrome/gemini-nano'),
          messages: _history,
          config: {
            if (systemPrompt.isNotEmpty) 'systemPrompt': systemPrompt,
            'temperature': ?temperature,
            'topK': ?topK,
            if (inputLangs.isNotEmpty)
              'expectedInputs': [
                {'type': 'text', 'languages': inputLangs},
              ],
            if (outputLangs.isNotEmpty)
              'expectedOutputs': [
                {'type': 'text', 'languages': outputLangs},
              ],
            'signal': _currentController!.signal,
            'responseConstraint': ?constraint,
            'onDownloadProgress': _showDownloadProgress,
          },
          onChunk: (chunk) {
            if (buffer.isEmpty) {
              loadingSpan.remove(); // Remove loading indicator on first chunk
              _hideDownloadProgress();
            }
            final text = chunk.text;
            buffer.write(text);
            contentDiv.innerHTML = markdownToHtml(buffer.toString()).toJS;
            _scrollToBottom();
          },
        );
        _updateTokenStats(response.usage);
        _history.add(
          Message(
            role: Role.model,
            content: [TextPart(text: buffer.toString())],
          ),
        );
      } finally {
        if (buffer.isEmpty) {
          loadingSpan.remove();
        }
        _hideDownloadProgress();
        _scrollToBottom();
      }
    } catch (e, stack) {
      // Suppress errors caused by a user-initiated stop.
      if (_currentController?.signal.aborted != true) {
        _appendMessage('System', 'Error: $e\n$stack');
        print('Error: $e\n$stack');
      }
    }
  } finally {
    _running = false;
    _currentController = null;
    _promptInput.disabled = false;
    _generateBtn.disabled = false;
    _stopBtn.style.display = 'none';
  }
}

void _scrollToBottom() {
  _outputDiv.scrollTop = _outputDiv.scrollHeight.toDouble();
}

web.HTMLDivElement _appendMessage(
  String speaker,
  String text, {
  String? settingsInfo,
}) {
  final row = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'message-row ${speaker.toLowerCase()}';

  final speakerDiv = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'speaker'
    ..innerText = speaker;

  if (settingsInfo != null) {
    final helpIcon = web.document.createElement('span') as web.HTMLSpanElement
      ..className = 'help-icon'
      ..innerText = '?'
      ..title = settingsInfo;
    speakerDiv.appendChild(helpIcon);
  }

  final contentDiv = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'content'
    ..innerText = text;

  row.appendChild(speakerDiv);
  row.appendChild(contentDiv);
  _outputDiv.appendChild(row);
  _scrollToBottom();
  return contentDiv;
}
