<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="./docs/resources/genkit-logo-dark.png">
    <img alt="Genkit logo" src="./docs/resources/genkit-logo.png" width="400">
  </picture>
  <br>
  <strong>Genkit Dart (Preview)</strong>
  <br>
  <em>AI SDK for Dart &bull; LLM Framework &bull; AI Agent Toolkit</em>
</p>

<p align="center">
  Build production-ready AI-powered applications in Dart with a unified interface for text generation, structured output, tool calling, and agentic workflows.
</p>

<p align="center">
  <a href="https://genkit.dev">Documentation</a> &bull;
  <a href="https://discord.gg/qXt5zzQKpc">Discord</a>
</p>


---

## Using a coding agent? Install the skill.

Before you write a line of Genkit Dart with an agent, install the official
Genkit Dart Agent Skill:

```bash
npx skills add genkit-ai/skills --skill developing-genkit-dart
```

It teaches your agent the current Genkit Dart APIs (flows, tools, agents,
sessions, prompts, plugins, `schemantic`) and common gotchas. Source, manual
install instructions, and skills for JS/TS, Go and Python:
[github.com/genkit-ai/skills](https://github.com/genkit-ai/skills).

---

See the [Genkit package documentation](https://pub.dev/packages/genkit) for getting started, guides, and API reference.

| Package | Description | Pub |
| :--- | :--- | :--- |
| [`genkit`](packages/genkit) | The Genkit framework: flows, tools, prompts, structured output, agents, and a client for calling deployed flows. | [![Pub](https://img.shields.io/pub/v/genkit.svg)](https://pub.dev/packages/genkit) |
| [`genkit_google_genai`](packages/genkit_google_genai) | Google AI plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_google_genai.svg)](https://pub.dev/packages/genkit_google_genai) |
| [`genkit_vertexai`](packages/genkit_vertexai) | Vertex AI plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_vertexai.svg)](https://pub.dev/packages/genkit_vertexai) |
| [`genkit_anthropic`](packages/genkit_anthropic) | Anthropic plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_anthropic.svg)](https://pub.dev/packages/genkit_anthropic) |
| [`genkit_openai`](packages/genkit_openai) | OpenAI plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_openai.svg)](https://pub.dev/packages/genkit_openai) |
| [`genkit_chrome`](packages/genkit_chrome) | Chrome Prompt API (Gemini Nano) plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_chrome.svg)](https://pub.dev/packages/genkit_chrome) |
| [`genkit_mcp`](packages/genkit_mcp) | Model Context Protocol (MCP) plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_mcp.svg)](https://pub.dev/packages/genkit_mcp) |
| [`genkit_middleware`](packages/genkit_middleware) | Common middlewares (filesystem, skills, toolApproval) for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_middleware.svg)](https://pub.dev/packages/genkit_middleware) |
| [`genkit_a2ui`](packages/genkit_a2ui) | A2UI (Agent-to-UI) streaming UI protocol support for Genkit Dart (experimental). | [![Pub](https://img.shields.io/pub/v/genkit_a2ui.svg)](https://pub.dev/packages/genkit_a2ui) |
| [`genkit_shelf`](packages/genkit_shelf) | Shelf adapter for serving Genkit actions and agents over HTTP. | [![Pub](https://img.shields.io/pub/v/genkit_shelf.svg)](https://pub.dev/packages/genkit_shelf) |
| [`genkit_otel`](packages/genkit_otel) | OpenTelemetry GenAI semantic-conventions instrumentation for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_otel.svg)](https://pub.dev/packages/genkit_otel) |
| [`genkit_firebase_ai`](packages/genkit_firebase_ai) | Firebase AI plugin for Genkit Dart. | [![Pub](https://img.shields.io/pub/v/genkit_firebase_ai.svg)](https://pub.dev/packages/genkit_firebase_ai) |
| [`genkit_google_cloud`](packages/genkit_google_cloud) | Google Cloud integration for Genkit Dart (Firestore session store, experimental). | [![Pub](https://img.shields.io/pub/v/genkit_google_cloud.svg)](https://pub.dev/packages/genkit_google_cloud) |
| [`schemantic`](packages/schemantic) | Type-safe data classes and runtime JSON Schemas, with serialization and validation. | [![Pub](https://img.shields.io/pub/v/schemantic.svg)](https://pub.dev/packages/schemantic) |
| [`schemantic_builder`](packages/schemantic_builder) | The code generator for `schemantic`. | [![Pub](https://img.shields.io/pub/v/schemantic_builder.svg)](https://pub.dev/packages/schemantic_builder) |

---

<p align="center">
  Built by Google with contributions from the <a href="https://github.com/genkit-ai/genkit-dart/graphs/contributors">Open Source Community</a>
</p>
