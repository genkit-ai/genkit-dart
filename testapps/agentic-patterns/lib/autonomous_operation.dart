import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

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

final researchAgent = ai.defineFlow(
  name: 'researchAgent',
  inputSchema: ResearchAgentInput.$schema,
  outputSchema: stringSchema(),
  fn: (input, _) async {
    var messages = [
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
    ];

    var response = await ai.generate(
      model: geminiFlash,
      messages: messages,
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
          final question = interrupt.metadata as String?;
          // In a real CLI app, we would prompt the user here.
          // For this sample, we'll simulate a user response.
          print('\n[Agent requested input]: $question');
          final simulatedAnswer =
              'I am interested in efficiency and scalability.';
          print('[User answered]: $simulatedAnswer\n');

          resumeResponses.add(
            InterruptResponse(
              // We need to find the ToolRequestPart corresponding to this interrupt
              // The `interrupt` object in `GenerateResponse` might not link back to the part directly yet in Dart SDK?
              // `interrupt_test.dart` uses `response1.message!.content.first.toolRequestPart!`.
              // We should look it up in `response.message!.content`.
              response.message!.content.whereType<ToolRequestPart>().firstWhere(
                    (p) => p.toolRequest == interrupt.toolRequest,
                  ),
              simulatedAnswer,
            ),
          );
        }
      }

      if (resumeResponses.isEmpty) {
        break;
      }

      // Resume execution with user feedback
      // We append the previous model message to history (handled by `messages` + `resume` logic typically?
      // Wait, `generate` with `resume` expects `messages` to include the history up to the interruption?
      // `interrupt_test.dart` constructs history manually: `history = [UserMessage, response1.message!]`.
      messages = [...messages, response.message!];

      response = await ai.generate(
        model: geminiFlash,
        messages: messages,
        tools: [searchWeb.name, askUser.name],
        resume: resumeResponses,
      );
    }

    return response.text;
  },
);
