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

import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('FilesystemMiddleware', () {
    late Directory tempDir;
    late Genkit genkit;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('genkit_fs_test');
      genkit = Genkit(isDevEnv: false, plugins: [FilesystemPlugin()]);
    });

    tearDown(() async {
      await genkit.shutdown();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('should list contents of a directory', () async {
      await File(p.join(tempDir.path, 'file1.txt')).create();
      await Directory(p.join(tempDir.path, 'subdir')).create();

      final mw = FilesystemMiddleware(tempDir.path);
      final tools = mw.tools;
      final listTool = tools.firstWhere((t) => t.name == 'list_files');

      final result = await listTool.runRaw({'dirPath': ''});
      final list = result.result as List<ListFileOutputItem>;

      expect(list.any((i) => i.path == 'file1.txt' && !i.isDirectory), isTrue);
      expect(list.any((i) => i.path == 'subdir' && i.isDirectory), isTrue);
    });

    test('should read file content and inject message', () async {
      final file = File(p.join(tempDir.path, 'test.txt'));
      await file.writeAsString('hello world');

      final mw = filesystem(rootDirectory: tempDir.path);

      genkit.defineModel(
        name: 'read-test-model',
        fn: (req, ctx) async {
          // Check if we have the injected message
          final injectedMsg = req.messages
              .where(
                (m) =>
                    m.role == Role.user &&
                    m.content.any(
                      (part) =>
                          part.text != null &&
                          part.text!.contains('<read_file'),
                    ),
              )
              .firstOrNull;

          if (injectedMsg != null) {
            final content = injectedMsg.content.first.text!;
            if (content.contains('hello world')) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [TextPart(text: 'Content read')],
                ),
              );
            }
          }

          if (req.messages.length <= 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'read_file',
                      input: {'filePath': 'test.txt'},
                    ),
                  ),
                ],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'No content')],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('read-test-model'),
        prompt: 'read',
        use: [mw],
      );

      expect(result.text, 'Content read');
    });

    test('should NOT allow access outside root', () async {
      final mw = FilesystemMiddleware(tempDir.path);
      final readTool = mw.tools.firstWhere((t) => t.name == 'read_file');

      expect(
        () => readTool.runRaw({'filePath': '../outside.txt'}),
        throwsA(
          isA<Exception>().having(
            (e) => e.toString(),
            'message',
            contains('Access denied'),
          ),
        ),
      );
    });

    test('should write file', () async {
      final mw = FilesystemMiddleware(tempDir.path);
      final writeTool = mw.tools.firstWhere((t) => t.name == 'write_file');

      final result = await writeTool.runRaw({
        'filePath': 'new.txt',
        'content': 'new content',
      });
      expect(result.result, contains('written successfully'));

      final file = File(p.join(tempDir.path, 'new.txt'));
      expect(await file.readAsString(), 'new content');
    });

    group('search_and_replace tool', () {
      late File file;
      late Tool searchAndReplaceTool;

      setUp(() async {
        file = File(p.join(tempDir.path, 'replace.txt'));
        await file.writeAsString('hello world');
        final mw = FilesystemMiddleware(tempDir.path);
        searchAndReplaceTool = mw.tools.firstWhere(
          (t) => t.name == 'search_and_replace',
        );
      });

      test('should search and replace single occurrence', () async {
        final editBlock = '''<<<<<<< SEARCH
hello world
=======
hello universe
>>>>>>> REPLACE''';

        final result = await searchAndReplaceTool.runRaw({
          'filePath': 'replace.txt',
          'edits': [editBlock],
        });

        expect(result.result, contains('Successfully applied 1 edit(s)'));
        expect(await file.readAsString(), 'hello universe');
      });

      test('should apply multiple edits in order', () async {
        final editBlock1 = '''<<<<<<< SEARCH
hello
=======
hi
>>>>>>> REPLACE''';
        final editBlock2 = '''<<<<<<< SEARCH
world
=======
there
>>>>>>> REPLACE''';

        final result = await searchAndReplaceTool.runRaw({
          'filePath': 'replace.txt',
          'edits': [editBlock1, editBlock2],
        });

        expect(result.result, contains('Successfully applied 2 edit(s)'));
        expect(await file.readAsString(), 'hi there');
      });

      test('should fail if missing SEARCH marker', () async {
        final badEditBlock = '''hello world
=======
hello universe
>>>>>>> REPLACE''';

        expect(
          () => searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [badEditBlock],
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid edit block format. Block must start with'),
            ),
          ),
        );
      });

      test('should fail if missing REPLACE marker', () async {
        final badEditBlock = '''<<<<<<< SEARCH
hello world
=======
hello universe''';

        expect(
          () => searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [badEditBlock],
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Invalid edit block format. Block must start with'),
            ),
          ),
        );
      });

      test('should fail if missing separator', () async {
        final badEditBlock = '''<<<<<<< SEARCH
hello world
hello universe
>>>>>>> REPLACE''';

        expect(
          () => searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [badEditBlock],
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Missing separator'),
            ),
          ),
        );
      });

      test('should fail if search content not found', () async {
        final editBlock = '''<<<<<<< SEARCH
hello nothing
=======
hello universe
>>>>>>> REPLACE''';

        expect(
          () => searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [editBlock],
          }),
          throwsA(
            isA<Exception>().having(
              (e) => e.toString(),
              'message',
              contains('Search content not found in file'),
            ),
          ),
        );
      });

      test(
        'should find correct split when target file contains the separator',
        () async {
          await file.writeAsString('code with\n=======\nseparator');

          // The replacement also contains a separator, just to make sure
          // it doesn't get confused splitting.
          // The block is:
          // <<<<<<< SEARCH\n
          // code with\n
          // =======\n
          // separator\n
          // =======\n
          // new code with\n
          // =======\n
          // separator\n
          // >>>>>>> REPLACE
          final complexEditBlock = '''<<<<<<< SEARCH
code with
=======
separator
=======
new code with
=======
separator
>>>>>>> REPLACE''';

          final result = await searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [complexEditBlock],
          });

          expect(result.result, contains('Successfully applied'));

          // 'code with\n=======\nseparator' was exactly found as search block,
          // and 'new code with\n=======\nseparator' is the replacement.
          expect(
            await file.readAsString(),
            'new code with\n=======\nseparator',
          );
        },
      );

      test(
        'should only replace the first occurrence of multiple identical search strings',
        () async {
          await file.writeAsString('hello\nhello\nhello');

          final editBlock = '''<<<<<<< SEARCH
hello
=======
hi
>>>>>>> REPLACE''';

          await searchAndReplaceTool.runRaw({
            'filePath': 'replace.txt',
            'edits': [editBlock],
          });

          expect(await file.readAsString(), 'hi\nhello\nhello');
        },
      );
    });

    test('should intercept image reads and inject pending message', () async {
      // Create a 1x1 transparent GIF
      final gifBytes = base64Decode(
        'R0lGODlhAQABAIAAAAAAAP///yH5BAEAAAAALAAAAAABAAEAAAIBRAA7',
      );
      final file = File(p.join(tempDir.path, 'test.gif'));
      await file.writeAsBytes(gifBytes);

      final mw = filesystem(rootDirectory: tempDir.path);

      genkit.defineModel(
        name: 'fs-image-model',
        fn: (req, ctx) async {
          // Check if we received an image message
          final imageMessage = req.messages.where((m) {
            if (m.role != Role.user) return false;
            return m.content.any((p) {
              final json = p.toJson();
              if (json['media'] is Map<String, dynamic>) {
                final media = json['media'] as Map<String, dynamic>;
                return (media['url'] as String?)?.startsWith(
                      'data:image/gif',
                    ) ??
                    false;
              }
              return false;
            });
          }).firstOrNull;

          if (imageMessage != null) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Received image')],
              ),
            );
          }

          // Initial request
          if (req.messages.length <= 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'read_file',
                      input: {'filePath': 'test.gif'},
                    ),
                  ),
                ],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [
                TextPart(text: 'Loop continued without image detection'),
              ],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('fs-image-model'),
        prompt: 'read image',
        use: [mw],
      );

      expect(result.text, 'Received image');
      expect(
        result.messages.map(
          (m) =>
              '${m.role} - ${m.content.map((c) => c.isText
                  ? 'text'
                  : c.isToolRequest
                  ? 'toolRequest'
                  : c.isToolResponse
                  ? 'toolResponse'
                  : c.isMedia
                  ? 'media'
                  : 'unknown')}',
        ),
        [
          'user - (text)',
          'model - (toolRequest)',
          'tool - (toolResponse)',
          'user - (text, media)', // Because it merged into the last user message, or rather replaced it? Wait, let me check the middleware logic.
          'model - (text)',
        ],
      );
    });

    test('should handle tool errors by injecting user message', () async {
      final mw = filesystem(rootDirectory: tempDir.path);

      genkit.defineModel(
        name: 'error-model',
        fn: (req, ctx) async {
          // Check for error message
          final errorMsg = req.messages
              .where(
                (m) =>
                    m.role == Role.user &&
                    m.content.any(
                      (p) =>
                          p.text != null &&
                          p.text!.contains("Tool 'read_file' failed"),
                    ),
              )
              .firstOrNull;

          if (errorMsg != null) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'Error caught')],
              ),
            );
          }

          if (req.messages.length <= 1) {
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [
                  ToolRequestPart(
                    toolRequest: ToolRequest(
                      name: 'read_file',
                      input: {'filePath': 'nonexistent.txt'},
                    ),
                  ),
                ],
              ),
            );
          }

          return ModelResponse(
            finishReason: FinishReason.stop,
            message: Message(
              role: Role.model,
              content: [TextPart(text: 'No error caught')],
            ),
          );
        },
      );

      final result = await genkit.generate(
        model: modelRef('error-model'),
        prompt: 'cause error',
        use: [mw],
      );

      expect(result.text, 'Error caught');
    });

    test(
      'should inject file contents in the same multi-turn generate loop',
      () async {
        final file = File(p.join(tempDir.path, 'multi_turn.txt'));
        await file.writeAsString('multi-turn-content');

        final mw = filesystem(rootDirectory: tempDir.path);

        genkit.defineModel(
          name: 'multi-turn-model',
          fn: (req, ctx) async {
            // If no injected message found, and we haven't requested the tool yet, request it
            if (req.messages.length <= 1) {
              return ModelResponse(
                finishReason: FinishReason.stop,
                message: Message(
                  role: Role.model,
                  content: [
                    ToolRequestPart(
                      toolRequest: ToolRequest(
                        name: 'read_file',
                        input: {'filePath': 'multi_turn.txt'},
                      ),
                    ),
                  ],
                ),
              );
            }

            // If we get here, it means the tool was requested and executed, but injected message wasn't seen
            return ModelResponse(
              finishReason: FinishReason.stop,
              message: Message(
                role: Role.model,
                content: [TextPart(text: 'done')],
              ),
            );
          },
        );

        final result = await genkit.generate(
          model: modelRef('multi-turn-model'),
          prompt: 'read multi-turn',
          use: [mw],
        );

        expect(
          result.messages.map(
            (m) =>
                '${m.role} - ${m.content.map((c) => c.isText
                    ? 'text'
                    : c.isToolRequest
                    ? 'toolRequest'
                    : c.isToolResponse
                    ? 'toolResponse'
                    : c.isMedia
                    ? 'media'
                    : 'unknown')}',
          ),
          [
            'user - (text)',
            'model - (toolRequest)',
            'tool - (toolResponse)',
            'user - (text)',
            'model - (text)',
          ],
        );
      },
    );
  });
}
