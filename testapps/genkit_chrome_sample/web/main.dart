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

final _validationError =
    web.document.querySelector('#validation-error') as web.HTMLDivElement;

// Model params
int? _defaultTopK;
int? _maxTopK;
double? _defaultTemperature;
double? _maxTemperature;

void main() async {
  final ai = Genkit(plugins: [genkit_chrome.ChromeAIPlugin()]);

  // Fetch model params if available
  try {
    final params = await genkit_chrome.ChromeModel.getParams();
    _defaultTopK = params.defaultTopK;
    _maxTopK = params.maxTopK;
    _defaultTemperature = params.defaultTemperature.toDouble();
    _maxTemperature = params.maxTemperature.toDouble();

    _topKInput.placeholder = 'default: $_defaultTopK (1-$_maxTopK)';
    _topKInput.max = '$_maxTopK';

    _temperatureInput.placeholder =
        'default: $_defaultTemperature (0.0-${_maxTemperature!.toStringAsFixed(1)})';
    _temperatureInput.max = '$_maxTemperature';

    // Update titles for help icons
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
  } catch (e) {
    print('Error fetching model params: $e');
  }

  _generateBtn.onClick.listen((event) => _submit(ai));

  _promptInput.onKeyDown.listen((event) {
    if (event.key == 'Enter' && !event.shiftKey) {
      event.preventDefault();
      _submit(ai);
    }
  });

  // Validation listeners
  _temperatureInput.onInput.listen((_) => _validateInputs());
  _topKInput.onInput.listen((_) => _validateInputs());

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
    _generateBtn.disabled = false;
  }
}

bool _running = false;

final _outputDiv =
    web.document.querySelector('#chat-container') as web.HTMLDivElement;
final _promptInput =
    web.document.querySelector('#prompt') as web.HTMLTextAreaElement;
final _generateBtn =
    web.document.querySelector('#generate') as web.HTMLButtonElement;

final _systemPromptInput =
    web.document.querySelector('#systemPrompt') as web.HTMLTextAreaElement;
final _temperatureInput =
    web.document.querySelector('#temperature') as web.HTMLInputElement;
final _topKInput = web.document.querySelector('#topK') as web.HTMLInputElement;

final List<Message> _history = [];

Future<void> _submit(Genkit ai) async {
  final prompt = _promptInput.value.trim();
  if (prompt.isEmpty) return;
  if (_running) return;

  // Re-validate to be safe (though button should be disabled)
  _validateInputs();
  if (_validationError.style.display == 'block') return;

  _running = true;
  // Disable input while running
  _promptInput.disabled = true;
  _generateBtn.disabled = true;

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

    // Update system prompt in history if it changed or is new
    // For simplicity in this sample, we'll just prepend it if it exists
    // A more robust app might manage system prompt as a distinct state

    try {
      final settingsList = <String>[];
      if (systemPrompt.isNotEmpty) {
        settingsList.add('System Prompt: $systemPrompt');
      }
      if (temperature != null &&
          _defaultTemperature != null &&
          temperature != _defaultTemperature) {
        settingsList.add('Temperature: $temperature');
      }
      if (topK != null && _defaultTopK != null && topK != _defaultTopK) {
        settingsList.add('Top K: $topK');
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
        await ai.generate(
          model: modelRef('chrome/gemini-nano'),
          messages: _history,
          config: {
            if (systemPrompt.isNotEmpty) 'systemPrompt': systemPrompt,
            'temperature': ?temperature,
            'topK': ?topK,
          },
          onChunk: (chunk) {
            if (buffer.isEmpty) {
              loadingSpan.remove(); // Remove loading indicator on first chunk
            }
            final text = chunk.text;
            buffer.write(text);
            contentDiv.innerHTML = markdownToHtml(buffer.toString()).toJS;
            _scrollToBottom();
          },
        );
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
        _scrollToBottom();
      }
    } catch (e, stack) {
      _appendMessage('System', 'Error: $e\n$stack');
      print('Error: $e\n$stack');
    }
  } finally {
    _running = false;
    _promptInput.disabled = false;
    _generateBtn.disabled = false;
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
