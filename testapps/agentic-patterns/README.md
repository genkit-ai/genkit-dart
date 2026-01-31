# Agentic Patterns with Genkit Dart

This project demonstrates various agentic patterns implemented using the Genkit Dart SDK. These samples mirror the patterns found in the Genkit JavaScript SDK.

## Running with Genkit Developer UI

You can interact with the flows using the Genkit Developer UI, which provides a rich interface for testing and inspecting traces.

```bash
genkit start -- dart run bin/main.dart
```

Once running, open the URL provided (usually `http://localhost:4000`) to access the UI.

## Running from the Command Line

You can also run individual samples directly from the command line using the provided CLI runner.

**Usage:**
```bash
dart run bin/main.dart <command> [args]
```

### Available Samples

Below is a list of the available samples and how to run them:

- **Iterative Refinement**
  Generates a draft and improves it based on critique.
  ```bash
  dart run bin/main.dart iterativeRefinement "Sustainable energy"
  ```

- **Sequential Processing**
  Chains multiple steps (Story Idea -> Story Intro).
  ```bash
  dart run bin/main.dart sequentialProcessing "Space exploration"
  ```

- **Parallel Execution**
  Runs tasks in parallel (Product Name & Tagline) and aggregates results.
  ```bash
  dart run bin/main.dart parallelExecution "Smart coffee mug"
  ```

- **Conditional Routing**
  Classifies intent and routes to specific sub-flows (Question vs. Creative).
  ```bash
  dart run bin/main.dart conditionalRouting "Write a poem about cats"
  ```

- **Tool Calling**
  Demonstrates how the LLM calls external tools (e.g., simulated weather).
  ```bash
  dart run bin/main.dart toolCalling "What's the weather in New York?"
  ```

- **Autonomous Operation (Research Agent)**
  A multi-turn agent that uses tools and can interrupt execution to ask the user for clarification.
  ```bash
  dart run bin/main.dart autonomousOperation "Find a good laptop for coding"
  ```

- **Agentic RAG**
  Retrieval Augmented Generation using a tool to fetch relevant context (simulated menu items).
  ```bash
  dart run bin/main.dart agenticRag "Do you have vegan burgers?"
  ```

- **Stateful Interactions**
  Demonstrates managing conversation history across multiple turns using a session ID.
  ```bash
  dart run bin/main.dart statefulInteractions "session-123" "Hello, I'm Bob."
  ```

- **Image Generator**
  Generates a detailed image prompt from a concept and then generates an image using `gemini-2.5-flash-image` (Nano Banana).
  ```bash
  dart run bin/main.dart imageGenerator "Cyberpunk city"
  ```
