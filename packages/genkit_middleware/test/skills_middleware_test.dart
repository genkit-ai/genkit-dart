import 'dart:io';
import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('SkillsMiddleware', () {
    late Genkit genkit;
    late Directory skillsDir;

    setUp(() async {
      genkit = Genkit(isDevEnv: false, plugins: [SkillsPlugin()]);
      skillsDir = await Directory.systemTemp.createTemp('genkit_skills_test');

      // Create a test skill
      final testSkillDir = Directory(p.join(skillsDir.path, 'test_skill'));
      await testSkillDir.create();
      await File(p.join(testSkillDir.path, 'SKILL.md')).writeAsString('''
---
description: A test description.
---
This is a test skill.
''');
    });

    tearDown(() async {
      await genkit.shutdown();
      if (await skillsDir.exists()) {
        await skillsDir.delete(recursive: true);
      }
    });

    test('should inject use_skill tool and list skills', () async {
      final mw = skills(skillPaths: [skillsDir.path]);

      genkit.defineModel(
        name: 'test-model',
        fn: (req, ctx) async {
          // Verify system message
          final systemMessage = req.messages.first;
          expect(systemMessage.role, Role.system);
          final text = systemMessage.content.first.text;
          expect(text, contains('test_skill'));
          expect(text, contains('A test description.'));

          // Call the tool
          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Skill content received')],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'use_skill',
                    input: {'skillName': 'test_skill'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('test-model'),
        prompt: 'help me',
        use: [mw],
      );

      // Verify that the tool was executed and the result is in the history
      final toolMessage = result.messages.firstWhere(
        (m) => m.role == Role.tool,
      );
      final toolResponse = toolMessage.content.first.toolResponse!;
      expect(toolResponse.name, 'use_skill');
      expect(toolResponse.output, contains('description: A test description.'));
      expect(toolResponse.output, contains('This is a test skill.'));
    });

    test('use_skill tool should return skill content', () async {
      final mw = SkillsMiddleware([skillsDir.path]);
      final tools = mw.tools;
      final useSkillTool = tools.firstWhere((t) => t.name == 'use_skill');

      final output = await useSkillTool.runRaw({'skillName': 'test_skill'});
      expect(output.result, contains('description: A test description.'));
      expect(output.result, contains('This is a test skill.'));
    });

    test('should work via plugin registration', () async {
      final genkitWithPlugin = Genkit(
        plugins: [SkillsPlugin()],
        isDevEnv: false,
      );

      genkitWithPlugin.defineModel(
        name: 'test-model',
        fn: (req, ctx) async {
          // Verify system message contains skills
          final systemMessage = req.messages.firstWhere(
            (m) => m.role == Role.system,
          );
          expect(
            systemMessage.content.any(
              (p) => p.text?.contains('<skills>') == true,
            ),
            isTrue,
          );

          if (req.messages.any((m) => m.role == Role.tool)) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Skill content received')],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                ToolRequestPart(
                  toolRequest: ToolRequest(
                    name: 'use_skill',
                    input: {'skillName': 'test_skill'},
                  ),
                ),
              ],
            ),
          );
        },
      );

      // Use the middleware ref
      final result = await genkitWithPlugin.generate(
        model: modelRef('test-model'),
        prompt: 'help me via plugin',
        use: [
          skills(skillPaths: [skillsDir.path]),
        ],
      );

      // Verify that the tool was executed and the result is in the history
      final toolMessage = result.messages.firstWhere(
        (m) => m.role == Role.tool,
      );
      final toolResponse = toolMessage.content.first.toolResponse!;
      expect(toolResponse.name, 'use_skill');
      expect(toolResponse.output, contains('description: A test description.'));
      expect(toolResponse.output, contains('This is a test skill.'));
    });

    test('should merge with existing system message', () async {
      final mw = skills(skillPaths: [skillsDir.path]);

      genkit.defineModel(
        name: 'system-check-model',
        fn: (req, ctx) async {
          // Verify merged system message
          final systemMessage = req.messages.first;
          expect(systemMessage.role, Role.system);
          expect(systemMessage.content.length, greaterThan(1));
          expect(systemMessage.content[0].text, 'Existing system instruction');
          expect(systemMessage.content.last.text, contains('<skills>'));

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'ok')],
            ),
          );
        },
      );

      await genkit.generate(
        model: modelRef('system-check-model'),
        prompt: 'hello',
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'Existing system instruction')],
          ),
        ],
        use: [mw],
      );
    });
    test(
      'should NOT duplicate skill metadata upon repeated generate calls (idempotency)',
      () async {
        final mw = skills(skillPaths: [skillsDir.path]);

        var executionCount = 0;
        genkit.defineModel(
          name: 'idempotent-model',
          fn: (req, ctx) async {
            executionCount++;

            var skillsTagCount = 0;
            for (final msg in req.messages) {
              for (final part in msg.content) {
                if (part.isText) {
                  final hasTags = part.text!.contains('<skills>');
                  if (hasTags) {
                    skillsTagCount++;
                  }
                }
              }
            }

            expect(
              skillsTagCount,
              equals(1),
              reason:
                  'Skills metadata should not be duplicated on turn $executionCount',
            );

            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'ok')],
              ),
            );
          },
        );

        final result1 = await genkit.generate(
          model: modelRef('idempotent-model'),
          prompt: 'First call',
          use: [mw],
        );

        await genkit.generate(
          model: modelRef('idempotent-model'),
          prompt: 'Second call',
          messages: result1.messages,
          use: [mw],
        );

        expect(executionCount, equals(2));
      },
    );
  });
}
