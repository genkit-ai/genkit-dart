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

/// Browser/Flutter-safe client helpers for consuming an A2UI-enabled Genkit
/// agent.
///
/// This library has no server-only dependencies (no `dart:io`). Pull A2UI
/// envelopes off each streamed chunk with [a2uiEnvelopes] and feed them to your
/// renderer (e.g. `genui`'s `SurfaceController`). Send surface actions back to
/// the agent as the next turn with [actionToMessage].
library;

import 'dart:convert';

import 'package:genkit/plugin.dart';

import 'src/part.dart';
import 'src/types.dart';

export 'src/part.dart'
    show a2uiEnvelopes, a2uiEnvelopesFromParts, a2uiPart, isA2uiPart;
export 'src/types.dart'
    show
        A2uiClientAction,
        A2uiComponent,
        A2uiEnvelope,
        a2uiMimeType,
        a2uiVersion,
        basicCatalogId;

/// Builds the agent input message for sending a rendered surface's user action
/// back to the agent as the next turn.
///
/// The action's `name` becomes a human-readable summary so the agent can react
/// to it; the full action object is attached as an a2ui data part for richer
/// handling by the middleware.
Message actionToMessage(A2uiClientAction action) {
  final ctx = action.context.isNotEmpty
      ? ' with context ${jsonEncode(action.context)}'
      : '';
  final summary =
      'User interacted with the UI (surface "${action.surfaceId}"): '
      'action "${action.name}"$ctx.';
  return Message(
    role: Role.user,
    content: [
      TextPart(text: summary),
      a2uiPart([
        {'action': action.toJson()},
      ]),
    ],
  );
}
