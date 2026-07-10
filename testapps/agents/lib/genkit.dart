// Copyright 2026 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

/// Shared Genkit instance and model references for the agents sample.
///
/// Ported from the JS `src/genkit.ts`. The Dart sample targets the Google AI
/// provider only; the API key is read from the `GEMINI_API_KEY` environment
/// variable by the `googleAI()` plugin.
library;

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_middleware/filesystem.dart';
import 'package:genkit_middleware/skills.dart';
import 'package:genkit_middleware/tool_approval.dart';

/// The default (capable) model used by most agents.
final ModelRef defaultModel = googleAI.gemini('gemini-flash-latest');

/// A fast/cheap model for auxiliary tasks (decomposition, safety checks, etc.).
final ModelRef liteModel = googleAI.gemini('gemini-flash-lite-latest');

/// The shared Genkit instance. Prompts are loaded from `./prompts`.
///
/// The middleware plugins (filesystem, skills, tool approval, retry) must be
/// registered here so that the `use: [...]` references in the coding agent
/// resolve at runtime.
final Genkit ai = Genkit(
  plugins: [
    googleAI(),
    FilesystemPlugin(),
    SkillsPlugin(),
    ToolApprovalPlugin(),
    RetryPlugin(),
  ],
  model: defaultModel,
);
