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
import 'package:genkit/lite.dart';
import 'package:genkit_chrome/genkit_chrome.dart' as genkit_chrome;
import 'package:markdown/markdown.dart';
import 'package:web/web.dart' as web;

void main() {
  _generateBtn.onClick.listen((event) => _submit());

  _promptInput.onKeyDown.listen((event) {
    if (event.key == 'Enter' && !event.shiftKey) {
      event.preventDefault();
      _submit();
    }
  });

  // Focus input on load
  _promptInput.disabled = false;
  _generateBtn.disabled = false;
  _promptInput.placeholder = 'Type a message... (Shift+Enter for newline)';
  _promptInput.focus();
}

bool _running = false;

final _outputDiv =
    web.document.querySelector('#chat-container') as web.HTMLDivElement;
final _promptInput =
    web.document.querySelector('#prompt') as web.HTMLTextAreaElement;
final _generateBtn =
    web.document.querySelector('#generate') as web.HTMLButtonElement;

Future<void> _submit() async {
  final prompt = _promptInput.value.trim();
  if (prompt.isEmpty) return;
  if (_running) return;
  _running = true;
  // Disable input while running
  _promptInput.disabled = true;
  _generateBtn.disabled = true;

  try {
    _appendMessage('User', prompt);
    _promptInput.value = '';

    try {
      final contentDiv = _appendMessage('Model', '');
      final buffer = StringBuffer();
      // Placeholder while waiting for first chunk
      final loadingSpan =
          web.document.createElement('span') as web.HTMLSpanElement
            ..innerText = ' ...';
      contentDiv.appendChild(loadingSpan);
      _scrollToBottom();

      try {
        await generate(
          model: genkit_chrome.ChromeModel(),
          prompt: prompt,
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

web.HTMLDivElement _appendMessage(String speaker, String text) {
  final row = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'message-row ${speaker.toLowerCase()}';

  final speakerDiv = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'speaker'
    ..innerText = speaker;

  final contentDiv = web.document.createElement('div') as web.HTMLDivElement
    ..className = 'content'
    ..innerText = text;

  row.appendChild(speakerDiv);
  row.appendChild(contentDiv);
  _outputDiv.appendChild(row);
  _scrollToBottom();
  return contentDiv;
}
