import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:genkit_middleware/tool_approval.dart';

final _lines = StreamIterator(stdin.transform(utf8.decoder).transform(const LineSplitter()));

Future<String?> _readLineAsync() async {
  if (await _lines.moveNext()) {
    return _lines.current;
  }
  return null;
}

void main() async {
  configureCollectorExporter();

  final apiKey = Platform.environment['GEMINI_API_KEY'];
  if (apiKey == null) {
    print('GEMINI_API_KEY environment variable is required.');
    print('Please set it in your environment or .env file');
    exit(1);
  }

  // Create plugin instances
  final middlewarePlugin = FilesystemPlugin();
  final skillsPlugin = SkillsPlugin();
  final toolApprovalPlugin = ToolApprovalPlugin();

  final ai = Genkit(
    plugins: [
      googleAI(apiKey: apiKey),
      middlewarePlugin,
      skillsPlugin,
      toolApprovalPlugin,
    ],
  );

  final currentDir = Directory.current.path;
  final fsRoot = '$currentDir/workspace';
  final skillsRoot = '$currentDir/skills';

  // Ensure workspace exists
  Directory(fsRoot).createSync(recursive: true);

  print('--- Coding Agent ---');
  print('Type your request. To exit, type "exit".');

  final messages = <Message>[
    Message(
      role: Role.system,
      content: [
        TextPart(
          text:
              'You are a helpful coding agent. Very terse but thoughful and careful.\n'
              'Your working directory is in $fsRoot, you are not allowed to access anything outside it.\n'
              'Use skills. ALWAYS start by analyzing the current state of the workspace, there might be something already there.',
        ),
      ],
    ),
  ];

  while (true) {
    stdout.write('\n> ');
    final input = await _readLineAsync();
    if (input == null || input.trim().toLowerCase() == 'exit') {
      break;
    }

    try {
      List<ToolRequestPart>? interruptRestart;
      var currentMessages = List<Message>.from(messages);
      late GenerateResponseHelper response;

      while (true) {
        response = await ai.generate(
          model: googleAI.gemini('gemini-3-flash-preview'),
          prompt: interruptRestart == null ? input : null,
          messages: currentMessages,
          use: [
            toolApproval(approved: ['read_file', 'list_files', 'read_skill']),
            skills(skillPaths: [skillsRoot]),
            filesystem(rootDirectory: fsRoot),
          ],
          interruptRestart: interruptRestart,
          maxTurns: 20,
        );

        if (response.finishReason != FinishReason.interrupted) {
          break;
        }

        final interrupts = response.interrupts;
        if (interrupts.isEmpty) {
          print('Interrupted but no interrupt record found.');
          break;
        }

        final approvedInterrupts = <ToolRequestPart>[];
        for (final interrupt in interrupts) {
          print('\n*** Tool Approval Required ***');
          print('Tool: ${interrupt.toolRequest.name}');
          print('Input: ${jsonEncode(interrupt.toolRequest.input)}');

          stdout.write('Approve? (y/N): ');
          final approval = await _readLineAsync();
          if (approval != null && approval.trim().toLowerCase() == 'y') {
            approvedInterrupts.add(
              ToolRequestPart(
                toolRequest: interrupt.toolRequest,
                metadata: {...?interrupt.metadata, 'tool-approved': true},
              ),
            );
          }
        }

        if (approvedInterrupts.isNotEmpty) {
          print('Resuming...');
          interruptRestart = approvedInterrupts;
          currentMessages = response.messages;
        } else {
          print('Tool denied.');
          break;
        }
      }

      print('\nAI Response:\n${response.text}');

      messages.clear();
      messages.addAll(response.messages);
    } catch (e) {
      print('Error during generation: $e');
    }
  }
}
