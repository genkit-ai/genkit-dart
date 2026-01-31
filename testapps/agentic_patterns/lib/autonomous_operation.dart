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
import 'package:schemantic/schemantic.dart';

part 'autonomous_operation.g.dart';

@Schematic()
abstract class $ResearchAgentInput {
  String get task;
}

@Schematic()
abstract class $AgentSearchInput {
  String get query;
}

@Schematic()
abstract class $AgentAskUserInput {
  String get question;
}

Flow<ResearchAgentInput, String, void, void> defineResearchAgent(
  Genkit ai,
  ModelRef geminiFlash,
) {
  // A tool for the agent to search the web
  final searchWeb = ai.defineTool(
    name: 'searchWeb',
    description: 'Search the web for information on a given topic.',
    inputSchema: AgentSearchInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      // In a real app, you would implement a web search API call here.
      return 'You found search results for: ${input.query}';
    },
  );

  // A tool for the agent to ask the user a question
  final askUser = ai.defineTool(
    name: 'askUser',
    description: 'Ask the user a clarifying question.',
    inputSchema: AgentAskUserInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, context) async {
      // Interrupt execution to get user input
      context.interrupt(input.question);
    },
  );

  return ai.defineFlow(
    name: 'researchAgent',
    inputSchema: ResearchAgentInput.$schema,
    outputSchema: stringSchema(),
    fn: (input, _) async {
      var response = await ai.generate(
        model: geminiFlash,
        messages: [
          Message(
            role: Role.system,
            content: [
              TextPart(
                text:
                    "You are a helpful research assistant. Your goal is to provide a comprehensive answer to the user's task.",
              ),
            ],
          ),
          Message(
            role: Role.user,
            content: [
              TextPart(
                text:
                    'Your task is: ${input.task}. Use the available tools to accomplish this.',
              ),
            ],
          ),
        ],
        tools: [searchWeb.name, askUser.name],
      );

      // Handle interrupts loop
      while (response.finishReason == FinishReason.interrupted) {
        final interrupts = response.interrupts;
        if (interrupts.isEmpty) {
          break;
        }

        final resumeResponses = <InterruptResponse>[];

        for (final interrupt in interrupts) {
          if (interrupt.toolRequest.name == askUser.name) {
            final question = interrupt.metadata?['interrupt'] as String?;
            // In a real CLI app, we would prompt the user here.
            // For this sample, we'll simulate a user response.
            print('\n[Agent requested input]: $question');
            final simulatedAnswer =
                'I am interested in efficiency and scalability. Linux OS. My budget is \$1500.';
            print('[User answered]: $simulatedAnswer\n');

            resumeResponses.add(
              InterruptResponse(
                interrupt,
                simulatedAnswer,
              ),
            );
          }
        }

        if (resumeResponses.isEmpty) {
          break;
        }

        // Resume execution with user feedback
        response = await ai.generate(
          model: geminiFlash,
          messages: [...response.messages, response.message!],
          tools: [searchWeb.name, askUser.name],
          resume: resumeResponses,
        );
      }

      return response.text;
    },
  );
}
