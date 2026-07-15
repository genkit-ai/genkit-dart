<!--
 Copyright 2026 Google LLC
 SPDX-License-Identifier: Apache-2.0
-->

# Genkit Dart — Agents sample

A faithful Dart port of the Genkit JS `testapps/agents` sample. It demonstrates
the full agents feature set through a suite of agents served over HTTP by a
[`genkit_shelf`](../../packages/genkit_shelf) server, and a
[Jaspr](https://jaspr.site) web UI that talks to them with the browser-safe
`remoteAgent` client from `package:genkit/client.dart`.

The UI is a near line-for-line port of the JS React + Vite app: a sidebar of
self-contained demo pages, each driving one agent.

## Layout

```
testapps/agents/
  lib/                 # The agents (one file per agent) + shared genkit setup
    genkit.dart        # Shared Genkit instance + model refs (googleAI)
    weather_agent.dart
    banking_agent.dart
    background_agent.dart
    branching_agent.dart
    task_agent.dart
    research_agent.dart
    trip_planner_agent.dart
    workspace_agent.dart
    orchestrator_agent.dart
    coding_agent.dart
    workspace_browser.dart
  prompts/
    tripPlanner.prompt # dotprompt file for the trip-planner agent
  skills/dart/SKILL.md # skill loaded on demand by the coding agent
  workspace/           # sandbox dir for the coding agent
  bin/server.dart      # shelf server exposing every agent under /api/...
  web/                 # Jaspr web UI (its own pubspec, outside the workspace)
```

## Demos

| Page | Agent | Feature |
| --- | --- | --- |
| Coding Agent | `codingAgent` | filesystem + shell + skills middleware, tool-approval interrupts |
| Weather Chat | `weatherAgent` | streaming chat, tool calls, server store |
| Weather (Stateless) | `weatherAgentStateless` | client-managed state (round-tripped) |
| Banking (Interrupt) | `bankingAgent` | restartable tool with a conditional approval interrupt + resume |
| Workspace Builder | `workspaceAgent` | artifact production, streamed `artifact` chunks |
| Background (Detach) | `backgroundAgent` | `detach` + status polling + abort |
| Branching (Variants) | `branchingAgent` | fork a conversation from a snapshot |
| Task Tracker | `taskAgent` | custom session state, live `customPatch` chunks |
| Research | `researchAgent` | multi-step `defineCustomAgent`, live status |
| Sub-Agent Delegation | `orchestratorAgent` | delegation to researcher / coder sub-agents |
| Trip Planner | `tripPlannerAgent` | `definePromptAgent` from a `.prompt` file, customized via `promptInput` |

## Running

The sample uses the Google AI provider. Set your API key first:

```bash
export GEMINI_API_KEY=...   # e.g. from Google AI Studio
```

### 1. Start the agents server (port 8080)

```bash
cd testapps/agents
dart pub get
dart run build_runner build   # generate schemantic .g.dart files (once)
dart run bin/server.dart
```

> **Note:** the API server above does **not** serve the web UI. Opening
> `http://localhost:8080` in a browser will only show a plain-text help
> message — the UI runs as a separate app on its own port (see below).

### 2. Start the web UI (port 5173)

The web UI is a separate Jaspr package. `jaspr serve` defaults to port 8080,
which collides with the API server, so run it on a different port (5173, like
the JS sample's Vite dev server).

Install the Jaspr CLI once:

```bash
dart pub global activate jaspr_cli
```

Then run it (in a second terminal, leaving the API server running):

```bash
cd testapps/agents/web
dart pub get
jaspr serve --port 5173    # then open http://localhost:5173
```

The UI calls the agents server directly at `http://localhost:8080` (see
`apiBase` in `web/lib/pages/streaming_chat_page.dart`). The server enables CORS
for browser access.


## Notes on differences from the JS sample

- **Session store:** server-managed agents use `InMemorySessionStore`
  (sessions reset on server restart). A `FileSessionStore` is also available
  via `package:genkit/io.dart` for persistence across restarts.
- **Middleware:** the orchestrator uses the real `agents()` delegation
  middleware (auto-injecting `delegate_to_*` tools). The JS `artifacts()`
  middleware is not in the Dart middleware suite yet, so the workspace agent
  defines `write_artifact`/`read_artifact` tools directly.
- **UI:** Jaspr replaces React + Vite. The component structure, streaming loop,
  and `remoteAgent` client usage mirror the JS pages.
