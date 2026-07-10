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

/// Banking agent — human-in-the-loop approval via an interrupt.
///
/// Ported from the JS `banking-agent.ts`. The JS sample uses
/// `ai.defineInterrupt`; Dart models an interrupt as a tool that calls
/// `ctx.interrupt(...)`. The agent always asks for user approval (via the
/// `userApproval` interrupt) before executing the `transferMoney` tool. The
/// client resumes the paused turn with the interrupt's `respond` builder,
/// supplying the tool output directly without re-executing the tool.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'banking_agent.g.dart';

@Schema()
abstract class $UserApprovalInput {
  @Field(description: 'The action to be approved')
  String get action;
  @Field(description: 'Details about the action')
  String get details;
}

@Schema()
abstract class $TransferMoneyInput {
  double get amount;
  String get toAccount;
}

@Schema()
abstract class $TransferMoneyOutput {
  bool get success;
  String get transactionId;
}

/// Interrupt that asks the user to approve a sensitive action before
/// proceeding. Modeled as a tool that always interrupts; the client provides
/// the `{ approved, feedback }` output via the interrupt's `respond` builder.
final userApproval = ai.defineTool(
  name: 'userApproval',
  description:
      'Ask the user for approval before proceeding with a sensitive action.',
  inputSchema: UserApprovalInput.$schema,
  // No outputSchema: the output is supplied by the client on resume.
  fn: (input, ctx) async => ctx.interrupt(),
);

/// Executes a money transfer. Only reached after the user approves.
final transferMoney = ai.defineTool(
  name: 'transferMoney',
  description: 'Transfer money to a specified account.',
  inputSchema: TransferMoneyInput.$schema,
  outputSchema: TransferMoneyOutput.$schema,
  fn: (input, _) async => TransferMoneyOutput(
    success: true,
    transactionId: 'txn-${DateTime.now().millisecondsSinceEpoch}',
  ),
);

final bankingAgent = ai.defineAgent(
  name: 'bankingAgent',
  system:
      'You are a helpful banking assistant. If the user wants to transfer '
      'money, ALWAYS use the userApproval interrupt to confirm the details '
      'before executing the transferMoney tool.',
  use: [retry()],
  tools: [userApproval, transferMoney],
  store: InMemorySessionStore(),
);
