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
/// - Typed structured output via `outputSchema` (and typed `.prompt` lookup)
/// - Prompt variants (.formal variant)
/// - Partials (_signature.prompt)
/// - defineCustomPrompt for programmatic prompt building
/// - Named schemas (defineSchema) referenced from .prompt files
/// - Flows that use prompts, including per-call options (config, history)
void main() {
  final ai = Genkit(plugins: [googleAI()], promptDir: './prompts');

  // --- Named schema referenced by name from a .prompt file ---
  //
  // `prompts/recipe.prompt` declares `output.schema: Recipe`. The name is
  // looked up when the prompt is rendered, so defining it after the
  // constructor (which loads the prompt folder) is fine.
  ai.defineSchema('Recipe', {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'ingredients': {
        'type': 'array',
        'items': {'type': 'string'},
      },
      'steps': {
        'type': 'array',
        'items': {'type': 'string'},
      },
    },
    'required': ['title', 'ingredients', 'steps'],
  });

  // --- Inline definePrompt with typed input and output ---
  //
  // Both type arguments are inferred from the schemas, so `jokePrompt` is an
  // `Prompt<JokeInput, Joke>` and `response.output` is a `Joke?`.

  final jokePrompt = ai.definePrompt(
    name: 'joke',
    model: modelRef('googleai/gemini-flash-latest'),
    config: {'temperature': 0.9},
    inputSchema: JokeInput.schema,
    outputSchema: Joke.schema,
    system: 'You are a witty comedian. Keep jokes family-friendly.',
    prompt: 'Tell me a {{style}} joke about {{topic}}.',
  );

  // --- Inline definePrompt with partials and generated input schema ---
  //
  // No outputSchema, so this one stays untyped: `response.output` is dynamic
  // and `response.text` is the natural way to read it.

  ai.definePrompt(
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

  // Flow: tell a joke using the inline prompt. `response.output` is a `Joke?`,
  // so the fields are reachable without a cast.
  ai.defineFlow(
    name: 'tellJoke',
    outputSchema: Joke.schema,
    fn: (Map<String, dynamic>? input, ctx) async {
      final topic = input?['topic'] as String? ?? 'programming';
      final style = input?['style'] as String? ?? 'punny';
      final response = await jokePrompt(JokeInput(topic: topic, style: style));

      // Statically a `Joke?` -- no cast, no map indexing.
      final joke = response.output;
      if (joke == null) {
        throw StateError('Model returned no joke: ${response.finishReason}');
      }
      return joke;
    },
  );

  // Flow: per-call options. `prompt.call` / `stream` / `render` take the same
  // named parameters as `ai.generate` (minus the prompt's own content):
  // scalars replace the prompt's value, `config` is merged over it, and
  // `messages` is the conversation history.
  ai.defineFlow(
    name: 'followUpJoke',
    outputSchema: Joke.schema,
    fn: (Map<String, dynamic>? input, ctx) async {
      final topic = input?['topic'] as String? ?? 'programming';
      final response = await jokePrompt(
        JokeInput(topic: topic, style: 'dry'),
        config: {'temperature': 0.2},
        messages: [
          Message(
            role: Role.user,
            content: [TextPart(text: 'My last joke was about printers.')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'Noted. I will avoid printers.')],
          ),
        ],
      );
      final joke = response.output;
      if (joke == null) {
        throw StateError('Model returned no joke: ${response.finishReason}');
      }
      return joke;
    },
  );

  // Flow: stream a joke. A chunk's typed `output` stays null until the partial
  // JSON satisfies the Joke schema (here: both fields present), so stream the
  // raw text as it arrives and take the typed Joke from the final result.
  ai.defineFlow(
    name: 'streamJoke',
    streamSchema: .string(),
    outputSchema: Joke.schema,
    fn: (Map<String, dynamic>? input, ctx) async {
      final topic = input?['topic'] as String? ?? 'programming';
      final stream = jokePrompt.stream(JokeInput(topic: topic, style: 'punny'));
      await for (final chunk in stream) {
        ctx.sendChunk(chunk.text);
      }
      final joke = (await stream.onResult).output;
      if (joke == null) throw StateError('Model returned no joke');
      return joke;
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

  // Flow: summarize text using the .prompt file, looked up with types.
  //
  // The file's frontmatter carries the schema the model is asked for, but not
  // a Dart type, so `outputParserSchema` supplies the parser and
  // `response.output` comes back a `Summary?`.
  ai.defineFlow(
    name: 'summarizeText',
    outputSchema: Summary.schema,
    fn: (Map<String, dynamic>? input, ctx) async {
      final summarizePrompt = await ai.prompt(
        'summarize',
        outputParserSchema: Summary.schema,
      );
      final response = await summarizePrompt({
        'text': input?['text'] ?? 'No text provided.',
        'maxSentences': input?['maxSentences'] ?? '3',
      });

      final summary = response.output;
      if (summary == null) {
        throw StateError('Model returned no summary: ${response.finishReason}');
      }
      return summary;
    },
  );

  // Flow: structured output whose schema is a `defineSchema` name.
  ai.defineFlow(
    name: 'recipe',
    fn: (Map<String, dynamic>? input, ctx) async {
      final recipePrompt = await ai.prompt('recipe');
      final response = await recipePrompt({'food': input?['food'] ?? 'pasta'});
      return response.output;
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
