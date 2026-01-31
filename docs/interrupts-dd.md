# Interrupts in Genkit Dart

This document details the design for implementing tool interrupts in Genkit Dart.

## Overview

Interrupts allow a tool to pause the generation loop and return control to the caller (user). This is useful for "Human-in-the-loop" scenarios, such as asking for clarification, sensitive permission checks, or presenting intermediate results that require user selection.

## Mechanism

The mechanism relies on:
1.  **Throwing an Exception**: Tools signal an interrupt by throwing a `ToolInterruptException`.
2.  **Context Helper**: A helper method `interrupt(data)` on the tool execution context (`ActionFnArg`) to easily throw this exception.
3.  **Handling in Generate**: The `generate` loop catches this exception.
    *   If caught, the generation stops (finishReason: `interrupted`).
    *   The returned response includes the tool requests with updated metadata:
        *   Interrupted tools have `interrupt` metadata (with the data).
        *   Completed tools (in the same batch) have `pendingOutput` metadata.
4.  **Resuming**: The `generate` action accepts a `resume` option (in config or options).
    *   When resuming, the earlier tool requests are resolved using the provided `resume` data and any `pendingOutput` from the previous turn.
    *   The resolved tool responses are appended to the history, and the model is called to continue generation.

## Implementation Details

### 1. `ToolInterruptException`

A new exception class in `package:genkit/src/ai/interrupt.dart`.

```dart
class ToolInterruptException {
  final dynamic interrupt; // The data payload
  ToolInterruptException(this.interrupt);
}
```

### 2. Context Extension

We add an extension on `ActionFnArg` (in `tool.dart` or `interrupt.dart`) to allow tools to interrupt easily.

```dart
extension ToolInterrupt on ActionFnArg {
  void interrupt([dynamic data]) {
    throw ToolInterruptException(data ?? true);
  }
}
```

### 3. Modifying `generate.dart`

The `_runGenerateLoop` function needs two major changes:

#### A. Pre-loop Resume Logic

Before entering the loop (or calling the model), we check if we are in a "Resume" state.
We are in a resume state if `options.resume` is not null AND the last message in `messages` contains tool requests.

```dart
// Pseudo-code in _runGenerateLoop
if (options.resume != null && messages.last.role == Role.model && hasToolRequests(messages.last)) {
    // Construct Tool Response Message
    final toolResponses = [];
    for (final part in messages.last.content) {
        if (part is ToolRequestPart) {
           // Resolve using pendingOutput or options.resume info
           // ...
        }
    }
    // Append toolResponses to history
    currentRequest.messages.add(Message(role: Role.tool, content: toolResponses));
    // Proceed to loop (which will call composedModel with this new history)
}
```

#### B. Tool Execution Loop with Interrupt Handling

Inside the loop, when executing tools:

```dart
    final toolResponses = <Part>[];
    bool interrupted = false;
    final executedToolRequests = <(ToolRequestPart, dynamic)>[]; // Track request + result/interrupt

    for (final toolRequest in toolRequests) {
      // ... lookup tool ...
      try {
        // Execute tool
        final response = await composedTool(...);
        toolResponses.add(ToolResponsePart(toolResponse: response));
        executedToolRequests.add((toolRequest, response)); 
      } on ToolInterruptException catch (e) {
        interrupted = true;
        executedToolRequests.add((toolRequest, e));
      } catch (e) {
          // Normal error handling
      }
    }

    if (interrupted) {
        // Construct new ModelResponse with metadata
        // 1. Copy original model response
        // 2. Update ToolRequestParts in the message content:
        //    - If it was the one interrupted: add metadata {'interrupt': e.interrupt}
        //    - If it completed: add metadata {'pendingOutput': result.output}
        
        return GenerateResponseHelper(
            newResponse, 
            output: ...
        );
    }
```

### 4. Resume Data Structure

The `resume` option in `GenerateActionOptions` is a `Map<String, dynamic>`.
We expect it to have a structure similar to:
```json
{
  "respond": [
    {
      "ref": "...", 
      "name": "...",
      "output": ...
    }
  ]
}
```
Or simply a list of tool responses that match the requests.

## User Experience

```dart
@Schematic()
class TriviaQuestions { ... }

final triviaTool = ai.defineTool(
  name: 'present_questions',
  inputSchema: TriviaQuestions.$schema,
  fn: (input, ctx) {
    ctx.interrupt(input); // Throws
  }
);

// First call
final response = await ai.generate(
  prompt: 'Give me trivia',
  tools: ['present_questions'],
);

if (response.finishReason == FinishReason.interrupted) {
  final interruptData = response.toolRequests.first.metadata?['interrupt'];
  // Handle interaction... get answer...
  
  // Resume
  final response2 = await ai.generate(
    options: GenerateActionOptions(
        messages: response.messages, // History includes the interrupt turn
        tools: ['present_questions'],
        resume: {
            'respond': [
                {'name': 'present_questions', 'output': 'User Answer'}
            ]
        }
    )
  );
}
```
