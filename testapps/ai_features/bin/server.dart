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

import 'dart:io';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:schemantic/schemantic.dart';

part 'server.g.dart';

@Schema()
abstract class $TransferMoneyInput {
  @Field(description: 'the account id of the transfer destination')
  String get toAccountId;

  @Field(description: 'the amount in integer cents (100 = 1 USD)')
  int get amount;
}

@Schema()
abstract class $TransferMoneyOutput {
  @Field(description: 'the outcome of the transfer')
  String get status;

  @Field(description: 'message')
  String? get message;
}

@Schema()
abstract class $AskQuestionInput {
  @Field(description: 'the choices to display to the user')
  List<String> get choices;

  @Field(description: 'when true, allow write-ins')
  bool? get allowOther;
}

void main(List<String> args) async {
  final ai = Genkit(plugins: [googleAI()]);

  final transferMoney = ai.defineTool(
    name: 'transferMoney',
    description: 'Transfers money between accounts.',
    inputSchema: TransferMoneyInput.$schema,
    outputSchema: TransferMoneyOutput.$schema,
    fn: (input, ctx) async {
      final resumedData = ctx.resumed;
      final resumedStatus = resumedData is Map ? resumedData['status'] : null;

      // if the user rejected the transaction
      if (resumedStatus == 'REJECTED') {
        return TransferMoneyOutput(
          status: 'REJECTED',
          message: 'The user rejected the transaction.',
        );
      }

      // trigger an interrupt to confirm if amount > $100
      if (resumedStatus != 'APPROVED' && input.amount > 10000) {
        ctx.interrupt({'message': 'Please confirm sending an amount > \$100.'});
      }

      // complete the transaction if not interrupted
      return TransferMoneyOutput(
        status: 'COMPLETED',
        message: 'Transferred \$${input.amount / 100} to ${input.toAccountId}',
      );
    },
  );

  ai.defineFlow(
    name: 'transferFlowWithRestart',
    fn: (String prompt, ctx) async {
      var response = await ai.generate(
        model: googleAI.gemini('gemini-flash-latest'),
        tools: [transferMoney],
        prompt: prompt,
      );

      while (response.interrupts.isNotEmpty) {
        print('Interrupted, resuming with approval in 5 seconds...');
        await Future.delayed(Duration(seconds: 5));

        final confirmations = <ToolRequestPart>[];
        for (final interrupt in response.interrupts) {
          // use the 'restart' method on our tool to provide `resumed` metadata
          confirmations.add(
            interrupt.toolRequestPart!.restart({'status': 'APPROVED'}),
          );
        }

        print('Resuming');
        response = await ai.generate(
          model: googleAI.gemini('gemini-flash-latest'),
          tools: [transferMoney],
          messages: response.messages,
          interruptRestart: confirmations,
        );
      }

      return response.text;
    },
  );

  final askQuestion = ai.defineTool(
    name: 'askQuestion',
    description: 'use this to ask the user a clarifying question',
    inputSchema: AskQuestionInput.$schema,
    fn: (input, ctx) async {
      // Just interrupt immediately since it's an interactive question
      ctx.interrupt(input);
    },
  );

  ai.defineFlow(
    name: 'transferFlowManual',
    fn: (_, ctx) async {
      final response = await ai.generate(
        prompt: 'Ask me a movie trivia question.',
        tools: [askQuestion],
        model: googleAI.gemini('gemini-flash-latest'),
      );

      final answers = <InterruptResponse>[];
      if (response.interrupts.isNotEmpty) {
        print('Interrupted, resuming with approval in 5 seconds...');
        await Future.delayed(Duration(seconds: 5));
        // multiple interrupts can be called at once, so we handle them all
        for (final question in response.interrupts) {
          answers.add(InterruptResponse(question, 'The answer is C'));
        }
      }

      final finalResponse = await ai.generate(
        tools: [askQuestion],
        model: googleAI.gemini('gemini-flash-latest'),
        messages: response.messages,
        interruptRespond: answers,
      );

      return finalResponse.text;
    },
  );

  if (args.isEmpty) {
    print(
      'Available flows for Dev UI. Run `genkit start -- dart run bin/server.dart`',
    );
    print('Listening... (Press Ctrl+C to exit)');
    // Keep process alive for Genkit Dev UI reflection server
    await ProcessSignal.sigint.watch().first;
    return;
  }

  final command = args[0];
  if (command == 'transfer') {
    final flow = await ai.registry.lookupAction(
      'flow',
      'transferFlowWithRestart',
    );
    final response = await flow!.run('Transfer \$150 to account 123');
    print('Final response: $response');
  } else if (command == 'trivia') {
    final flow = await ai.registry.lookupAction('flow', 'transferFlowManual');
    final response = await flow!.run(null);
    print('Final response: $response');
  } else {
    print('Unknown command. Use "transfer" or "trivia".');
  }
}
