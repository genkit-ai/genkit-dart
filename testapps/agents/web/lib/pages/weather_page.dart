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

/// Weather chat — multi-turn streaming chat with tool calling.
///
/// Ported from the JS `WeatherChat.tsx`. Uses the shared streaming chat page.
library;

import 'package:jaspr/jaspr.dart';

import '../components/info_sidebar.dart';
import 'streaming_chat_page.dart';

class WeatherPage extends StatelessComponent {
  const WeatherPage({this.snapshotId, super.key});

  /// Optional snapshot id from the URL (`/weather/:snapshotId`). When present,
  /// the session is restored via `agent.loadChat()`.
  final String? snapshotId;

  @override
  Component build(BuildContext context) {
    return StreamingChatPage(
      endpoint: '/api/weatherAgent',
      title: 'Weather Agent',

      description:
          'Multi-turn chat with tool-calling. Ask about the weather in any '
          'city.',
      suggestions: const [
        'What is the weather like in London?',
        'Is it sunny in Tokyo right now?',
        'Compare the weather in Paris and New York.',
      ],
      sidebar: weatherSidebar(),
      sessionPath: '/weather',
      snapshotId: snapshotId,
    );
  }
}
