# Genkit MCP testapp

This testapp shows both sides of the Genkit MCP integration:

- `bin/server.dart` - an MCP server (stdio) that exposes Genkit tools, a prompt,
  and resources over the Model Context Protocol.
- `bin/host.dart` - a Genkit app that acts as an MCP host, connecting to the
  server above via `defineMcpHost`. The host registers a dynamic action provider
  (DAP) named `myServers`, so the remote server's tools/prompts/resources become
  resolvable through the registry as `myServers:<name>`.

## Server (`bin/server.dart`)

Exposes:

- tools: `greet`, `add`, `weather`
- prompt: `echoPrompt`
- resources: `info` (`app://info`) and `file` (`file://{path}`)

It communicates over stdio, so do not print to stdout from the server; the
transport uses stdout exclusively for JSON-RPC. You normally do not run the
server directly; the host spawns it (see below).

## Host (`bin/host.dart`)

The host connects to the server, then defines an `askWithMcpTools` flow that lets
Gemini call the MCP tools (`toolNames: ['myServers:*']`).

Set a Gemini API key first:

```sh
export GEMINI_API_KEY=...   # or GOOGLE_API_KEY
```

### Run under the Dev UI

Launch from this directory so the relative spawn command (`dart run
bin/server.dart`) resolves:

```sh
cd testapps/mcp
genkit start -- dart run bin/host.dart
```

In the Dev UI you can:

- see the `weather` / `greet` / `add` tools, the `echoPrompt`, and the resources
  listed individually under the `myServers` host (the DAP is expanded);
- run any of them directly from the Dev UI; and
- run the `askWithMcpTools` flow, which lets Gemini pick and call the MCP tools.

### Run headless

```sh
cd testapps/mcp
dart run bin/host.dart "what's the weather in Tokyo?"
```
