# Genkit Middleware

A collection of useful middleware for Genkit Dart to enhance your agent's capabilities.

## Features

- **Filesystem**: Give your agent read/write access to a specific directory.
- **Skills**: Inject reusable instructions/personas from markdown files.
- **Tool Approval**: Require human approval before executing sensitive tools.

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  genkit_middleware: ^0.0.1
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
      FilesystemPlugin(),
      SkillsPlugin(),
      ToolApprovalPlugin(),
    ],
  );
  
  // ...
}
```

## Usage

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
        ToolRequestPart(
          toolRequest: interrupt.toolRequest,
          metadata: {
            ...?interrupt.metadata, 
            'tool-approved': true // The middleware checks for this
          }, 
        ),
      ],
    );
  }
}
```
