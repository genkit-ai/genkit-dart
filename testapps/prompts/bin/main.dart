// Copyright 2025 Google LLC
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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:prompts_testapp/schemas.dart';

/// Testapp that exercises various prompt features:
/// - .prompt files loaded from the `prompts/` directory (with picoschema inputs)
/// - Inline definePrompt with Handlebars templates and generated input schemas
/// - Prompt variants (.formal variant)
/// - Partials (_signature.prompt)
/// - defineCustomPrompt for programmatic prompt building
/// - Flows that use prompts
void main() {
  final ai = Genkit(plugins: [googleAI()], promptDir: './prompts');

  // --- Inline definePrompt with generated input schema ---

  final jokePrompt = ai.definePrompt<Map<String, dynamic>, JokeInput>(
    name: 'joke',
    model: modelRef('googleai/gemini-flash-latest'),
    config: {'temperature': 0.9},
    inputSchema: JokeInput.schema,
    system: 'You are a witty comedian. Keep jokes family-friendly.',
    prompt: 'Tell me a {{style}} joke about {{topic}}.',
  );

  // --- Inline definePrompt with partials and generated input schema ---

  ai.definePrompt<Map<String, dynamic>, EmailInput>(
    name: 'email',
    model: modelRef('googleai/gemini-flash-latest'),
    config: {'temperature': 0.5},
    inputSchema: EmailInput.schema,
    system: 'You are a professional email composer.',
    prompt: '''Write a short email to {{recipient}} about {{subject}}.

{{> signature}}''',
  );

  // --- defineCustomPrompt with generated input schema ---

  ai.defineCustomPrompt<StoryInput>(
    name: 'custom-story',
    description: 'Programmatically builds a story prompt with character list',
    inputSchema: StoryInput.schema,
    fn: (input, ctx) async {
      final genre = input.genre;
      final charList = input.characters.map((c) => '- $c').join('\n');

      return GenerateActionOptions(
        model: 'googleai/gemini-flash-latest',
        config: {'temperature': 0.8},
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text: 'You are a creative storyteller specializing in $genre.',
              ),
            ],
          ),
          Message(
            role: Role.user,
            content: [
              TextPart(
                text:
                    'Write a short $genre story featuring these characters:\n$charList',
              ),
            ],
          ),
        ],
      );
    },
  );

  // --- Flows that use prompts ---

  // Flow: tell a joke using the inline prompt
  ai.defineFlow(
    name: 'tellJoke',
    fn: (Map<String, dynamic>? input, ctx) async {
      final topic = input?['topic'] as String? ?? 'programming';
      final style = input?['style'] as String? ?? 'punny';
      final response = await jokePrompt(JokeInput(topic: topic, style: style));
      return response.text;
    },
  );

  // Flow: greet someone using the .prompt file
  ai.defineFlow(
    name: 'greetUser',
    fn: (Map<String, dynamic>? input, ctx) async {
      final greetingPrompt = await ai.prompt('greeting');
      final response = await greetingPrompt({
        'name': input?['name'] ?? 'World',
        'style': input?['style'] ?? 'cheerful',
      });
      return response.text;
    },
  );

  // Flow: formal greeting using the .prompt variant
  ai.defineFlow(
    name: 'formalGreeting',
    fn: (Map<String, dynamic>? input, ctx) async {
      final formalPrompt = await ai.prompt('greeting', variant: 'formal');
      final response = await formalPrompt({
        'name': input?['name'] ?? 'Dr. Smith',
        'title': input?['title'] ?? 'Professor',
      });
      return response.text;
    },
  );

  // Flow: summarize text using the .prompt file
  ai.defineFlow(
    name: 'summarizeText',
    fn: (Map<String, dynamic>? input, ctx) async {
      final summarizePrompt = await ai.prompt('summarize');
      final response = await summarizePrompt({
        'text': input?['text'] ?? 'No text provided.',
        'maxSentences': input?['maxSentences'] ?? '3',
      });
      return response.text;
    },
  );

  // Flow: render a prompt without calling the model
  ai.defineFlow(
    name: 'renderPrompt',
    fn: (Map<String, dynamic>? input, ctx) async {
      final greetingPrompt = await ai.prompt('greeting');
      final rendered = await greetingPrompt.render({
        'name': input?['name'] ?? 'World',
        'style': input?['style'] ?? 'casual',
      });
      // Return the rendered messages as a serializable map
      return {
        'model': rendered.model,
        'messages': rendered.messages.map((m) => m.toJson()).toList(),
      };
    },
  );
}
