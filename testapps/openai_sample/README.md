# OpenAI Compatibility Test Application

This directory contains a test application for the `genkit_openai` package, demonstrating various features and use cases.

## Prerequisites

1. **Install Dart dependencies**:

   ```bash
   dart pub get
   ```

2. **Generate code** (for schemas):

   ```bash
   dart run build_runner build
   ```

3. **Set up API key**:

   The examples require an OpenAI API key. You can either:
   
   - Pass it as an argument when running
   - Set it as an environment variable:
   
   **PowerShell:**
   ```powershell
   $env:OPENAI_API_KEY="your-key-here"
   ```
   
   **Bash:**
   ```bash
   export OPENAI_API_KEY=your-key-here
   ```

## Running the Application

Start the application to define Genkit flows:

```bash
dart run lib/main.dart [API_KEY]
```

Or with environment variable set:

```bash
dart run lib/main.dart
```

This initializes the Genkit application and defines the following flows:
- `simpleGenerate` - Basic text generation
- `creativeGenerate` - Creative generation with high temperature
- `streamGenerate` - Streaming text generation
- `weatherQuery` - Get weather using tool calling
- `assistant` - AI assistant with weather tool
- `dartExpert` - Dart/Flutter expert with system prompt

## Using with Genkit UI

To interact with the flows through the Genkit UI:

```bash
npx genkit start -- dart run lib/main.dart
```

This will open the Genkit Developer UI where you can test each flow interactively.

## What's Demonstrated

This test app defines Genkit flows that showcase:

- ✅ **Basic text generation** with OpenAI models
- ✅ **Streaming responses** for real-time output
- ✅ **Tool calling** with typed schemas (weather tool)
- ✅ **System prompts** for specialized assistants
- ✅ **Custom options** (temperature, maxTokens, etc.)
- ✅ **Multiple flow types** for different use cases

## Using with OpenAI-Compatible APIs

The examples can be modified to work with other OpenAI-compatible APIs (Groq, xAI, DeepSeek) by changing the `baseUrl` parameter when initializing the plugin. See the package README for details.
