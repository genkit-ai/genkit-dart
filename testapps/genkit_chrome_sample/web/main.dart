import 'package:genkit/lite.dart';
import 'package:genkit_chrome/genkit_chrome.dart' as genkit_chrome;
import 'package:web/web.dart' as web;

void main() {
  final outputDiv =
      web.document.querySelector('#chat-container') as web.HTMLDivElement;
  final promptInput =
      web.document.querySelector('#prompt') as web.HTMLTextAreaElement;
  final generateBtn =
      web.document.querySelector('#generate') as web.HTMLButtonElement;

  void scrollToBottom() {
    outputDiv.scrollTop = outputDiv.scrollHeight.toDouble();
  }

  web.HTMLDivElement appendMessage(String speaker, String text) {
    final row = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'message-row';

    final speakerDiv = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'speaker'
      ..innerText = speaker;

    final contentDiv = web.document.createElement('div') as web.HTMLDivElement
      ..className = 'content'
      ..innerText = text;

    row.appendChild(speakerDiv);
    row.appendChild(contentDiv);
    outputDiv.appendChild(row);
    scrollToBottom();
    return contentDiv;
  }

  Future<void> submit() async {
    final prompt = promptInput.value.trim();
    if (prompt.isEmpty) return;

    appendMessage('User', prompt);
    promptInput.value = '';

    try {
      final contentDiv = appendMessage('Model', '');
      final loadingSpan =
          web.document.createElement('span') as web.HTMLSpanElement
            ..innerText = ' ...';
      contentDiv.appendChild(loadingSpan);
      scrollToBottom();

      try {
        await generate(
          model: genkit_chrome.ChromeModel(),
          prompt: prompt,
          onChunk: (chunk) {
            final text = chunk.text;
            loadingSpan.before(web.Text(text));
            scrollToBottom();
          },
        );
      } finally {
        loadingSpan.remove();
        scrollToBottom();
      }
    } catch (e, stack) {
      appendMessage('System', 'Error: $e\n$stack');
      print('Error: $e\n$stack');
    }
  }

  generateBtn.onClick.listen((event) => submit());

  promptInput.onKeyDown.listen((event) {
    if (event.key == 'Enter' && !event.shiftKey) {
      event.preventDefault();
      submit();
    }
  });

  // Focus input on load
  promptInput.disabled = false;
  generateBtn.disabled = false;
  promptInput.placeholder = 'Type a message... (Shift+Enter for newline)';
  promptInput.focus();
}
