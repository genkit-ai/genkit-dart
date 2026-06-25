// Copyright 2026 Google LLC
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

/// Coding agent — a full-featured AI coding assistant.
///
/// Ported from the JS `coding-agent.ts`. Combines middleware:
///   * `filesystem` — list_files, read_file, write_file, search_and_replace
///     scoped to a sandboxed `workspace/` directory.
///   * `skills` — loads coding conventions on demand via the use_skill tool.
///   * `toolApproval` — requires user approval (interrupt) before file writes
///     and edits; reads and run_shell are auto-approved.
///   * `retry` — automatic retry on transient model errors.
///
/// Plus two standalone tools:
///   * `run_shell` — runs a shell command in the workspace, with an AI-powered
///     safety gate (a fast model evaluates each command; risky commands
///     interrupt for user approval).
///   * `ask_user` — lets the model ask the user a question with options.
library;

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:genkit_middleware/tool_approval.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'coding_agent.g.dart';

/// The sandboxed workspace directory (created on first use).
final String workspaceDir = p.join(Directory.current.path, 'workspace');

/// The skills directory bundled with the sample.
final String skillsDir = p.join(Directory.current.path, 'skills');

@Schema()
abstract class $AskUserInput {
  @Field(description: 'The question to ask the user')
  String get question;
  @Field(
    description: 'Suggested answer options for the user to choose from (2-5)',
  )
  List<String> get options;
}

@Schema()
abstract class $RunShellInput {
  @Field(description: 'The shell command to execute')
  String get command;
}

@Schema()
abstract class $RunShellOutput {
  String get stdout;
  String get stderr;
  int get exitCode;
}

@Schema()
abstract class $SafetyVerdict {
  @Field(description: 'Whether the command is safe or risky')
  String get verdict;
  @Field(description: 'Brief explanation of why the command is safe or risky')
  String get reason;
}

/// Interrupt that lets the model ask the user a question with options.
final askUser = ai.defineTool(
  name: 'ask_user',
  description:
      'Ask the user a question when you need clarification, a preference, or a '
      'decision. Provide a clear question and 2-5 suggested options. The user '
      'can pick one of the options or write their own answer.',
  inputSchema: AskUserInput.$schema,
  fn: (input, ctx) async => ctx.interrupt(),
);

final runShell = ai.defineTool(
  name: 'run_shell',
  description:
      'Execute a shell command in the workspace directory. Use for running '
      'build commands, installing dependencies, running scripts, testing, etc. '
      'Commands are safety-checked automatically; risky commands will require '
      'user approval.',
  inputSchema: RunShellInput.$schema,
  outputSchema: RunShellOutput.$schema,
  fn: (input, ctx) async {
    // Check if this is a resumed (user-approved) invocation.
    final resumed = ctx.toolRequest?.metadata?['resumed'];
    final isApproved = resumed is Map && resumed['toolApproved'] == true;

    if (!isApproved) {
      // AI-powered safety gate — use a fast model to evaluate the command.
      final safetyCheck = await ai.generate(
        model: liteModel,
        prompt:
            'You are a shell command safety evaluator. Evaluate the following '
            'shell command for safety.\n\n'
            'Command: "${input.command}"\n'
            'Working directory: A sandboxed workspace directory.\n\n'
            'Consider these factors:\n'
            '- Does it try to access files outside the workspace (/, /etc, ~, ..)?\n'
            '- Is it destructive (rm -rf, format, mkfs, dd, etc.)?\n'
            '- Does it modify system configuration or env permanently?\n'
            '- Does it install system-wide packages or modify global state?\n'
            '- Does it access network in a dangerous way (curl | bash, etc.)?\n'
            '- Could it expose sensitive information (env vars, keys)?\n\n'
            'Simple development commands like npm install, npx, dart, node, '
            'cat, ls, mkdir, echo, grep, find, git, python, etc. within the '
            'workspace are SAFE.\n\nRespond with JSON.',
        outputFormat: 'json',
        outputSchema: SafetyVerdict.$schema,
      );

      final verdict = safetyCheck.output;
      if (verdict != null && verdict.verdict == 'risky') {
        // Interrupt — the client shows the command + reason and asks for
        // approval. If approved, the tool is restarted with
        // { toolApproved: true }.
        ctx.interrupt({
          'command': input.command,
          'reason': verdict.reason,
          'verdict': 'risky',
        });
      }
    }

    // Execute the command in the workspace directory.
    await Directory(workspaceDir).create(recursive: true);
    try {
      final shell = Platform.isWindows ? 'cmd.exe' : '/bin/sh';
      final shellArgs = Platform.isWindows
          ? ['/c', input.command]
          : ['-c', input.command];
      final result = await Process.run(
        shell,
        shellArgs,
        workingDirectory: workspaceDir,
        environment: {'HOME': workspaceDir, 'USERPROFILE': workspaceDir},
      );
      return RunShellOutput(
        stdout: result.stdout.toString(),
        stderr: result.stderr.toString(),
        exitCode: result.exitCode,
      );
    } catch (e) {
      return RunShellOutput(
        stdout: '',
        stderr: 'Command failed: $e',
        exitCode: 1,
      );
    }
  },
);

final codingAgent = ai.defineAgent(
  name: 'codingAgent',
  description:
      'An expert AI coding assistant that can read, create, edit files, and '
      'run shell commands in a sandboxed workspace.',
  system: '''
You are an expert AI coding assistant working in a sandboxed workspace directory.

You have access to filesystem tools to interact with the workspace:
- **list_files**: List files and directories in the workspace
- **read_file**: Read the contents of a file
- **write_file**: Create a new file or overwrite an existing one
- **search_and_replace**: Make surgical edits to existing files
- **run_shell**: Execute shell commands (dart, node, etc.)
- **ask_user**: Ask the user a question when you need clarification or a choice

You also have access to a skills library with coding conventions and best practices.
Use the **use_skill** tool to load relevant skills before starting work.

## Rules

1. **Always explore first**: Use list_files and read_file to understand the existing codebase before making changes.
2. **Load relevant skills**: If a skill matches the task, load it first.
3. **Prefer surgical edits**: Use search_and_replace for small changes to existing files. Only use write_file for new files or complete rewrites.
4. **Use run_shell for builds & tests**: After writing code, use run_shell to build, lint, or test it when appropriate.
5. **Explain your work**: Before each file operation, explain what you're about to do and why. After, confirm what was done.
6. **One step at a time**: Don't try to create an entire project in one turn.
7. **Handle errors gracefully**: If a file operation or shell command fails, explain the error and suggest a fix.
8. **Ask when uncertain**: If the user's request is ambiguous or involves a choice, use the ask_user tool to present options.

## Response Format

Use markdown for all responses. Use code blocks with language tags for code snippets.''',
  tools: [runShell, askUser],
  use: [
    // Tool approval MUST come before filesystem. Reads and run_shell are
    // auto-approved; writes require user confirmation.
    toolApproval(
      approved: [
        'list_files',
        'read_file',
        'use_skill',
        'run_shell',
        'ask_user',
      ],
    ),
    // Filesystem tools scoped to the workspace directory.
    filesystem(rootDirectory: workspaceDir),
    // Skills library — coding conventions, language guides, etc.
    skills(skillPaths: [skillsDir]),
    // Automatic retry on transient model errors.
    retry(),
  ],
  store: InMemorySessionStore(),
  maxTurns: 30,
);
