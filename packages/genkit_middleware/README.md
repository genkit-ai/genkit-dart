# Genkit Middleware

A collection of useful middleware for Genkit Dart to enhance your agent's capabilities.

## Features

- **Agents**: Let a main agent delegate tasks to specialized sub-agents.
- **Filesystem**: Give your agent read/write access to a specific directory.
- **Skills**: Inject reusable instructions/personas from markdown files.
- **Tool Approval**: Require human approval before executing sensitive tools.

## Installation

Install `genkit_middleware` package:

```bash
dart pub add genkit_middleware

# or

flutter pub add genkit_middleware
```

## Setup

To use these middleware, you must first register their corresponding plugins when initializing `Genkit`.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/genkit_middleware.dart';

void main() {
  final ai = Genkit(
    plugins: [
      // Register the plugins here
      AgentsPlugin(),
      FilesystemPlugin(),
      SkillsPlugin(),
      ToolApprovalPlugin(),
    ],
  );
  
  // ...
}
```

## Usage

### Agents Middleware

Enables sub-agent delegation. For each configured agent the middleware injects a
dedicated delegation tool (e.g. `delegate_to_researcher`) and appends a
`<sub-agents>` block to the system prompt listing the available agents and their
descriptions. When the model calls a delegation tool, the middleware resolves the
target agent from the registry, runs it, and returns the sub-agent's response as
the tool result.

**Key behaviors:**
- Injects **one delegation tool per agent**, named `<toolPrefix>_<agentName>`
  (default prefix: `delegate_to`).
- Agent descriptions are auto-discovered from the registry and surfaced in the
  system prompt.
- Sub-agent interrupts and failures are returned as tool responses (not thrown),
  allowing the orchestrator to self-correct.
- Sub-agent artifacts are merged into the parent session and/or returned inline,
  controlled by `artifactStrategy`.

#### Options

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `agents` | `List<String>` | — (required) | Names of registered agents available for delegation. Each name gets a dedicated delegation tool. |
| `toolPrefix` | `String?` | `'delegate_to'` | Prefix for generated delegation tool names. Set to `''` to use bare agent names. |
| `maxDelegations` | `int?` | unlimited | Maximum sub-agent delegations allowed per generate call. Prevents runaway delegation loops. |
| `historyLength` | `int?` | `0` | Number of recent conversation messages (user/model only) to forward to sub-agents as context. |
| `artifactStrategy` | `String?` | `'inline'` | `inline`: artifact content is included in the tool result **and** merged into the parent session. `session`: artifacts are merged into the parent session only (the tool result lists names only). |

#### Configuration

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/agents.dart';

final ai = Genkit(plugins: [AgentsPlugin(), /* ... */]);

// Define sub-agents (descriptions are auto-discovered by the middleware).
final researcher = ai.defineAgent(
  name: 'researcher',
  description: 'Searches the web and summarizes findings.',
  system: 'You are a research assistant.',
);

final coder = ai.defineAgent(
  name: 'coder',
  description: 'An expert programmer that writes clean code.',
  system: 'You are an expert programmer.',
);

// Main orchestrator agent delegates to sub-agents. This injects
// `delegate_to_researcher` and `delegate_to_coder` tools.
final orchestrator = ai.defineAgent(
  name: 'orchestrator',
  system: 'Delegate research to the researcher and coding to the coder.',
  use: [
    agents(agents: ['researcher', 'coder']),
  ],
);
```

You can customize the tool-name prefix and forward conversation history:

```dart
use: [
  agents(
    // Tools become `ask_researcher` and `ask_coder`.
    toolPrefix: 'ask',
    agents: ['researcher', 'coder'],
    maxDelegations: 5,
    historyLength: 4,
  ),
]
```

### Filesystem Middleware

Allows the agent to list, read, write, and search/replace files within a restricted root directory.

#### Configuration

```dart
// ... inside your generate call
final response = await ai.generate(
  prompt: 'Check the logs in the current directory.',
  use: [
    // Configure the middleware for this request
    filesystem(rootDirectory: '/path/to/secure/workspace'),
  ],
);
```

**Tools Provided:**
- `list_files`: List files and directories.
- `read_file`: Read file contents.
- `write_file`: Write content to a file.
- `search_and_replace`: Targeted search and replace in files.

### Skills Middleware

Injects specialized instructions (skills) into the system prompt from `SKILL.md` files located in specified directories.

#### Configuration

```dart
// ... inside your generate call
final response = await ai.generate(
  prompt: 'Help me debug this issue.',
  use: [
    skills(skillPaths: ['/path/to/skills']),
  ],
);
```

**Tools Provided:**
- `use_skill`: Retrieve the full content of a skill by name.

**Skill File Format:**
Create a `SKILL.md` file in a subdirectory of your skills path.

```markdown
---
name: debugging_expert
description: Expert advice on debugging complex issues.
---
# Debugging Expert

You are an expert at debugging. Always follow these steps:
1. Analyze the stack trace.
2. Isolate the reproduction case.
3. ...
```

### Tool Approval Middleware

Intercepts tool execution for specified tools and requires explicit approval (via interrupt).

#### Configuration

```dart
// ... inside your generate call
final response = await ai.generate(
  prompt: 'Delete the database.',
  use: [
    // 'delete_db' and 'deploy_prod' are NOT in this list, so they will require approval
    toolApproval(approved: ['read_file', 'list_files']),
  ],
);
```

#### Handling Interrupts

When a protected tool is called, `generate` will return with `FinishReason.interrupted`. You must handle this interrupt to approve or deny the tool execution.

```dart
if (response.finishReason == FinishReason.interrupted) {
  final interrupt = response.interrupts.first;
  print('Tool ${interrupt.toolRequest.name} requires approval.');
  
  // Ask user for approval
  final isApproved = await askUser(); // Implement your logic

  if (isApproved) {
    // Resume generation with approval metadata
    final resumeResponse = await ai.generate(
      messages: response.messages, // Pass history
      toolChoice: ToolChoice.none, // Prevent immediate re-call
      // ... other options
      interruptRestart: [
        interrupt.toolRequestPart!.restart({'tool-approved': true}),
      ],
    );
  }
}
```
