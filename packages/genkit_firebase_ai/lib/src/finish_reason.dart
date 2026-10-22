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

import 'package:genkit/plugin.dart';

/// Maps a Gemini finish reason wire value onto Genkit's vocabulary.
///
/// Switches on the wire value, not the enum, because `firebase_ai` adds
/// members in minor releases. `firebase_ai` parses unrecognized wire values
/// as `FinishReason.unknown`, so those surface as [FinishReason.unknown].
FinishReason finishReasonFromWire(String? wire) {
  switch (wire) {
    case 'STOP':
      return FinishReason.stop;
    case 'MAX_TOKENS':
      return FinishReason.length;
    case 'SAFETY':
    case 'RECITATION':
    case 'LANGUAGE':
    case 'BLOCKLIST':
    case 'PROHIBITED_CONTENT':
    case 'SPII':
    case 'IMAGE_SAFETY':
    case 'IMAGE_PROHIBITED_CONTENT':
    case 'IMAGE_RECITATION':
    case 'MODEL_ARMOR':
    case 'ESCALATION':
    case 'PUP_LIMITED_DISABLED':
      return FinishReason.blocked;
    case 'MALFORMED_FUNCTION_CALL':
    case 'UNEXPECTED_TOOL_CALL':
    case 'TOO_MANY_TOOL_CALLS':
    case 'NO_IMAGE':
    case 'IMAGE_OTHER':
    case 'MALFORMED_RESPONSE':
    case 'MISSING_THOUGHT_SIGNATURE':
    case 'OTHER':
      return FinishReason.other;
    default:
      return FinishReason.unknown;
  }
}
