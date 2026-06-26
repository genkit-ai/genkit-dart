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

/// App shell — sidebar nav + routed content outlet.
///
/// Ported from the JS `web/src/App.tsx` + `web/src/main.tsx` router config.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'pages/background_agent_page.dart';
import 'pages/banking_page.dart';
import 'pages/branching_page.dart';
import 'pages/client_state_page.dart';
import 'pages/coding_agent_page.dart';
import 'pages/research_page.dart';
import 'pages/sub_agent_page.dart';
import 'pages/task_tracker_page.dart';
import 'pages/trip_planner_page.dart';
import 'pages/weather_page.dart';
import 'pages/workspace_page.dart';

class _NavItem {
  const _NavItem(this.to, this.icon, this.label);
  final String to;
  final String icon;
  final String label;
}

const _navItems = [
  _NavItem('/coding-agent', '💻', 'Coding Agent'),
  _NavItem('/weather', '🌤️', 'Weather Chat'),
  _NavItem('/client-state', '🌤️', 'Weather Chat (Stateless)'),
  _NavItem('/banking', '🏦', 'Banking (Interrupt)'),
  _NavItem('/workspace', '🛠️', 'Workspace Builder'),
  _NavItem('/background', '⏳', 'Background (Detach)'),
  _NavItem('/branching', '🔀', 'Branching (Variants)'),
  _NavItem('/tasks', '✅', 'Task Tracker (Custom State)'),
  _NavItem('/research', '🔬', 'Research (Custom Agent)'),
  _NavItem('/subagents', '🤝', 'Sub-Agent Delegation'),
  _NavItem('/trip-planner', '✈️', 'Trip Planner (Prompt File)'),
];

/// The root component: a router with a shell that wraps every page.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(
      routes: [
        ShellRoute(
          builder: (context, state, child) => _Shell(child: child),
          routes: [
            Route(path: '/', redirect: (_, _) => '/weather'),
            Route(path: '/weather', builder: (_, _) => const WeatherPage()),
            Route(
              path: '/weather/:snapshotId',
              builder: (_, state) =>
                  WeatherPage(snapshotId: state.params['snapshotId']),
            ),
            Route(
              path: '/client-state',
              builder: (_, _) => const ClientStatePage(),
            ),
            Route(path: '/banking', builder: (_, _) => const BankingPage()),
            Route(path: '/workspace', builder: (_, _) => const WorkspacePage()),
            Route(
              path: '/background',
              builder: (_, _) => const BackgroundAgentPage(),
            ),
            Route(path: '/branching', builder: (_, _) => const BranchingPage()),
            Route(
              path: '/branching/:snapshotId',
              builder: (_, state) =>
                  BranchingPage(snapshotId: state.params['snapshotId']),
            ),

            Route(path: '/tasks', builder: (_, _) => const TaskTrackerPage()),
            Route(path: '/research', builder: (_, _) => const ResearchPage()),
            Route(path: '/subagents', builder: (_, _) => const SubAgentPage()),
            Route(
              path: '/trip-planner',
              builder: (_, _) => const TripPlannerPage(),
            ),
            Route(
              path: '/coding-agent',
              builder: (_, _) => const CodingAgentPage(),
            ),
          ],
        ),
      ],
    );
  }
}

class _Shell extends StatelessComponent {
  const _Shell({required this.child});
  final Component child;

  @override
  Component build(BuildContext context) {
    final current = RouteState.of(context).location;
    return div(classes: 'app', [
      aside(classes: 'sidebar', [
        h1(classes: 'sidebar-title', [.text('🔥 Genkit Agents')]),
        p(classes: 'sidebar-subtitle', [.text('Genkit Agent Demos')]),
        nav(classes: 'nav-list', [
          for (final item in _navItems)
            Link(
              to: item.to,
              classes: current.startsWith(item.to) && item.to != '/'
                  ? 'nav-item active'
                  : 'nav-item',
              children: [
                span(classes: 'nav-icon', [.text(item.icon)]),
                span(classes: 'nav-label', [.text(item.label)]),
              ],
            ),
        ]),
        div(classes: 'sidebar-footer', [
          span(classes: 'sidebar-hint', [
            .text(
              'Each page is a self-contained sample showing how to use the ',
            ),
            code([.text('remoteAgent')]),
            .text(' client.'),
          ]),
        ]),
      ]),
      main_(classes: 'main', [child]),
    ]);
  }
}
