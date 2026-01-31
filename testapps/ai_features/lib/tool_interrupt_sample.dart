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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'tool_interrupt_sample.g.dart';

@Schematic()
abstract class $TriviaQuestions {
  @Field(description: 'the main question')
  String get question;

  @Field(
      description:
          'list of multiple choice answers (typically 4), 1 correct 3 wrong')
  List<String> get answers;
}

Future<void> main(List<String> args) async {
  // Initialize Genkit with Google AI plugin
  final ai = Genkit(
    plugins: [googleAI()],
  );

  // Define the tool
  ai.defineTool(
    name: 'present_questions',
    description:
        "can present questions to the user, responds with the user' selected answer",
    inputSchema: TriviaQuestions.$schema,
    fn: (input, ctx) async {
      // input is TriviaQuestions (generated class)
      ctx.interrupt(input);
    },
  );

  print('Generating trivia question...');
  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: '''
      Generate a trivia question and call present_questions tool to present it to the user.
      Answers are provided numbered starting from 1. When answer is provided, be dramatic about
      saying whether the answer is correct or wrong.
    ''',
    tools: ['present_questions'],
  );

  if (response.finishReason == FinishReason.interrupted) {
    print('\nFlow interrupted!');
    final interruptPart = response.interrupts.first;
    // interruptData from metadata
    final interruptData = interruptPart.metadata?['interrupt'];

    final questions = interruptData as TriviaQuestions;

    print('\n--- TRIVIA TIME ---');
    print('Q: ${questions.question}');
    for (var i = 0; i < questions.answers.length; i++) {
      print('   (${i + 1}) ${questions.answers[i]}');
    }
    print('-------------------\n');

    // Read user input
    stdout.write('Your Answer (number): ');
    final userSelection = stdin.readLineSync()?.trim();
    if (userSelection == null || userSelection.isEmpty) {
      print('No answer provided. Exiting.');
      return;
    }

    print('User selected: $userSelection');

    // Resume flow
    print('\nResuming flow with answer...');
    final response2 = await ai.generate(
      model: googleAI.gemini('gemini-2.5-flash'),
      messages: response.messages,
      tools: ['present_questions'],
      resume: [
        InterruptResponse(interruptPart, userSelection),
      ],
    );

    print('\nHost Response:\n${response2.text}');
  } else {
    print(
        'Flow finished without interrupt (unexpected): ${response.finishReason}');
    print(response.text);
  }
}
