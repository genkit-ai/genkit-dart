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

/// Banking agent — human-in-the-loop approval via a restartable tool.
///
/// Instead of a separate `userApproval` interrupt, the `transferMoney` tool is
/// itself restartable and guards the transfer with a *conditional* interrupt:
/// if the amount is over $100 and the tool request was not explicitly approved
/// (via a `transfer-approved` flag in its request metadata), the tool
/// interrupts before moving any money.
///
/// This is more secure than a model-driven approval step: the check lives
/// inside the tool, so the user cannot talk the agent into skipping it. The
/// client approves by *restarting* the tool with `transfer-approved: true` in
/// the metadata (see `banking_page.dart`), which re-executes it and lets the
/// transfer through.
library;

import 'package:genkit/genkit.dart';
import 'package:schemantic/schemantic.dart';

import 'genkit.dart';

part 'banking_agent.g.dart';

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

/// Metadata key the client sets (via a tool restart) to approve a transfer that
/// the conditional interrupt would otherwise block.
const transferApprovedMetadataKey = 'transfer-approved';

/// The threshold above which a transfer requires explicit user approval.
const transferApprovalThreshold = 100;

/// Executes a money transfer.
///
/// Transfers over [transferApprovalThreshold] require explicit approval: unless
/// the tool request carries `transfer-approved: true` in its metadata, the tool
/// interrupts instead of transferring. The client resolves the interrupt by
/// restarting the tool with that metadata set (see `banking_page.dart`).
final transferMoney = ai.defineTool(
  name: 'transferMoney',
  description: 'Transfer money to a specified account.',
  inputSchema: TransferMoneyInput.$schema,
  outputSchema: TransferMoneyOutput.$schema,
  fn: (input, ctx) async {
    final approved =
        ctx.toolRequest?.metadata?[transferApprovedMetadataKey] == true;

    // Enforce approval inside the tool so the model cannot be talked into
    // skipping it. Restarting with `transfer-approved: true` clears this gate.
    if (input.amount > transferApprovalThreshold && !approved) {
      ctx.interrupt({
        'message':
            'Transfer of \$${input.amount} to ${input.toAccount} requires '
            'your approval.',
        'amount': input.amount,
        'toAccount': input.toAccount,
      });
    }

    return TransferMoneyOutput(
      success: true,
      transactionId: 'txn-${DateTime.now().millisecondsSinceEpoch}',
    );
  },
);

final bankingAgent = ai.defineAgent(
  name: 'bankingAgent',
  system:
      'You are a helpful banking assistant. Use the transferMoney tool to '
      'transfer money. Large transfers may pause for the user to approve them '
      'before completing.',
  use: [retry()],
  tools: [transferMoney],
  store: InMemorySessionStore(),
);
