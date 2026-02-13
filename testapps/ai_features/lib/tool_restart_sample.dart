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

part 'tool_restart_sample.g.dart';

@Schematic()
abstract class $ApprovalRequest {
  @Field(description: 'the main question')
  String get question;

  @Field(description: 'request for approval details')
  String get details;
}

Future<void> main(List<String> args) async {
  configureCollectorExporter();

  // Initialize Genkit with Google AI plugin
  final ai = Genkit(plugins: [googleAI()]);

  var isApproved = false;

  // Define the tool
  ai.defineTool(
    name: 'transfer_funds',
    description: "transfer funds, requires user approval",
    inputSchema: ApprovalRequest.$schema,
    fn: (input, ctx) async {
      // Check if context has approval flag to simulate state or auth passing
      if (!isApproved) {
        ctx.interrupt(input);
      }
      return 'Successfully transferred funds! Details: ${input.details}';
    },
  );

  print('Generating fund transfer request...');
  final response = await ai.generate(
    model: googleAI.gemini('gemini-2.5-flash'),
    prompt: '''
      Transfer \$500 to the account '12345-6789'.
    ''',
    tools: ['transfer_funds'],
  );

  if (response.finishReason == FinishReason.interrupted) {
    print('\nFlow interrupted!');
    final interruptPart = response.interrupts.first;
    // interruptData from metadata
    final interruptData = interruptPart.metadata?['interrupt'];

    if (interruptData is! ApprovalRequest) {
      print(
        'Error: Unexpected interrupt data type: ${interruptData?.runtimeType}',
      );
      return;
    }
    final request = interruptData;

    print('\n--- APPROVAL REQUIRED ---');
    print('Action: ${request.details}');
    print('-------------------------\n');

    // Read user input
    stdout.write('Approve this transfer? (y/n): ');
    final userSelection = stdin.readLineSync()?.trim().toLowerCase();
    if (userSelection != 'y') {
      print('Transfer rejected. Exiting.');
      return;
    }

    print('User approved the transfer.');

    // Resume flow
    print('\nRestarting tool execution with approval...');

    // Pass approval flag through action context so the tool succeeds on restart
    isApproved = true;

    final response2 = await ai.generate(
      model: googleAI.gemini('gemini-2.5-flash'),
      messages: response.messages,
      tools: ['transfer_funds'],
      interruptRestart: [interruptPart], // Null output = Restart
    );

    print('\nModel Response:\n${response2.text}');
  } else {
    print(
      'Flow finished without interrupt (unexpected): ${response.finishReason}',
    );
    print(response.text);
  }
}
