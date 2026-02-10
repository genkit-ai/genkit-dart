# OpenAI Compatibility Test Application

This directory contains a test application for the `genkit_openai_compat` package, demonstrating various features and use cases.

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

### Run All Examples

Run all examples in sequence:

```bash
dart run lib/main.dart [API_KEY]
```

Or with environment variable set:

```bash
dart run lib/main.dart
```

This will run through all examples demonstrating:
- Simple text generation
- Streaming responses
- Tool calling with weather data
- Multi-turn conversations with context

## Individual Examples

You can also run individual standalone examples:

### Basic Generation

```bash
dart run bin/basic_example.dart YOUR_API_KEY
```

Demonstrates:
- Simple text generation
- Using custom options (temperature, maxTokens)
- Testing different models

### Streaming

```bash
dart run bin/streaming_example.dart YOUR_API_KEY
```

Shows real-time streaming of responses.

### Tool Calling

```bash
dart run bin/tool_calling_example.dart YOUR_API_KEY
```

Demonstrates function calling with weather and calculator tools.

### Conversations

```bash
dart run bin/conversation_example.dart YOUR_API_KEY
```

Shows multi-turn conversations with context preservation.

## What's Demonstrated

This test app showcases:

- ✅ **Basic text generation** with OpenAI models
- ✅ **Streaming responses** for real-time output
- ✅ **Tool calling** with typed schemas
- ✅ **Multi-turn conversations** with message history
- ✅ **Custom options** (temperature, maxTokens, etc.)
- ✅ **Multiple models** (GPT-4o Mini, GPT-3.5 Turbo)

## Using with OpenAI-Compatible APIs

The examples can be modified to work with other OpenAI-compatible APIs (Groq, xAI, DeepSeek) by changing the `baseURL` parameter when initializing the plugin. See the package README for details.
