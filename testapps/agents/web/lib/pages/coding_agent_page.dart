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

/// Coding agent — filesystem + shell + skills, with tool-approval interrupts.
///
/// Ported from the JS `CodingAgent.tsx`. This page uses the shared streaming
/// chat; tool calls (list_files, write_file, run_shell, ...) render inline.
/// Tool-approval interrupts surface as `tool` messages and can be resumed from
/// the full client API; here we keep the page focused on the streaming view.
library;

import 'package:jaspr/jaspr.dart';

import 'streaming_chat_page.dart';

class CodingAgentPage extends StatelessComponent {
  const CodingAgentPage({super.key});

  @override
  Component build(BuildContext context) {
    return const StreamingChatPage(
      endpoint: '/api/codingAgent',
      title: 'Coding Agent',
      description:
          'An AI coding assistant working in a sandboxed workspace. It can '
          'list, read, write, and edit files and run shell commands.',
      suggestions: [
        'Create a Dart hello world file called hello.dart.',
        'List the files in the workspace.',
        'Write a function that calculates the fibonacci sequence.',
      ],
    );
  }
}
