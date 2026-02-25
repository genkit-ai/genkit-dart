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
import 'package:genkit_mcp/src/util/convert_messages.dart';
import 'package:genkit_mcp/src/util/convert_prompts.dart';
import 'package:genkit_mcp/src/util/convert_tools.dart';
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

class _BadPromptSchema extends SchemanticType<Map<String, dynamic>> {
  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': {
        'count': {'type': 'integer'},
      },
    }),
    dependencies: const [],
  );
}

class _NullableStringPromptSchema extends SchemanticType<Map<String, dynamic>> {
  @override
  Map<String, dynamic> parse(dynamic input) {
    return input as Map<String, dynamic>;
  }

  @override
  JsonSchemaMetadata? get schemaMetadata => JsonSchemaMetadata(
    definition: Schema.fromMap({
      'type': 'object',
      'properties': {
        'title': {
          'type': ['string', 'null'],
          'description': 'title arg',
        },
      },
      'required': const <String>[],
    }),
    dependencies: const [],
  );
}

void main() {
  test('prompt arguments enforce string-only properties', () {
    expect(
      () => toMcpPromptArguments(_BadPromptSchema()),
      throwsA(
        predicate(
          (e) =>
              e is GenkitException &&
              e.status == StatusCodes.FAILED_PRECONDITION,
        ),
      ),
    );
  });

  test('prompt arguments allow nullable string types', () {
    final args = toMcpPromptArguments(_NullableStringPromptSchema());
    expect(args, isNotNull);
    expect(args!.first['name'], 'title');
    expect(args.first['description'], 'title arg');
    expect(args.first['required'], isFalse);
  });

  test('tool conversion uses default object schema when input missing', () {
    final ai = Genkit();
    final tool = ai.defineTool<Map<String, dynamic>, String>(
      name: 'plainTool',
      description: 'plain tool',
      fn: (input, _) async => 'ok',
    );

    final payload = toMcpTool(tool);
    final schema = payload['inputSchema'] as Map<String, dynamic>;
    expect(schema[r'$schema'], 'http://json-schema.org/draft-07/schema#');
    expect(schema['type'], 'object');
  });

  test('tool conversion includes execution.taskSupport by default', () {
    final ai = Genkit();
    final tool = ai.defineTool<Map<String, dynamic>, String>(
      name: 'defaultTaskTool',
      description: 'default task tool',
      inputSchema: mapSchema(stringSchema(), dynamicSchema()),
      fn: (input, _) async => 'ok',
    );

    final payload = toMcpTool(tool);
    final execution = payload['execution'] as Map<String, dynamic>;
    expect(execution['taskSupport'], 'optional');
  });

  test('tool conversion allows per-tool execution override via metadata', () {
    // Genkit.defineTool does not expose metadata, so construct Tool directly.
    final forbiddenTool = Tool<Map<String, dynamic>, String>(
      name: 'forbiddenTaskTool',
      description: 'forbidden task tool',
      inputSchema: mapSchema(stringSchema(), dynamicSchema()),
      metadata: {
        'mcp': {
          'execution': {'taskSupport': 'forbidden'},
        },
      },
      fn: (input, _) async => 'ok',
    );

    final payload = toMcpTool(forbiddenTool);
    final execution = payload['execution'] as Map<String, dynamic>;
    expect(execution['taskSupport'], 'forbidden');

    final requiredTool = Tool<Map<String, dynamic>, String>(
      name: 'requiredTaskTool',
      description: 'required task tool',
      inputSchema: mapSchema(stringSchema(), dynamicSchema()),
      metadata: {
        'mcp': {
          'execution': {'taskSupport': 'required'},
        },
      },
      fn: (input, _) async => 'ok',
    );

    final requiredPayload = toMcpTool(requiredTool);
    final requiredExecution =
        requiredPayload['execution'] as Map<String, dynamic>;
    expect(requiredExecution['taskSupport'], 'required');
  });

  test('prompt media requires data URLs', () {
    final message = Message(
      role: Role.user,
      content: [MediaPart(media: Media(url: 'http://example.com/image.png'))],
    );
    expect(
      () => toMcpPromptMessage(message),
      throwsA(
        predicate(
          (e) => e is GenkitException && e.status == StatusCodes.UNIMPLEMENTED,
        ),
      ),
    );
  });

  test('prompt roles reject system messages', () {
    final message = Message(
      role: Role.system,
      content: [TextPart(text: 'system')],
    );
    expect(
      () => toMcpPromptMessage(message),
      throwsA(
        predicate(
          (e) => e is GenkitException && e.status == StatusCodes.UNIMPLEMENTED,
        ),
      ),
    );
  });

  test('media data URLs must include a comma separator', () {
    final message = Message(
      role: Role.user,
      content: [MediaPart(media: Media(url: 'data:image/png;base64'))],
    );
    expect(
      () => toMcpPromptMessage(message),
      throwsA(
        predicate(
          (e) =>
              e is GenkitException && e.status == StatusCodes.INVALID_ARGUMENT,
        ),
      ),
    );
  });

  test('resource content rejects unsupported parts', () {
    final part = DataPart(data: {'foo': 'bar'});
    expect(
      () => toMcpResourceContent('my://resource', part),
      throwsA(
        predicate(
          (e) => e is GenkitException && e.status == StatusCodes.UNIMPLEMENTED,
        ),
      ),
    );
  });

  test('resource content converts text and media parts', () {
    final textPart = TextPart(text: 'hello');
    expect(toMcpResourceContent('my://resource', textPart), {
      'uri': 'my://resource',
      'text': 'hello',
    });

    final media = Media(
      url: 'data:image/png;base64,QUJD',
      contentType: 'image/png',
    );
    final mediaPart = MediaPart(media: media);
    expect(toMcpResourceContent('my://resource', mediaPart), {
      'uri': 'my://resource',
      'mimeType': 'image/png',
      'blob': 'QUJD',
    });
  });

  test('resource definitions require uri or template (not both)', () {
    final ai = Genkit();
    expect(
      () => ai.defineResource(
        name: 'invalidResource',
        fn: (_, _) async => ResourceOutput(content: []),
      ),
      throwsA(
        predicate(
          (e) =>
              e is GenkitException && e.status == StatusCodes.INVALID_ARGUMENT,
        ),
      ),
    );
    expect(
      () => ai.defineResource(
        name: 'invalidResource',
        uri: 'my://resource',
        template: 'file://{id}',
        fn: (_, _) async => ResourceOutput(content: []),
      ),
      throwsA(
        predicate(
          (e) =>
              e is GenkitException && e.status == StatusCodes.INVALID_ARGUMENT,
        ),
      ),
    );
  });

  test('resource matcher supports exact uri and simple templates', () {
    final ai = Genkit();
    final exact = ai.defineResource(
      name: 'exactResource',
      uri: 'my://resource',
      fn: (_, _) async => ResourceOutput(content: []),
    );
    expect(exact.matches(ResourceInput(uri: 'my://resource')), isTrue);
    expect(exact.matches(ResourceInput(uri: 'my://other')), isFalse);

    final templated = ai.defineResource(
      name: 'templatedResource',
      template: 'file://{path}',
      fn: (_, _) async => ResourceOutput(content: []),
    );
    expect(templated.matches(ResourceInput(uri: 'file://foo')), isTrue);
    expect(templated.matches(ResourceInput(uri: 'file://')), isFalse);
  });

  test('resource templates reject unsupported operators', () {
    final ai = Genkit();
    expect(
      () => ai.defineResource(
        name: 'badTemplate',
        template: 'file://{+path}',
        fn: (_, _) async => ResourceOutput(content: []),
      ),
      throwsA(
        predicate(
          (e) => e is GenkitException && e.status == StatusCodes.UNIMPLEMENTED,
        ),
      ),
    );
  });
}
