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

/// Sub-agent delegation — an orchestrator that delegates to specialized agents.
///
/// Ported from the JS `SubAgentChat.tsx`. Delegation tool calls
/// (delegate_to_researcher / delegate_to_coder) render inline.
library;

import 'package:jaspr/jaspr.dart';

import '../components/info_sidebar.dart';
import 'streaming_chat_page.dart';

class SubAgentPage extends StatelessComponent {
  const SubAgentPage({super.key});

  @override
  Component build(BuildContext context) {
    return StreamingChatPage(
      endpoint: '/api/orchestratorAgent',
      title: 'Sub-Agent Delegation',
      description:
          'An orchestrator agent that delegates to a researcher and a coder '
          'sub-agent and synthesizes their answers.',
      suggestions: const [
        'Research the best sorting algorithms and write a Dart quicksort.',
        'Write a function that calculates the fibonacci sequence.',
        'Explain how HTTPS works.',
      ],
      sidebar: subAgentSidebar(),
    );
  }
}
