# Remote Models Sample

This test application demonstrates how to serve Genkit models using `genkit_shelf` and how to consume them from another Genkit client application using `defineRemoteModel`.

## Running the Example

1. Ensure you have your API keys set in your environment variables:
   - `GEMINI_API_KEY` for Google Generative AI
   - `OPENAI_API_KEY` for OpenAI

2. Start the server (which hosts the models):
   ```bash
   dart run bin/server.dart
   ```
   The server will start on port 8080 and require a `super-secret` bearer token for authentication.

3. In a separate terminal, run the client:
   ```bash
   dart run bin/client.dart
   ```
   The client will connect to the local server, authenticate using the secret token, and execute a sample flow that calls both the Gemini and GPT-4o remote models.
