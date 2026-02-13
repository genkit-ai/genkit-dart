import 'dart:convert';
import 'package:genkit/genkit.dart';
import 'package:genkit_middleware/tool_approval.dart';
import 'package:schemantic/schemantic.dart';

void main() async {
  // Initialize standard framework
  final genkit = Genkit(plugins: [ToolApprovalPlugin()], isDevEnv: false);

  // Define a tool that transfers funds
  genkit.defineTool(
    name: 'transferFunds',
    description: 'Transfers funds between accounts. Requires user approval.',
    inputSchema: mapSchema(
      stringSchema(),
      stringSchema(),
    ), // simpler string-map schema
    fn: (input, context) async {
      // Since it's a generic Map<String, String> we access safely:
      final from = input['from'];
      final to = input['to'];
      return 'SUCCESS: Transferred funds from $from to $to';
    },
  );

  // Simple mock model that will trigger the tool
  genkit.defineModel(
    name: 'banking-assistant',
    fn: (req, ctx) async {
      // If we resumed from an interrupt, there will be a tool response
      if (req.messages.last.role == Role.tool) {
        final toolResponse =
            req.messages.last.content.first.toolResponsePart!.toolResponse;
        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(
            role: Role.model,
            content: [
              TextPart(
                text: 'Bank Agent: Action complete. ${toolResponse.output}',
              ),
            ],
          ),
        );
      }

      // Initially trigger the tool
      return ModelResponse(
        finishReason: FinishReason.stop,
        message: Message(
          role: Role.model,
          content: [
            ToolRequestPart(
              toolRequest: ToolRequest(
                name: 'transferFunds',
                input: {'from': 'Checking', 'to': 'Savings'},
              ),
            ),
          ],
        ),
      );
    },
  );

  // Create the middleware, note how transferFunds is NOT approved
  final approvalMw = toolApproval(
    approved: ['checkBalance', 'findNearestBranch'],
  );

  print('--- Initial Run ---');
  final response1 = await genkit.generate(
    model: modelRef('banking-assistant'),
    prompt: 'transfer my funds',
    use: [approvalMw],
    toolNames: ['transferFunds'],
  );

  if (response1.finishReason == FinishReason.interrupted) {
    print(
      'Execution interrupted! Reason: ${response1.message?.content.first.metadata?['interrupt']}',
    );
    final interrupt = response1.interrupts.first;
    print(
      'Intercepted Tool Call: ${interrupt.toolRequest.name}(${jsonEncode(interrupt.toolRequest.input)})',
    );
    print('Awaiting User Approval...');

    // Simulate user approval by resuming the execution and passing the appropriate metadata
    print('\n--- Resuming Run with Approval ---');
    final response2 = await genkit.generate(
      model: modelRef('banking-assistant'),
      messages: response1.messages,
      use: [approvalMw],
      toolNames: ['transferFunds'],
      interruptRestart: [
        ToolRequestPart(
          toolRequest: interrupt.toolRequest,
          // Inject metadata indicating the tool call was approved by the user
          metadata: {'tool-approved': true},
        ),
      ],
    );

    print(response2.text);
  }

  await genkit.shutdown();
}
