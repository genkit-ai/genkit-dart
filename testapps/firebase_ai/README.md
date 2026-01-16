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

3. **Run the App**
   ```bash
   # Run with Genkit tools (optional, for traces/DevUI)
   genkit start -- flutter run -d macos

   # Or standard Flutter run
   flutter run
   ```

## Features

- Chat with Gemini using Firebase AI.
- Tool calling demonstration (e.g., `getWeather`).
