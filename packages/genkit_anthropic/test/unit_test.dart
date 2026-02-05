import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:test/test.dart';

void main() {
  group('toAnthropicMessage', () {
    test('should map TextPart correctly', () {
      final input = Message(
        role: Role.user,
        content: [TextPart(text: 'Hello')],
      );
      final result = toAnthropicMessage(input);
      expect(result.role, anthropic.MessageRole.user);
      final content = result.content;
      // Accessing .blocks directly as seen in plugin_impl.dart
      expect(content.blocks.first, isA<anthropic.Block>());
      final block = content.blocks.first;
      block.map(
        text: (b) => expect(b.type, 'text'),
        toolUse: (_) => fail('Should be text'),
        thinking: (_) => fail('Should be text'),
        toolResult: (_) => fail('Should be text'),
        image: (_) => fail('Should be text'),
        redactedThinking: (_) => fail('Should be text'),
        codeExecutionToolResult: (_) => fail('Should be text'),
        containerUpload: (_) => fail('Should be text'),
        document: (_) => fail('Should be text'),
        mCPToolResult: (_) => fail('Should be text'),
        mCPToolUse: (_) => fail('Should be text'),
        searchResult: (_) => fail('Should be text'),
        serverToolUse: (_) => fail('Should be text'),
        webSearchToolResult: (_) => fail('Should be text'),
      );
    });

    test('should filter ReasoningPart from input', () {
      final input = Message(
        role: Role.user,
        content: [
          TextPart(text: 'Hello'),
          ReasoningPart(reasoning: 'thinking...'),
        ],
      );
      final result = toAnthropicMessage(input);
      expect(result.content.blocks.length, 1); // Should only have TextPart
    });
  });

  group('fromAnthropicMessage', () {
    test('should map ThinkingBlock to ReasoningPart with signature', () {
      final input = anthropic.Message(
        id: 'msg_123',
        type: 'message',
        role: anthropic.MessageRole.assistant,
        content: anthropic.MessageContent.blocks([
          anthropic.Block.thinking(
            type: anthropic.ThinkingBlockType.thinking,
            thinking: 'Hmm',
            signature: 'sig_123',
          ),
          anthropic.Block.text(text: 'Hello'),
        ]),
        model: 'claude-3-5-sonnet',
        usage: anthropic.Usage(inputTokens: 10, outputTokens: 5),
      );

      final result = fromAnthropicMessage(input);
      expect(result.content.length, 2);

      // Use JSON check for ReasoningPart due to schemantic type erasure in generic lists
      final reasoningPart = result.content[0].toJson();
      expect(reasoningPart['reasoning'], 'Hmm');
      expect((reasoningPart['metadata'] as Map?)?['signature'], 'sig_123');

      final textPart = result.content[1].toJson();
      expect(textPart['text'], 'Hello');
    });
  });
}
