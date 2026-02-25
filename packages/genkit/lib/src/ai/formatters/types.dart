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

import '../../types.dart';
import '../generate_types.dart';

/// Function type for parsing a message.
typedef MessageParser<Output> = Output Function(Message message);

/// Function type for parsing a chunk.
typedef ChunkParser<Output> =
    Output Function(GenerateResponseChunk<Output> chunk);

/// Return type for formatter handlers.
class FormatterHandlerResult<Output> {
  final MessageParser<Output> parseMessage;
  final ChunkParser<Output>? parseChunk;
  final String? instructions;

  FormatterHandlerResult({
    required this.parseMessage,
    this.parseChunk,
    this.instructions,
  });
}

/// A formatter defines how to configure a generation request and parse the response
/// for a specific output format.
class Formatter<Output> {
  final String name;
  final GenerateActionOutputConfig config;
  final FormatterHandlerResult<Output> Function(Map<String, dynamic>? schema)
  handler;

  Formatter({required this.name, required this.config, required this.handler});
}
