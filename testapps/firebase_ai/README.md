This is a sample Flutter application demonstrating how to use the `genkit_firebase_ai` plugin.

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A Firebase project with "Blaze" plan (for Vertex AI) or appropriate setup for Gemini.

## Setup

1. **Install Dependencies**
   ```bash
   flutter pub get
   ```

2. **Configure Firebase**
   This project requires `firebase_options.dart` which is git-ignored. Generate it using `flutterfire`:

   ```bash
   flutterfire configure
   ```
   Select your project and platforms (iOS, Android, macOS, Web).

3. **Run the App with Observability (Telemetry)**
   To see Genkit traces and telemetry during development:

   First, start the Genkit Developer UI:
   ```bash
   genkit start
   ```
   Look for the output line: `Telemetry API running on http://localhost:4033`. (Usually it's port 4033, but it can be different).

   Then, in another terminal, run your Flutter app and pass the telemetry server address:
   ```bash
   flutter run --dart-define=GENKIT_ENV=dev --dart-define=GENKIT_TELEMETRY_SERVER=http://localhost:4033
   ```
   *(Adjust the port if Genkit assigned a different one)*

   Open http://localhost:4000 in your browser to see the Genkit Developer UI.

   **Standard Flutter run (No Telemetry)**
   ```bash
   flutter run
   ```

## Features

- Chat with Gemini using Firebase AI.
- Tool calling demonstration (e.g., `getWeather`).
