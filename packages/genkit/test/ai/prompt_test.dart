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

import 'dart:convert';
import 'dart:io';

import 'package:dotprompt/dotprompt.dart' as dp;
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/dotprompt_registry.dart';
import 'package:genkit/src/ai/formatters/formatters.dart';
import 'package:genkit/src/ai/prompt.dart';
import 'package:genkit/src/ai/prompt_loader.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';
import 'package:test/test.dart';

/// Structured output fixture for the typed-prompt tests. Hand-rolled rather
/// than generated so this file stays free of a build_runner part.
class _Joke {
  _Joke({required this.setup, required this.punchline});

  factory _Joke.fromJson(Map<String, dynamic> json) => _Joke(
    setup: json['setup'] as String,
    punchline: json['punchline'] as String,
  );

  final String setup;
  final String punchline;

  Map<String, dynamic> toJson() => {'setup': setup, 'punchline': punchline};
}

/// Stands in for a generated `_Joke.$schema`.
final _jokeSchema = SchemanticType.from<_Joke>(
  jsonSchema: {
    'type': 'object',
    'properties': {
      'setup': {'type': 'string'},
      'punchline': {'type': 'string'},
    },
    'required': ['setup', 'punchline'],
  },
  parse: (json) => _Joke.fromJson(json as Map<String, dynamic>),
);

void main() {
  group('PromptConfig', () {
    test('creates with required name', () {
      final config = PromptConfig(name: 'test');
      expect(config.name, equals('test'));
      expect(config.variant, isNull);
      expect(config.fullName, equals('test'));
    });

    test('fullName includes variant', () {
      final config = PromptConfig(name: 'test', variant: 'v2');
      expect(config.fullName, equals('test.v2'));
    });

    test('stores all config fields', () {
      final config = PromptConfig(
        name: 'test',
        variant: 'formal',
        model: modelRef('test-model'),
        config: {'temperature': 0.7},
        description: 'A test prompt',
        system: 'You are helpful',
        prompt: 'Say {{greeting}}',
        maxTurns: 5,
        returnToolRequests: true,
        toolNames: ['tool1'],
        toolChoice: .auto,
      );

      expect(config.name, equals('test'));
      expect(config.variant, equals('formal'));
      expect(config.model!.name, equals('test-model'));
      expect(config.config, equals({'temperature': 0.7}));
      expect(config.description, equals('A test prompt'));
      expect(config.system, equals('You are helpful'));
      expect(config.prompt, equals('Say {{greeting}}'));
      expect(config.maxTurns, equals(5));
      expect(config.returnToolRequests, isTrue);
      expect(config.toolNames, equals(['tool1']));
      expect(config.toolChoice, equals('auto'));
    });

    test('resolvedOutput is computed once', () {
      final config = PromptConfig(name: 'joke', outputSchema: _jokeSchema);

      // Read on every render; rebuilding the JSON schema each time is waste.
      expect(identical(config.resolvedOutput, config.resolvedOutput), isTrue);
      expect(config.resolvedOutput?.jsonSchema, isNotNull);
    });
  });

  group('PromptGenerateOptions', () {
    test('creates with all optional fields', () {
      final opts = PromptGenerateOptions(
        model: modelRef('override-model'),
        config: {'temperature': 0.5},
        toolChoice: .required,
        returnToolRequests: false,
        maxTurns: 3,
        context: {'user': 'test'},
      );

      expect(opts.model!.name, equals('override-model'));
      expect(opts.config, equals({'temperature': 0.5}));
      expect(opts.toolChoice, equals('required'));
      expect(opts.returnToolRequests, isFalse);
      expect(opts.maxTurns, equals(3));
      expect(opts.context, equals({'user': 'test'}));
    });

    test('creates with no fields', () {
      final opts = PromptGenerateOptions();
      expect(opts.model, isNull);
      expect(opts.config, isNull);
      expect(opts.tools, isNull);
    });
  });

  group('definePromptAction', () {
    late Registry registry;
    late DotpromptRegistry dpRegistry;

    setUp(() {
      registry = Registry();
      dpRegistry = DotpromptRegistry();
    });

    test('returns a Prompt', () {
      final config = PromptConfig(name: 'greet', prompt: 'Hello {{name}}');

      final ep = definePromptAction(registry, dpRegistry, config);

      expect(ep, isA<Prompt>());
      expect(ep.ref.name, equals('greet'));
      expect(ep.ref.metadata['type'], equals('prompt'));
      expect(
        () => ep.ref.metadata['type'] = 'other',
        throwsUnsupportedError,
        reason: 'ref metadata is read-only',
      );
    });

    test('ref metadata is read-only all the way down', () {
      final toolNames = ['lookup'];
      final config = PromptConfig(
        name: 'greet',
        prompt: 'Hello {{name}}',
        toolNames: toolNames,
      );

      final ep = definePromptAction(registry, dpRegistry, config);

      // Nested maps stay String-keyed so callers can keep casting them.
      final prompt = ep.ref.metadata['prompt'];
      expect(prompt, isA<Map<String, dynamic>>());
      prompt as Map<String, dynamic>;
      expect(() => prompt['name'] = 'other', throwsUnsupportedError);
      expect(() => (prompt['tools'] as List).add('x'), throwsUnsupportedError);
      // A copy, not a view: the prompt's own config list is not exposed.
      toolNames.add('later');
      expect(prompt['tools'], equals(['lookup']));
    });

    test('registers a PromptAction in the registry', () async {
      final config = PromptConfig(name: 'greet', prompt: 'Hello {{name}}');

      definePromptAction(registry, dpRegistry, config);

      final action = await registry.lookupAction(.executablePrompt, 'greet');
      expect(action, isNotNull);
      expect(action, isA<PromptAction>());
    });

    test('registers with variant in name', () async {
      final config = PromptConfig(
        name: 'greet',
        variant: 'formal',
        prompt: 'Good day, {{name}}',
      );

      final ep = definePromptAction(registry, dpRegistry, config);

      expect(ep.ref.name, equals('greet.formal'));

      final action = await registry.lookupAction(
        .executablePrompt,
        'greet.formal',
      );
      expect(action, isNotNull);
    });

    test('includes metadata in registration', () async {
      final config = PromptConfig(
        name: 'greet',
        model: modelRef('test-model'),
        prompt: 'Hello {{name}}',
        toolNames: ['tool1'],
        toolChoice: .auto,
      );

      definePromptAction(registry, dpRegistry, config);

      final action = await registry.lookupAction(.executablePrompt, 'greet');
      expect(action, isNotNull);
      final pa = action as PromptAction;
      expect(pa.metadata['type'], equals('prompt'));
      final promptMeta = pa.metadata['prompt'] as Map<String, dynamic>;
      expect(promptMeta['model'], equals('test-model'));
      expect(promptMeta['tools'], equals(['tool1']));
      expect(promptMeta['toolChoice'], equals('auto'));
    });
  });

  group('Prompt.render', () {
    late Registry registry;
    late DotpromptRegistry dpRegistry;

    setUp(() {
      registry = Registry();
      dpRegistry = DotpromptRegistry();
    });

    test('renders a simple string template', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello {{name}}'),
      );

      final options = await ep.render({'name': 'World'});

      // JS: messages: [{ content: [{ text: 'hello foo' }], role: 'user' }]
      expect(options.messages.length, equals(1));
      expect(options.messages[0].role, equals(Role.user));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('Hello World'),
      );
    });

    test('renders system template', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          system: 'You are a {{kind}} assistant',
          prompt: 'Help me',
        ),
      );

      final options = await ep.render({'kind': 'helpful'});

      // JS: messages: [system, user] — 2 messages
      expect(options.messages.length, equals(2));
      expect(options.messages[0].role, equals(Role.system));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('You are a helpful assistant'),
      );
      expect(options.messages[1].role, equals(Role.user));
      expect(
        options.messages[1].content[0].toJson()['text'],
        equals('Help me'),
      );
    });

    test('renders with literal Part system', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          systemParts: [TextPart(text: 'Be helpful')],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.messages.first.role, equals(Role.system));
      final sysText = options.messages.first.content[0].toJson()['text'];
      expect(sysText, equals('Be helpful'));
    });

    test('renders with literal messages', () async {
      final history = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'Previous question')],
        ),
        Message(
          role: Role.model,
          content: [TextPart(text: 'Previous answer')],
        ),
      ];

      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', messages: history, prompt: 'New question'),
      );

      final options = await ep.render({});

      // Should have history + new prompt
      expect(options.messages.length, equals(3));
      expect(options.messages[0].role, equals(Role.user));
      expect(options.messages[1].role, equals(Role.model));
      expect(options.messages[2].role, equals(Role.user));
    });

    test('resolves model from config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          model: modelRef('my-model'),
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.model, equals('my-model'));
    });

    test('opts model overrides config model', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          model: modelRef('default-model'),
          prompt: 'Hello',
        ),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(model: modelRef('override-model')),
      );

      expect(options.model, equals('override-model'));
    });

    test('merges config from both config and opts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          config: {'temperature': 0.7, 'topK': 40},
          prompt: 'Hello',
        ),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(config: {'temperature': 0.5, 'topP': 0.9}),
      );

      // opts should override config's temperature
      expect(options.config!['temperature'], equals(0.5));
      expect(options.config!['topK'], equals(40));
      expect(options.config!['topP'], equals(0.9));
    });

    test('resolves tool names from config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          toolNames: ['tool1', 'tool2'],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.tools, equals(['tool1', 'tool2']));
    });

    test('resolves toolChoice from config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', toolChoice: .required, prompt: 'Hello'),
      );

      final options = await ep.render({});

      expect(options.toolChoice, ToolChoice.required);
    });

    test('opts toolChoice overrides config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', toolChoice: .auto, prompt: 'Hello'),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(toolChoice: .required),
      );

      expect(options.toolChoice, ToolChoice.required);
    });

    test('resolves maxTurns from config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', maxTurns: 10, prompt: 'Hello'),
      );

      final options = await ep.render({});

      expect(options.maxTurns, equals(10));
    });

    test('resolves middleware use from config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          use: [middlewareRef(name: 'mw1')],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.use, isNotNull);
      expect(options.use!.length, equals(1));
      expect(options.use![0].name, equals('mw1'));
    });

    test('resolves middleware use from opts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello'),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(use: [middlewareRef(name: 'mw2')]),
      );

      expect(options.use, isNotNull);
      expect(options.use!.length, equals(1));
      expect(options.use![0].name, equals('mw2'));
    });

    test('merges middleware use from config and opts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          use: [middlewareRef(name: 'configMw')],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(use: [middlewareRef(name: 'optsMw')]),
      );

      // Config middleware should come first, then opts middleware.
      expect(options.use, isNotNull);
      expect(
        options.use!.map((m) => m.name).toList(),
        equals(['configMw', 'optsMw']),
      );
    });

    test('carries middleware config through render', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          use: [
            middlewareRef<Map<String, dynamic>>(
              name: 'mw1',
              config: {'foo': 'bar'},
            ),
          ],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.use, isNotNull);
      expect(options.use![0].name, equals('mw1'));
      expect(options.use![0].config, equals({'foo': 'bar'}));
    });

    test('use is null when no middleware provided', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello'),
      );

      final options = await ep.render({});

      expect(options.use, isNull);
    });

    test('middleware config with non-String map keys is handled', () async {
      // A middleware config given as a Map<dynamic, dynamic> (not exactly
      // Map<String, dynamic>) must not throw during render.
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          use: [
            middlewareRef<Map<dynamic, dynamic>>(
              name: 'mw1',
              config: <dynamic, dynamic>{'foo': 'bar'},
            ),
          ],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.use, isNotNull);
      expect(options.use![0].name, equals('mw1'));
      expect(options.use![0].config, equals({'foo': 'bar'}));
    });

    test('adds history from opts when no messages config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'New question'),
      );

      final history = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'Old question')],
        ),
        Message(
          role: Role.model,
          content: [TextPart(text: 'Old answer')],
        ),
      ];

      final options = await ep.render(
        {},
        PromptGenerateOptions(messages: history),
      );

      // JS: messages: [history user, history model, prompt user]
      expect(options.messages.length, equals(3));
      expect(options.messages[0].role, equals(Role.user));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('Old question'),
      );
      expect(options.messages[1].role, equals(Role.model));
      expect(
        options.messages[1].content[0].toJson()['text'],
        equals('Old answer'),
      );
      expect(options.messages[2].role, equals(Role.user));
      expect(
        options.messages[2].content[0].toJson()['text'],
        equals('New question'),
      );
    });

    test('renders with literal promptParts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          promptParts: [TextPart(text: 'Literal user prompt')],
        ),
      );

      final options = await ep.render({});

      expect(options.messages, isNotEmpty);
      final lastMsg = options.messages.last;
      expect(lastMsg.role, equals(Role.user));
      final text = lastMsg.content[0].toJson()['text'];
      expect(text, equals('Literal user prompt'));
    });

    test('renders with systemParts and promptParts (no templates)', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          systemParts: [TextPart(text: 'System instruction')],
          promptParts: [TextPart(text: 'User question')],
        ),
      );

      final options = await ep.render({});

      expect(options.messages.length, equals(2));
      expect(options.messages[0].role, equals(Role.system));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('System instruction'),
      );
      expect(options.messages[1].role, equals(Role.user));
      expect(
        options.messages[1].content[0].toJson()['text'],
        equals('User question'),
      );
    });

    test('renders messagesTemplate with variable substitution', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          messagesTemplate: 'Hello {{name}}, welcome!',
        ),
      );

      final options = await ep.render({'name': 'World'});

      expect(options.messages, isNotEmpty);
      final text = options.messages.last.content[0].toJson()['text'];
      expect(text, contains('Hello World, welcome!'));
    });

    test('messagesTemplate takes priority over messages', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          messagesTemplate: 'Template message',
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'Literal message')],
            ),
          ],
        ),
      );

      final options = await ep.render({});

      // messagesTemplate should be used, not literal messages
      final text = options.messages.last.content[0].toJson()['text'];
      expect(text, contains('Template message'));
    });

    test('messages config takes priority over opts messages', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'Config message')],
            ),
          ],
        ),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'Opts message')],
            ),
          ],
        ),
      );

      // Config messages should be used, not opts messages
      expect(options.messages.length, equals(1));
      final text = options.messages[0].content[0].toJson()['text'];
      expect(text, equals('Config message'));
    });

    test('prompt string takes priority over promptParts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          prompt: 'Template prompt {{name}}',
          promptParts: [TextPart(text: 'Literal prompt')],
        ),
      );

      final options = await ep.render({'name': 'World'});

      final text = options.messages.last.content[0].toJson()['text'];
      expect(text, contains('Template prompt World'));
    });

    test('system string takes priority over systemParts', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          system: 'Template system {{kind}}',
          systemParts: [TextPart(text: 'Literal system')],
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({'kind': 'helpful'});

      final sysText = options.messages.first.content[0].toJson()['text'];
      expect(sysText, contains('Template system helpful'));
    });

    test('renders system + messages + prompt in correct order', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          system: 'system {{name}}',
          messages: [
            Message(
              role: Role.user,
              content: [TextPart(text: 'hi')],
            ),
            Message(
              role: Role.model,
              content: [TextPart(text: 'bye')],
            ),
          ],
          prompt: 'user prompt {{name}}',
        ),
      );

      final options = await ep.render({'name': 'foo'});

      // Order should be: system, messages history, user prompt
      expect(options.messages.length, equals(4));
      expect(options.messages[0].role, equals(Role.system));
      expect(
        options.messages[0].content[0].toJson()['text'],
        contains('system foo'),
      );
      expect(options.messages[1].role, equals(Role.user));
      expect(options.messages[1].content[0].toJson()['text'], equals('hi'));
      expect(options.messages[2].role, equals(Role.model));
      expect(options.messages[2].content[0].toJson()['text'], equals('bye'));
      expect(options.messages[3].role, equals(Role.user));
      expect(
        options.messages[3].content[0].toJson()['text'],
        contains('user prompt foo'),
      );
    });

    test('renders multi-role messagesTemplate with {{role}} helper', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          messagesTemplate:
              '{{role "system"}}\nsystem {{name}}\n{{role "user"}}\nuser {{name}}',
        ),
      );

      final options = await ep.render({'name': 'foo'});

      expect(options.messages.length, equals(2));
      expect(options.messages[0].role, equals(Role.system));
      expect(
        options.messages[0].content[0].toJson()['text'],
        contains('system foo'),
      );
      expect(options.messages[1].role, equals(Role.user));
      expect(
        options.messages[1].content[0].toJson()['text'],
        contains('user foo'),
      );
    });

    test('messagesTemplate with opts.messages prepends history', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', messagesTemplate: 'hello {{name}}'),
      );

      final history = [
        Message(
          role: Role.user,
          content: [TextPart(text: 'hi')],
        ),
        Message(
          role: Role.model,
          content: [TextPart(text: 'bye')],
        ),
      ];

      final options = await ep.render({
        'name': 'World',
      }, PromptGenerateOptions(messages: history));

      // JS: messages: [template, history user, history model] — 3 messages
      // History is inserted after the template content
      expect(options.messages.length, equals(3));
      // Verify all messages are present with correct content
      final texts = options.messages
          .map((m) => m.content[0].toJson()['text'] as String)
          .toList();
      expect(texts.any((t) => t.contains('hello World')), isTrue);
      expect(texts.any((t) => t.contains('hi')), isTrue);
      expect(texts.any((t) => t.contains('bye')), isTrue);
      // History messages should have purpose metadata
      final historyMsgs = options.messages
          .where(
            (m) => (m.toJson()['metadata'] as Map?)?['purpose'] == 'history',
          )
          .toList();
      expect(historyMsgs.length, equals(2));
    });

    test(
      'messagesTemplate with {{history}} controls history placement',
      () async {
        final ep = definePromptAction(
          registry,
          dpRegistry,
          PromptConfig(
            name: 'test',
            messagesTemplate: 'hello {{name}}\n{{history}}',
          ),
        );

        final history = [
          Message(
            role: Role.user,
            content: [TextPart(text: 'prev Q')],
          ),
          Message(
            role: Role.model,
            content: [TextPart(text: 'prev A')],
          ),
        ];

        final options = await ep.render({
          'name': 'World',
        }, PromptGenerateOptions(messages: history));

        // JS: messages: [template user, history user (purpose:history),
        //                history model (purpose:history)]
        expect(options.messages.length, equals(3));
        // First message should be from the template
        expect(options.messages[0].role, equals(Role.user));
        expect(
          options.messages[0].content[0].toJson()['text'],
          contains('hello World'),
        );
        // History messages should have purpose metadata
        final historyMsgs = options.messages
            .where(
              (m) => (m.toJson()['metadata'] as Map?)?['purpose'] == 'history',
            )
            .toList();
        expect(historyMsgs.length, equals(2));
        expect(historyMsgs[0].content[0].toJson()['text'], equals('prev Q'));
        expect(historyMsgs[1].content[0].toJson()['text'], equals('prev A'));
      },
    );

    test('preserves output config through render', () async {
      final outputConfig = GenerateActionOutputConfig.fromJson({
        'format': 'json',
        'jsonSchema': {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        },
      });

      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          prompt: 'Generate a name',
          output: outputConfig,
        ),
      );

      final options = await ep.render({});

      expect(options.output, isNotNull);
      expect(options.output!.toJson()['format'], equals('json'));
    });

    test('renders with null input', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello static prompt'),
      );

      final options = await ep.render(null);

      expect(options.messages, isNotEmpty);
      final text = options.messages.last.content[0].toJson()['text'];
      expect(text, contains('Hello static prompt'));
    });
  });

  group('lookupPrompt', () {
    late Registry registry;
    late DotpromptRegistry dpRegistry;

    setUp(() {
      registry = Registry();
      dpRegistry = DotpromptRegistry();
    });

    test('finds a registered prompt by name', () async {
      definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'greet', prompt: 'Hello {{name}}'),
      );

      final ep = await lookupPrompt(registry, 'greet');
      expect(ep, isA<Prompt>());
      expect(ep.ref.name, equals('greet'));
    });

    test('finds a registered prompt by name and variant', () async {
      definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'greet',
          variant: 'formal',
          prompt: 'Good day {{name}}',
        ),
      );

      final ep = await lookupPrompt(registry, 'greet', variant: 'formal');
      expect(ep, isA<Prompt>());
      expect(ep.ref.name, equals('greet.formal'));
    });

    test('throws when prompt not found', () async {
      expect(
        () => lookupPrompt(registry, 'nonexistent'),
        throwsA(isA<GenkitException>()),
      );
    });
  });

  group('PromptAction', () {
    test('can be invoked with executablePrompt', () async {
      final registry = Registry();
      final dpRegistry = DotpromptRegistry();

      definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello {{name}}'),
      );

      final action = await registry.lookupAction(.executablePrompt, 'test');
      expect(action, isNotNull);

      // Invoke via the action
      final result = await action!({'name': 'World'});
      expect(result, isA<GenerateActionOptions>());
      final opts = result as GenerateActionOptions;
      expect(opts.messages, isNotEmpty);
    });

    test('can be invoked with legacy fn', () async {
      final action = PromptAction<String>(
        name: 'legacy',
        fn: (input, ctx) async {
          return GenerateActionOptions(
            model: 'test-model',
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'Hello $input')],
              ),
            ],
          );
        },
      );

      final result = await action('World');
      expect(result, isA<GenerateActionOptions>());
      final opts = result;
      expect(opts.model, equals('test-model'));
    });
  });

  group('Genkit.definePrompt integration', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, promptDir: null);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('definePrompt returns a Prompt', () {
      final ep = genkit.definePrompt(name: 'hi', prompt: 'Say hi to {{name}}');

      expect(ep, isA<Prompt>());
      expect(ep.ref.name, equals('hi'));
    });

    test('definePrompt with model', () async {
      final ep = genkit.definePrompt(
        name: 'hi',
        model: modelRef('test/model'),
        prompt: 'Say hi to {{name}}',
      );

      final options = await ep.render({'name': 'Sparky'});
      expect(options.model, equals('test/model'));
    });

    test('prompt() looks up defined prompts', () async {
      genkit.definePrompt(name: 'greeting', prompt: 'Hello {{name}}');

      final ep = await genkit.prompt('greeting');
      expect(ep, isA<Prompt>());
    });

    test('prompt() with variant', () async {
      genkit.definePrompt(
        name: 'greeting',
        variant: 'formal',
        prompt: 'Good day, {{name}}',
      );

      final ep = await genkit.prompt('greeting', variant: 'formal');
      expect(ep, isA<Prompt>());
      expect(ep.ref.name, equals('greeting.formal'));
    });

    test('prompt() throws for missing prompt', () {
      expect(
        () => genkit.prompt('nonexistent'),
        throwsA(isA<GenkitException>()),
      );
    });

    test('definePrompt with system and prompt templates', () async {
      final ep = genkit.definePrompt(
        name: 'assistant',
        system: 'You are a {{kind}} assistant',
        prompt: 'Help me with {{task}}',
      );

      final options = await ep.render({'kind': 'coding', 'task': 'Dart'});

      expect(options.messages.length, equals(2));
      expect(options.messages[0].role, equals(Role.system));
      expect(options.messages[1].role, equals(Role.user));
    });

    test('definePrompt with config options', () async {
      final ep = genkit.definePrompt(
        name: 'creative',
        model: modelRef('test/model'),
        config: {'temperature': 0.9},
        maxTurns: 3,
        toolChoice: .auto,
        prompt: 'Write a story',
      );

      final options = await ep.render({});
      expect(options.model, equals('test/model'));
      expect(options.config!['temperature'], equals(0.9));
      expect(options.maxTurns, equals(3));
      expect(options.toolChoice, equals('auto'));
    });

    test('defineCustomPrompt works for programmatic prompt building', () async {
      final pa = genkit.defineCustomPrompt<String>(
        name: 'old-style',
        fn: (input, ctx) async {
          return GenerateActionOptions(
            model: 'test-model',
            messages: [
              Message(
                role: Role.user,
                content: [TextPart(text: 'Hello $input')],
              ),
            ],
          );
        },
      );

      expect(pa, isA<PromptAction<String>>());
      final result = await pa('World');
      expect(result, isA<GenerateActionOptions>());
    });

    test('definePartial registers a partial', () async {
      genkit.definePartial('greeting', 'Hello {{name}}!');

      // Use the partial in a prompt
      final ep = genkit.definePrompt(
        name: 'with-partial',
        prompt: '{{> greeting}}',
      );

      final options = await ep.render({'name': 'World'});
      final text = options.messages.last.content[0].toJson()['text'];
      expect(text, contains('Hello World!'));
    });

    test('multiple prompts can be defined', () async {
      genkit.definePrompt(name: 'p1', prompt: 'Prompt 1');
      genkit.definePrompt(name: 'p2', prompt: 'Prompt 2');
      genkit.definePrompt(name: 'p3', prompt: 'Prompt 3');

      final ep1 = await genkit.prompt('p1');
      final ep2 = await genkit.prompt('p2');
      final ep3 = await genkit.prompt('p3');

      expect(ep1.ref.name, equals('p1'));
      expect(ep2.ref.name, equals('p2'));
      expect(ep3.ref.name, equals('p3'));
    });

    test('defineSchema registers a named schema', () {
      // Should not throw
      genkit.defineSchema('Address', {
        'type': 'object',
        'properties': {
          'street': {'type': 'string'},
          'city': {'type': 'string'},
        },
        'required': ['street', 'city'],
      });

      // Schema should be stored in the registry
      final schema = genkit.registry.lookupValue<Map<String, dynamic>>(
        'schema',
        'Address',
      );
      expect(schema, isNotNull);
      expect(schema!['type'], equals('object'));
      expect(schema['properties'], contains('street'));
    });

    test(
      'defineSchema makes schema available for picoschema in prompts',
      () async {
        genkit.defineSchema('Person', {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'age': {'type': 'integer'},
          },
          'required': ['name', 'age'],
        });

        // Define a prompt with picoschema output that references named schema
        final ep = genkit.definePrompt(
          name: 'person-prompt',
          prompt: 'Generate a person',
          output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        );

        // Verify the prompt was created successfully
        expect(ep, isA<Prompt>());
        final options = await ep.render({});
        expect(options.messages, isNotEmpty);
      },
    );

    test('defineSchema allows multiple schemas', () {
      genkit.defineSchema('Schema1', {
        'type': 'object',
        'properties': {
          'a': {'type': 'string'},
        },
      });
      genkit.defineSchema('Schema2', {
        'type': 'object',
        'properties': {
          'b': {'type': 'integer'},
        },
      });

      final s1 = genkit.registry.lookupValue<Map<String, dynamic>>(
        'schema',
        'Schema1',
      );
      final s2 = genkit.registry.lookupValue<Map<String, dynamic>>(
        'schema',
        'Schema2',
      );

      expect(s1, isNotNull);
      expect(s2, isNotNull);
      expect(s1!['properties'], contains('a'));
      expect(s2!['properties'], contains('b'));
    });
  });

  group('typed prompt output', () {
    late Genkit genkit;

    /// A model that replies with [text], optionally streaming [chunks] first.
    void defineEchoModel(String name, String text, {List<String>? chunks}) {
      genkit.defineModel(
        name: name,
        fn: (request, context) async {
          for (final chunk in chunks ?? const <String>[]) {
            context.sendChunk(
              ModelResponseChunk(content: [TextPart(text: chunk)]),
            );
          }
          return ModelResponse(
            finishReason: .stop,
            message: Message(
              role: .model,
              content: [TextPart(text: text)],
            ),
          );
        },
      );
    }

    /// Defines a prompt with [O] pinned as its Output but no outputSchema to
    /// infer it from: the case the schemaless-Output tests exercise. The
    /// return type supplies the inference context for `definePrompt`.
    Prompt<dynamic, O> defineSchemaless<O>(
      String name, {
      ModelRef<dynamic>? model,
      GenerateActionOutputConfig? output,
    }) => genkit.definePrompt(
      name: name,
      model: model,
      output: output,
      prompt: 'Tell a joke',
    );

    setUp(() {
      genkit = Genkit(isDevEnv: false, promptDir: null);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('definePrompt infers Output from outputSchema', () {
      final ep = genkit.definePrompt(
        name: 'joke',
        inputSchema: SchemanticType.map(.string(), .string()),
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      expect(ep, isA<Prompt<Map<String, String>, _Joke>>());
    });

    test('definePrompt without outputSchema leaves Output dynamic', () {
      final ep = genkit.definePrompt(name: 'plain', prompt: 'Say hi');

      expect(ep, isA<Prompt<dynamic, dynamic>>());
      expect(ep, isNot(isA<Prompt<dynamic, _Joke>>()));
    });

    test('outputSchema reaches the rendered request as a jsonSchema', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final options = await ep.render(null);
      expect(options.output, isNotNull);
      expect(
        (options.output!.jsonSchema!['properties'] as Map).keys,
        containsAll(['setup', 'punchline']),
      );
    });

    test('outputSchema merges with the raw output config', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      final options = await ep.render(null);
      expect(options.output!.toJson()['format'], equals('json'));
      expect(options.output!.jsonSchema, isNotNull);
    });

    test('a jsonSchema on both outputSchema and output is rejected', () {
      expect(
        () => genkit.definePrompt(
          name: 'joke',
          outputSchema: _jokeSchema,
          output: GenerateActionOutputConfig.fromJson({
            'jsonSchema': {'type': 'object'},
          }),
          prompt: 'Tell a joke',
        ),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('a domain Output with no outputSchema is rejected', () {
      // Without a schema the raw JSON would be cast straight to _Joke and blow
      // up with a bare TypeError on the first call, so this fails at
      // definition instead.
      expect(
        () => defineSchemaless<_Joke>('joke'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('no outputSchema to parse it'),
          ),
        ),
      );
    });

    test('JSON-shaped Outputs need no outputSchema', () {
      // These are what a decoder already produces, so the cast is safe and
      // requiring a schema would be a false positive. They still need JSON
      // requested, hence the format.
      final json = GenerateActionOutputConfig.fromJson({'format': 'json'});
      // Each would throw at definition if rejected.
      defineSchemaless<Map<String, dynamic>>('map', output: json);
      defineSchemaless<String>('str', output: json);
      defineSchemaless<List<dynamic>>('list', output: json);
      defineSchemaless<int>('int', output: json);
      defineSchemaless<double>('double', output: json);
      defineSchemaless<num>('num', output: json);
      defineSchemaless<bool>('bool', output: json);
    });

    test('a JSON-shaped Output on a text-only prompt is rejected', () {
      // No format and no schema means no formatter runs, so `output` would be
      // null on every call.
      expect(
        () => defineSchemaless<Map<String, dynamic>>('map'),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('does not request structured output'),
          ),
        ),
      );
    });

    test('a wrong-shaped reply for a scalar Output is a GenkitException', () {
      defineEchoModel('m', '{"a": 1}');
      final ep = defineSchemaless<String>(
        'p',
        model: modelRef('m'),
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
      );

      expect(
        ep(null),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('does not match the expected output type String'),
          ),
        ),
      );
    });

    test('call() parses the response into Output', () async {
      defineEchoModel('m', '{"setup": "Why?", "punchline": "Because."}');
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final response = await ep(null);

      // Statically a `_Joke?`, so no cast is needed to reach the fields.
      expect(response.output?.setup, equals('Why?'));
      expect(response.output?.punchline, equals('Because.'));
    });

    test('an untyped prompt still yields the raw JSON output', () async {
      defineEchoModel('m', '{"setup": "Why?"}');
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      final response = await ep(null);
      // Output is `dynamic` here, so the raw decoded JSON passes through.
      expect(response.output, isA<Map<String, dynamic>>());
      expect((response.output as Map)['setup'], equals('Why?'));
    });

    test('stream() parses both chunks and the final response', () async {
      defineEchoModel(
        'm',
        '{"setup": "Why?", "punchline": "Because."}',
        // Split mid-value so the first chunk is unparseable partial JSON.
        chunks: ['{"setup": "Wh', 'y?", "punchline": "Because."}'],
      );
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final stream = ep.stream(null);
      final chunkOutputs = <_Joke?>[];
      await for (final chunk in stream) {
        chunkOutputs.add(chunk.output);
      }
      final response = await stream.onResult;

      expect(response.output?.punchline, equals('Because.'));
      // A partial chunk that cannot satisfy the schema yields null rather
      // than failing the generation.
      expect(chunkOutputs.first, isNull);
      expect(chunkOutputs.last?.punchline, equals('Because.'));
    });

    test('a per-call output keeps the prompt format and schema', () async {
      final requests = <ModelRequest>[];
      genkit.defineModel(
        name: 'm',
        fn: (request, context) async {
          requests.add(request);
          return ModelResponse(
            finishReason: .stop,
            message: Message(
              role: .model,
              content: [
                TextPart(text: '{"setup": "Why?", "punchline": "Because."}'),
              ],
            ),
          );
        },
      );
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        outputSchema: _jokeSchema,
        output: GenerateActionOutputConfig(format: 'json'),
        prompt: 'Tell a joke',
      );

      final response = await ep(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(constrained: false),
        ),
      );

      // The override only set `constrained`; the prompt's output contract
      // (format + schema) carries over, so the reply still parses into a Joke.
      final output = requests.single.output!;
      expect(output.format, equals('json'));
      expect(output.constrained, isFalse);
      expect(
        (output.schema!['properties'] as Map).keys,
        containsAll(['setup', 'punchline']),
      );
      expect(response.output?.punchline, equals('Because.'));
    });

    test('per-call output fields win over the prompt config', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        output: GenerateActionOutputConfig(format: 'json', constrained: true),
        prompt: 'Tell a joke',
      );

      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(constrained: false),
        ),
      );

      expect(options.output?.constrained, isFalse);
      expect(options.output?.format, equals('json'));
      expect(options.output?.jsonSchema, isNotNull);
    });

    test('a per-call output replaces non-contract fields wholesale', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        output: GenerateActionOutputConfig(
          format: 'json',
          constrained: true,
          instructions: .string('Be brief'),
        ),
        prompt: 'Tell a joke',
      );

      // Matches JS: the override is not merged field by field, so the prompt's
      // `constrained` and `instructions` are dropped. Only the contract
      // (format + schema) carries over.
      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(contentType: 'application/json'),
        ),
      );

      final output = options.output!.toJson();
      expect(output['contentType'], equals('application/json'));
      expect(output, isNot(contains('constrained')));
      expect(output, isNot(contains('instructions')));
      expect(output['format'], equals('json'));
      expect(options.output!.jsonSchema, isNotNull);
    });

    test('a per-call non-JSON format drops the schema', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(format: 'text'),
        ),
      );

      expect(options.output?.format, equals('text'));
      expect(options.output?.jsonSchema, isNull);
    });

    test('a per-call format: json keeps the schema', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(format: 'json'),
        ),
      );

      expect(options.output?.format, equals('json'));
      expect(options.output?.jsonSchema, isNotNull);
    });

    test('a per-call jsonSchema wins over the prompt schema', () async {
      final ep = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );
      final override = {
        'type': 'object',
        'properties': {
          'setup': {'type': 'string'},
          'punchline': {'type': 'string'},
          'rating': {'type': 'integer'},
        },
      };

      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(jsonSchema: override),
        ),
      );

      expect(options.output?.jsonSchema, equals(override));
    });

    test('a per-call output on a prompt without output config', () async {
      final ep = genkit.definePrompt(name: 'plain', prompt: 'Say hi');

      final options = await ep.render(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(format: 'json'),
        ),
      );

      expect(options.output?.toJson(), equals({'format': 'json'}));
    });

    /// Registers a `text` formatter (Dart ships only `json`), so the per-call
    /// format tests prove the guard does not rely on the parser being absent.
    void defineTextFormat() => defineFormat(
      genkit.registry,
      Formatter(
        name: 'text',
        config: GenerateActionOutputConfig(format: 'text'),
        handler: (schema) => FormatterHandlerResult(
          parseMessage: (message) => message.text,
          parseChunk: (chunk) => chunk.accumulatedText,
        ),
      ),
    );

    test(
      'a per-call format: text yields null output on a typed prompt',
      () async {
        // The text reply must not reach the Joke parser (which would throw).
        defineTextFormat();
        final requests = <ModelRequest>[];
        genkit.defineModel(
          name: 'm',
          fn: (request, context) async {
            requests.add(request);
            return ModelResponse(
              finishReason: .stop,
              message: Message(
                role: .model,
                content: [TextPart(text: 'Why? Because.')],
              ),
            );
          },
        );
        final ep = genkit.definePrompt(
          name: 'joke',
          model: modelRef('m'),
          outputSchema: _jokeSchema,
          prompt: 'Tell a joke',
        );

        final response = await ep(
          null,
          PromptGenerateOptions(
            output: GenerateActionOutputConfig(format: 'text'),
          ),
        );

        expect(requests.single.output?.schema, isNull);
        expect(response.output, isNull);
        expect(response.text, equals('Why? Because.'));
      },
    );

    test(
      'a per-call format switch passes the raw value when untyped',
      () async {
        defineTextFormat();
        defineEchoModel('m', 'Why? Because.');
        genkit.definePrompt(
          name: 'joke',
          model: modelRef('m'),
          outputSchema: _jokeSchema,
          prompt: 'Tell a joke',
        );

        // Untyped lookup: Output is dynamic, so whatever the formatter produced
        // is passed through rather than dropped.
        final ep = await genkit.prompt('joke');
        final response = await ep(
          null,
          PromptGenerateOptions(
            output: GenerateActionOutputConfig(format: 'text'),
          ),
        );

        expect(response.output, equals('Why? Because.'));
      },
    );

    test('streamed chunks of a per-call format switch are null too', () async {
      defineTextFormat();
      defineEchoModel('m', 'Why? Because.', chunks: ['Why? ', 'Because.']);
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final stream = ep.stream(
        null,
        PromptGenerateOptions(
          output: GenerateActionOutputConfig(format: 'text'),
        ),
      );
      final chunkOutputs = [await for (final c in stream) c.output];

      expect(chunkOutputs, hasLength(2));
      expect(chunkOutputs, everyElement(isNull));
      expect((await stream.onResult).output, isNull);
    });

    test('a whole-number reply parses into a double Output', () async {
      // `jsonDecode('3')` is an int on the VM; a double Output must accept it.
      defineEchoModel('m', '3', chunks: ['3']);
      final ep = defineSchemaless<double>(
        'score',
        model: modelRef('m'),
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
      );

      final stream = ep.stream(null);
      final chunkOutputs = [await for (final c in stream) c.output];
      final response = await stream.onResult;

      expect(response.output, isA<double>());
      expect(response.output, equals(3.0));
      expect(chunkOutputs.single, isA<double>());
    });

    test('an aborted response survives a typed prompt', () async {
      genkit.defineModel(
        name: 'slow',
        fn: (request, context) async {
          await Future<void>.delayed(const Duration(seconds: 30));
          return ModelResponse(finishReason: .stop);
        },
      );
      final ep = genkit.definePrompt(
        name: 'joke',
        model: modelRef('slow'),
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final controller = CancellationController()..cancel();
      final response = await ep(
        null,
        PromptGenerateOptions(cancel: controller.token),
      );

      // Nothing to parse, but the response itself still comes back.
      expect(response.finishReason, equals(FinishReason.aborted));
      expect(response.output, isNull);
    });
  });

  group('typed prompt lookup', () {
    late Genkit genkit;

    setUp(() {
      genkit = Genkit(isDevEnv: false, promptDir: null);
    });

    tearDown(() async {
      await genkit.shutdown();
    });

    test('reuses the schema the prompt was defined with', () async {
      genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final ep = await genkit.prompt<dynamic, _Joke>('joke');
      expect(ep, isA<Prompt<dynamic, _Joke>>());
    });

    test(
      'rejects a parser schema for a prompt with no output schema',
      () async {
        genkit.definePrompt(name: 'joke', prompt: 'Tell a joke');

        // The parser schema is never sent, so accepting it would mean the model
        // is never asked for JSON and `.output` silently comes back null.
        await expectLater(
          genkit.prompt('joke', outputParserSchema: _jokeSchema),
          throwsA(
            isA<GenkitException>()
                .having((e) => e.status, 'status', StatusCode.invalidArgument)
                .having(
                  (e) => e.message,
                  'message',
                  allOf(
                    contains(
                      'defines no output schema and does not request '
                      'structured output',
                    ),
                    contains('outputParserSchema only parses the response'),
                    contains('look it up untyped'),
                  ),
                ),
          ),
        );
      },
    );

    test('rejects a parser schema for a format-only prompt', () async {
      genkit.definePrompt(
        name: 'joke',
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      // Intended: the model is asked for JSON but never given _Joke's shape,
      // so a domain type cannot be guaranteed. The message points at the
      // JSON-shaped lookup that does work (next test).
      await expectLater(
        genkit.prompt('joke', outputParserSchema: _jokeSchema),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.invalidArgument)
              .having(
                (e) => e.message,
                'message',
                allOf(
                  contains('requests JSON but defines no output schema'),
                  contains('never given the shape of _Joke'),
                  contains('outputParserSchema only parses the response'),
                  contains('prompt<dynamic, Map<String, dynamic>>()'),
                ),
              ),
        ),
      );
    });

    test('a format-only prompt is typeable as a JSON map', () async {
      genkit.defineModel(
        name: 'm',
        fn: (request, context) async => ModelResponse(
          finishReason: .stop,
          message: Message(
            role: .model,
            content: [TextPart(text: '{"setup": "Why?"}')],
          ),
        ),
      );
      genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      final ep = await genkit.prompt<dynamic, Map<String, dynamic>>('joke');
      final response = await ep(null);

      expect(response.output, equals({'setup': 'Why?'}));
    });

    test('a domain Output on a format-only prompt is rejected', () async {
      genkit.definePrompt(
        name: 'joke',
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      await expectLater(
        genkit.prompt<dynamic, _Joke>('joke'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            allOf(
              contains('requests JSON but defines no output schema'),
              contains('prompt<dynamic, Map<String, dynamic>>()'),
              isNot(contains('outputParserSchema')),
            ),
          ),
        ),
      );
    });

    test(
      'accepts a parser schema for a prompt with a raw jsonSchema',
      () async {
        genkit.definePrompt(
          name: 'joke',
          output: GenerateActionOutputConfig.fromJson({
            'jsonSchema': {'type': 'object'},
          }),
          prompt: 'Tell a joke',
        );

        final ep = await genkit.prompt('joke', outputParserSchema: _jokeSchema);
        expect(ep, isA<Prompt<dynamic, _Joke>>());
      },
    );

    test('accepts a redundant parser schema for a typed prompt', () async {
      genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      final ep = await genkit.prompt('joke', outputParserSchema: _jokeSchema);
      expect(ep, isA<Prompt<dynamic, _Joke>>());
    });

    test('the request carries the defined schema, not the parser', () async {
      final requests = <ModelRequest>[];
      genkit.defineModel(
        name: 'm',
        fn: (request, context) async {
          requests.add(request);
          return ModelResponse(
            finishReason: .stop,
            message: Message(
              role: .model,
              content: [
                TextPart(text: '{"setup": "Why?", "punchline": "Because."}'),
              ],
            ),
          );
        },
      );
      final definedSchema = {
        'type': 'object',
        'properties': {
          'setup': {'type': 'string', 'description': 'from the definition'},
          'punchline': {'type': 'string'},
        },
      };
      genkit.definePrompt(
        name: 'joke',
        model: modelRef('m'),
        output: GenerateActionOutputConfig.fromJson({
          'jsonSchema': definedSchema,
        }),
        prompt: 'Tell a joke',
      );

      final ep = await genkit.prompt('joke', outputParserSchema: _jokeSchema);
      final response = await ep(null);

      expect(requests.single.output?.schema, equals(definedSchema));
      expect(response.output?.punchline, equals('Because.'));
    });

    test('fails at lookup when Output has no schema to back it', () async {
      genkit.definePrompt(name: 'joke', prompt: 'Tell a joke');

      await expectLater(
        genkit.prompt<dynamic, _Joke>('joke'),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains(
              'defines no output schema and does not request '
              'structured output',
            ),
          ),
        ),
      );
    });

    test('a JSON-shaped Output needs no schema at lookup', () async {
      genkit.definePrompt(
        name: 'joke',
        output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
        prompt: 'Tell a joke',
      );

      // A raw JSON map already satisfies this, so demanding a schema here
      // would reject the common "just give me the decoded JSON" lookup.
      final ep = await genkit.prompt<dynamic, Map<String, dynamic>>('joke');
      expect(ep, isA<Prompt<dynamic, Map<String, dynamic>>>());
    });

    test('a typed lookup of a text-only prompt is rejected', () async {
      genkit.definePrompt(name: 'joke', prompt: 'Tell a joke');

      // The model is never asked for JSON, so `output` would always be null.
      await expectLater(
        genkit.prompt<dynamic, Map<String, dynamic>>('joke'),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.invalidArgument)
              .having(
                (e) => e.message,
                'message',
                contains('does not request structured output'),
              ),
        ),
      );
    });

    test('an untyped lookup of a text-only prompt still works', () async {
      genkit.definePrompt(name: 'joke', prompt: 'Tell a joke');

      final ep = await genkit.prompt('joke');
      expect(ep.ref.name, equals('joke'));
    });

    test(
      'a domain Output on a schemaless prompt does not suggest the parser',
      () async {
        genkit.definePrompt(name: 'joke', prompt: 'Tell a joke');

        // outputParserSchema would just hit the "does not define an output
        // schema" error, so the hint points at the prompt instead.
        await expectLater(
          genkit.prompt<dynamic, _Joke>('joke'),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              allOf(
                contains('define the schema on the prompt'),
                isNot(contains('outputParserSchema')),
              ),
            ),
          ),
        );
      },
    );

    test(
      'a domain Output on a raw-jsonSchema prompt suggests the parser',
      () async {
        genkit.definePrompt(
          name: 'joke',
          output: GenerateActionOutputConfig.fromJson({
            'jsonSchema': {'type': 'object'},
          }),
          prompt: 'Tell a joke',
        );

        await expectLater(
          genkit.prompt<dynamic, _Joke>('joke'),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              contains('Pass outputParserSchema:'),
            ),
          ),
        );
      },
    );

    test('an untyped lookup of a typed prompt still works', () async {
      genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke',
      );

      // No type arguments: Output is dynamic, so no schema is required.
      final ep = await genkit.prompt('joke');
      expect(ep.ref.name, equals('joke'));
    });

    test('a missing prompt is reported at lookup', () async {
      await expectLater(
        genkit.prompt('nope', outputParserSchema: _jokeSchema),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('not found'),
          ),
        ),
      );
    });

    test('a typed lookup of a .prompt file parses its output', () async {
      final tempDir = Directory.systemTemp.createTempSync('genkit_typed_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      File(p.join(tempDir.path, 'joke.prompt')).writeAsStringSync('''
---
model: m
output:
  schema:
    setup: string
    punchline: string
---
Tell a joke.
''');
      final ai = Genkit(isDevEnv: false, promptDir: tempDir.path);
      addTearDown(ai.shutdown);
      ai.defineModel(
        name: 'm',
        fn: (request, context) async => ModelResponse(
          finishReason: .stop,
          message: Message(
            role: .model,
            content: [
              TextPart(text: '{"setup": "Why?", "punchline": "Because."}'),
            ],
          ),
        ),
      );

      // The file supplies the wire schema; the Dart parser comes from here,
      // and Output is inferred from it.
      final ep = await ai.prompt('joke', outputParserSchema: _jokeSchema);
      expect(ep, isA<Prompt<dynamic, _Joke>>());
      final response = await ep(null);

      expect(response.output?.setup, equals('Why?'));
    });

    test(
      'any parser needs a wire schema, even for a JSON-shaped Output',
      () async {
        genkit.definePrompt(
          name: 'joke',
          output: GenerateActionOutputConfig.fromJson({'format': 'json'}),
          prompt: 'Tell a joke',
        );

        // A JSON-shaped Output alone would pass on a format-only prompt (see
        // above), but asking for a parser means asking for a specific shape,
        // which the model must be given.
        await expectLater(
          genkit.prompt(
            'joke',
            outputParserSchema: SchemanticType.map(.string(), .string()),
          ),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              contains('requests JSON but defines no output schema'),
            ),
          ),
        );
      },
    );

    test('a typed lookup shares the defining template cache', () async {
      final defined = genkit.definePrompt(
        name: 'joke',
        outputSchema: _jokeSchema,
        prompt: 'Tell a joke about {{topic}}',
      );
      await defined.render({'topic': 'cats'});

      final ep = await genkit.prompt<dynamic, _Joke>('joke');
      final options = await ep.render({'topic': 'dogs'});

      expect(
        options.messages.last.content[0].toJson()['text'],
        contains('dogs'),
      );
    });
  });

  group('Genkit promptDir integration', () {
    late Directory tempDir;
    late Genkit genkit;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('genkit_promptdir_test_');
    });

    tearDown(() async {
      await genkit.shutdown();
      tempDir.deleteSync(recursive: true);
    });

    test('loads .prompt files from promptDir on construction', () async {
      File(
        p.join(tempDir.path, 'hello.prompt'),
      ).writeAsStringSync('Hello {{name}}!');

      genkit = Genkit(isDevEnv: false, promptDir: tempDir.path);

      final ep = await genkit.prompt('hello');
      expect(ep, isA<Prompt>());

      final options = await ep.render({'name': 'World'});
      expect(options.messages.length, equals(1));
      expect(options.messages[0].role, equals(Role.user));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('Hello World!'),
      );
    });

    test('loads prompt with frontmatter from promptDir', () async {
      File(p.join(tempDir.path, 'greeting.prompt')).writeAsStringSync('''
---
model: test-model
config:
  temperature: 0.7
---
Hello {{name}}!
''');

      genkit = Genkit(isDevEnv: false, promptDir: tempDir.path);

      final ep = await genkit.prompt('greeting');
      expect(ep, isA<Prompt>());

      final options = await ep.render({'name': 'Dart'});
      expect(options.model, equals('test-model'));
      expect(options.config!['temperature'], equals(0.7));
      expect(
        options.messages[0].content[0].toJson()['text'],
        equals('Hello Dart!'),
      );
    });

    test(
      'a call with its own output schema ignores an undefined name',
      () async {
        // The file's `Recipe` is never defined, but this call does not use it,
        // neither for the request nor for parsing the reply.
        File(p.join(tempDir.path, 'recipe.prompt')).writeAsStringSync('''
---
model: m
output:
  schema: Recipe
  format: json
---
Generate a recipe.
''');
        genkit = Genkit(isDevEnv: false, promptDir: tempDir.path);
        final requests = <ModelRequest>[];
        genkit.defineModel(
          name: 'm',
          fn: (request, context) async {
            requests.add(request);
            return ModelResponse(
              finishReason: .stop,
              message: Message(
                role: .model,
                content: [TextPart(text: '{"name": "pasta"}')],
              ),
            );
          },
        );
        final own = {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
          },
        };

        final ep = await genkit.prompt('recipe');
        final response = await ep(
          null,
          PromptGenerateOptions(
            output: GenerateActionOutputConfig(jsonSchema: own),
          ),
        );

        expect(requests.single.output?.schema, own);
        expect(response.output, {'name': 'pasta'});
      },
    );

    test('does not load prompts when promptDir is null', () async {
      genkit = Genkit(isDevEnv: false, promptDir: null);

      expect(() => genkit.prompt('anything'), throwsA(isA<GenkitException>()));
    });
  });

  group('loadPromptFolder', () {
    late Registry registry;
    late DotpromptRegistry dpRegistry;
    late Directory tempDir;

    setUp(() {
      registry = Registry();
      dpRegistry = DotpromptRegistry();
      tempDir = Directory.systemTemp.createTempSync('genkit_prompt_test_');
    });

    tearDown(() {
      tempDir.deleteSync(recursive: true);
    });

    test('loads a simple .prompt file', () async {
      File(
        p.join(tempDir.path, 'hello.prompt'),
      ).writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action = await registry.lookupAction(.executablePrompt, 'hello');
      expect(action, isNotNull);
      expect(action, isA<PromptAction>());
    });

    test('loads prompt with frontmatter', () async {
      File(p.join(tempDir.path, 'greeting.prompt')).writeAsStringSync('''
---
model: test-model
config:
  temperature: 0.7
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action = await registry.lookupAction(.executablePrompt, 'greeting');
      expect(action, isNotNull);
      final pa = action as PromptAction;
      expect(
        (pa.metadata['prompt'] as Map<String, dynamic>)['model'],
        equals('test-model'),
      );
    });

    test('loads variant prompts', () async {
      File(
        p.join(tempDir.path, 'greeting.prompt'),
      ).writeAsStringSync('Hi {{name}}!');
      File(
        p.join(tempDir.path, 'greeting.formal.prompt'),
      ).writeAsStringSync('Good day, {{name}}.');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final defaultAction = await registry.lookupAction(
        .executablePrompt,
        'greeting',
      );
      final formalAction = await registry.lookupAction(
        .executablePrompt,
        'greeting.formal',
      );

      expect(defaultAction, isNotNull);
      expect(formalAction, isNotNull);
    });

    test('registers underscore-prefixed files as partials', () async {
      // Create a partial
      File(
        p.join(tempDir.path, '_header.prompt'),
      ).writeAsStringSync('Welcome, {{name}}!');
      // Create a prompt that uses the partial
      File(
        p.join(tempDir.path, 'page.prompt'),
      ).writeAsStringSync('{{> header}} How can I help?');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      // The partial should not be registered as a prompt action
      final partialAction = await registry.lookupAction(
        .executablePrompt,
        'header',
      );
      expect(partialAction, isNull);

      // But the main prompt should be registered
      final pageAction = await registry.lookupAction(.executablePrompt, 'page');
      expect(pageAction, isNotNull);
    });

    test('loads prompts from subdirectories', () async {
      final subDir = Directory(p.join(tempDir.path, 'sub'));
      subDir.createSync();
      File(
        p.join(subDir.path, 'nested.prompt'),
      ).writeAsStringSync('Nested prompt');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action = await registry.lookupAction(
        .executablePrompt,
        'sub/nested',
      );
      expect(action, isNotNull);
    });

    test('does nothing when directory does not exist', () {
      // Should not throw
      loadPromptFolder(
        registry,
        dpRegistry,
        dir: '/nonexistent/path/that/does/not/exist',
      );
    });

    test('loads with namespace', () async {
      File(
        p.join(tempDir.path, 'hello.prompt'),
      ).writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path, ns: 'myapp');

      final action = await registry.lookupAction(
        .executablePrompt,
        'myapp/hello',
      );
      expect(action, isNotNull);
    });

    test('loads multiple prompts', () async {
      File(p.join(tempDir.path, 'a.prompt')).writeAsStringSync('Prompt A');
      File(p.join(tempDir.path, 'b.prompt')).writeAsStringSync('Prompt B');
      File(p.join(tempDir.path, 'c.prompt')).writeAsStringSync('Prompt C');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      expect(await registry.lookupAction(.executablePrompt, 'a'), isNotNull);
      expect(await registry.lookupAction(.executablePrompt, 'b'), isNotNull);
      expect(await registry.lookupAction(.executablePrompt, 'c'), isNotNull);
    });

    test('ignores non-prompt files', () async {
      File(
        p.join(tempDir.path, 'hello.prompt'),
      ).writeAsStringSync('Hello {{name}}!');
      File(
        p.join(tempDir.path, 'readme.md'),
      ).writeAsStringSync('# Not a prompt');
      File(
        p.join(tempDir.path, 'config.json'),
      ).writeAsStringSync('{"key": "value"}');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      // Only the .prompt file should be loaded
      final action = await registry.lookupAction(.executablePrompt, 'hello');
      expect(action, isNotNull);

      final mdAction = await registry.lookupAction(.executablePrompt, 'readme');
      expect(mdAction, isNull);
    });

    test('wires input.schema (picoschema) onto the prompt action', () async {
      File(p.join(tempDir.path, 'greet.prompt')).writeAsStringSync('''
---
input:
  schema:
    name: string, the person to greet
    formal?: boolean, whether to be formal
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'greet')
              as PromptAction;
      expect(
        action.inputSchema,
        isNotNull,
        reason:
            'input.schema in the .prompt file should be surfaced so the '
            'Developer UI can render a form and input can be validated',
      );

      final jsonSchema = action.inputSchema!.jsonSchema();
      expect(jsonSchema['type'], equals('object'));
      expect(jsonSchema['properties'], contains('name'));
      expect(
        (jsonSchema['properties'] as Map)['name'],
        containsPair('type', 'string'),
      );
      // Required and optional fields are honored.
      expect(jsonSchema['required'], contains('name'));
      expect(jsonSchema['required'], isNot(contains('formal')));
    });

    test('accepts plain JSON Schema for input.schema unchanged', () async {
      File(p.join(tempDir.path, 'jsoninput.prompt')).writeAsStringSync('''
---
input:
  schema:
    type: object
    properties:
      topic:
        type: string
    required:
      - topic
---
Write about {{topic}}.
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'jsoninput')
              as PromptAction;
      expect(action.inputSchema, isNotNull);
      final jsonSchema = action.inputSchema!.jsonSchema();
      expect(jsonSchema['type'], equals('object'));
      expect(jsonSchema['properties'], contains('topic'));
    });

    test('treats JSON Schema without a top-level type as JSON Schema', () async {
      // A valid JSON Schema may omit the top-level `type` and rely on
      // `properties` (or a combinator like anyOf). It must not be mistaken for
      // Picoschema and re-converted.
      File(p.join(tempDir.path, 'notype.prompt')).writeAsStringSync('''
---
input:
  schema:
    properties:
      topic:
        type: string
    required:
      - topic
---
Write about {{topic}}.
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'notype')
              as PromptAction;
      final jsonSchema = action.inputSchema!.jsonSchema();
      expect(jsonSchema['properties'], contains('topic'));
      // Picoschema conversion would have wrapped `properties` as a field, so
      // its value would no longer be a nested schema map.
      expect(
        (jsonSchema['properties'] as Map)['topic'],
        containsPair('type', 'string'),
      );
    });

    test('input schema parse tolerates null input', () async {
      File(p.join(tempDir.path, 'opt.prompt')).writeAsStringSync('''
---
input:
  schema:
    name: string, the name
---
Hello {{name}}.
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'opt') as PromptAction;
      // A prompt may be invoked with no input; parsing null must not throw.
      expect(() => action.inputSchema!.parse(null), returnsNormally);
      expect(action.inputSchema!.parse(null), isEmpty);
    });

    test('converts output.schema (picoschema) to JSON Schema', () async {
      File(p.join(tempDir.path, 'classify.prompt')).writeAsStringSync('''
---
output:
  format: json
  schema:
    category: string, the predicted category
    confidence: number, a score from 0 to 1
---
Classify: {{text}}
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'classify');
      final options = await (ep as PromptAction).prompt!.render({
        'text': 'hello',
      });

      // The output schema reaching the model must be JSON Schema, not the raw
      // Picoschema strings.
      final outputSchema = options.output!.jsonSchema as Map<String, dynamic>;
      expect(outputSchema['type'], equals('object'));
      final properties = outputSchema['properties'] as Map<String, dynamic>;
      expect(properties['category'], containsPair('type', 'string'));
      expect(properties['confidence'], containsPair('type', 'number'));
      expect(options.output!.format, equals('json'));
    });

    test('resolves a named schema referenced in input.schema', () async {
      // A schema registered via `defineSchema` is referenced by name in the
      // .prompt frontmatter. The loader must pass registered schemas to the
      // Picoschema converter so the reference resolves to the real schema.
      registry.registerValue('schema', 'Address', {
        'type': 'object',
        'properties': {
          'street': {'type': 'string'},
          'city': {'type': 'string'},
        },
        'required': ['street', 'city'],
      });

      File(p.join(tempDir.path, 'shipto.prompt')).writeAsStringSync('''
---
input:
  schema:
    address: Address
---
Ship to {{address.city}}.
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'shipto')
              as PromptAction;
      final jsonSchema = action.inputSchema!.jsonSchema();
      final addressSchema = (jsonSchema['properties'] as Map)['address'] as Map;
      // If the named reference were not resolved, `address` would not be an
      // object schema with the registered properties.
      expect(addressSchema['type'], equals('object'));
      expect(addressSchema['properties'], contains('street'));
      expect(addressSchema['properties'], contains('city'));
    });

    group('a schema defined after the prompt is loaded', () {
      // `Genkit(promptDir:)` loads prompts in its constructor, so
      // `ai.defineSchema` always runs after the load (#559).
      final recipe = {
        'type': 'object',
        'properties': {
          'title': {'type': 'string'},
        },
        'required': ['title'],
      };

      Future<PromptAction> load(String source) async {
        File(p.join(tempDir.path, 'recipe.prompt')).writeAsStringSync(source);
        loadPromptFolder(registry, dpRegistry, dir: tempDir.path);
        return await registry.lookupAction(.executablePrompt, 'recipe')
            as PromptAction;
      }

      test('resolves a bare output.schema name at render time', () async {
        final action = await load('''
---
output:
  schema: Recipe
  format: json
---
Generate a recipe for {{food}}.
''');
        registry.registerValue('schema', 'Recipe', recipe);

        final options = await action.prompt!.render({'food': 'pasta'});
        expect(options.output!.jsonSchema, recipe);
        expect(options.output!.format, 'json');
      });

      test('resolves nested names in input and output schemas', () async {
        final action = await load('''
---
input:
  schema:
    favorite: Recipe
output:
  schema:
    recipes(array): Recipe
---
More like {{favorite.title}}.
''');
        registry.registerValue('schema', 'Recipe', recipe);

        final inputSchema = action.inputSchema!.jsonSchema();
        expect((inputSchema['properties'] as Map)['favorite'], recipe);

        final options = await action.prompt!.render(<String, dynamic>{});
        final output = options.output!.jsonSchema!;
        final recipes = (output['properties'] as Map)['recipes'] as Map;
        expect(recipes['items'] ?? recipes, containsPair('type', 'object'));
        expect(jsonEncode(output), isNot(contains(r'"$ref":"Recipe"')));
      });

      test('fails clearly when the name is never defined', () async {
        final action = await load('''
---
output:
  schema: Recipe
---
Generate a recipe.
''');

        await expectLater(
          action.prompt!.render(<String, dynamic>{}),
          throwsA(
            isA<GenkitException>()
                .having(
                  (e) => e.status,
                  'status',
                  StatusCode.failedPrecondition,
                )
                .having(
                  (e) => e.message,
                  'message',
                  allOf(contains("'Recipe'"), contains('defineSchema')),
                ),
          ),
        );
        // The input form metadata still builds, with the name unresolved.
        expect(action.toJson, returnsNormally);

        // Defining it later makes the same prompt work.
        registry.registerValue('schema', 'Recipe', recipe);
        final options = await action.prompt!.render(<String, dynamic>{});
        expect(options.output!.jsonSchema, recipe);
      });

      group('a per-call output that does not need the undefined name', () {
        const source = '''
---
output:
  schema: Recipe
  format: json
---
Generate a recipe.
''';

        test('brings its own jsonSchema', () async {
          final action = await load(source);
          final own = {
            'type': 'object',
            'properties': {
              'name': {'type': 'string'},
            },
          };

          final options = await action.prompt!.render(
            <String, dynamic>{},
            PromptGenerateOptions(
              output: GenerateActionOutputConfig(jsonSchema: own),
            ),
          );
          expect(options.output!.jsonSchema, own);
          expect(options.output!.format, 'json');
        });

        test('switches the format', () async {
          final action = await load(source);

          final options = await action.prompt!.render(
            <String, dynamic>{},
            PromptGenerateOptions(
              output: GenerateActionOutputConfig(format: 'text'),
            ),
          );
          expect(options.output!.format, 'text');
          expect(options.output!.jsonSchema, isNull);
        });

        test('still fails when it keeps the prompt schema', () async {
          final action = await load(source);

          await expectLater(
            action.prompt!.render(
              <String, dynamic>{},
              PromptGenerateOptions(
                output: GenerateActionOutputConfig(constrained: false),
              ),
            ),
            throwsA(isA<GenkitException>()),
          );
        });
      });

      test('lists every undefined name in one error', () async {
        final action = await load('''
---
output:
  schema:
    first: Recipe
    second: Menu
---
Plan a meal.
''');

        await expectLater(
          action.prompt!.render(<String, dynamic>{}),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              allOf(contains("'Recipe'"), contains("'Menu'")),
            ),
          ),
        );
      });

      test('the input form leaves an undefined name open', () async {
        final action = await load('''
---
input:
  schema:
    favorite: Recipe
---
More like {{favorite.title}}.
''');
        // Not registered yet: the Dev UI form still builds, accepting anything.
        final props =
            action.inputSchema!.jsonSchema()['properties']
                as Map<String, dynamic>;
        expect(props['favorite'], isEmpty);
        expect(action.toJson, returnsNormally);

        // Registered later: the next read picks it up.
        registry.registerValue('schema', 'Recipe', recipe);
        final resolved =
            action.inputSchema!.jsonSchema()['properties']
                as Map<String, dynamic>;
        expect(resolved['favorite'], recipe);
      });
    });

    group('Picoschema (spec forms, #562)', () {
      Future<GenerateActionOptions> render(String source) async {
        File(p.join(tempDir.path, 'pico.prompt')).writeAsStringSync(source);
        loadPromptFolder(registry, dpRegistry, dir: tempDir.path);
        final action =
            await registry.lookupAction(.executablePrompt, 'pico')
                as PromptAction;
        return action.prompt!.render(<String, dynamic>{});
      }

      test('parenthesized types produce arrays, objects, enums', () async {
        final options = await render('''
---
output:
  schema:
    tags(array): string
    steps(array, the steps):
      number: integer
      instruction: string
    obj(object):
      x: integer
    status(enum): [A, B]
    (*): string
---
hi
''');
        final schema = options.output!.jsonSchema!;
        final props = schema['properties'] as Map<String, dynamic>;

        expect(props['tags'], {
          'type': 'array',
          'items': {'type': 'string'},
        });
        final steps = props['steps'] as Map<String, dynamic>;
        expect(steps['type'], 'array');
        expect(steps['description'], 'the steps');
        expect(
          (steps['items'] as Map)['properties'],
          allOf(contains('number'), contains('instruction')),
        );
        expect(props['obj'], containsPair('type', 'object'));
        expect(props['status'], {
          'enum': ['A', 'B'],
        });
        // The wildcard is additionalProperties, not a required property.
        expect(props, isNot(contains('*')));
        expect(schema['additionalProperties'], {'type': 'string'});
        expect(schema['required'], ['tags', 'steps', 'obj', 'status']);
      });

      test('the same forms apply to input.schema', () async {
        File(p.join(tempDir.path, 'in.prompt')).writeAsStringSync('''
---
input:
  schema:
    tags(array): string
---
Tags: {{tags}}
''');
        loadPromptFolder(registry, dpRegistry, dir: tempDir.path);
        final action =
            await registry.lookupAction(.executablePrompt, 'in')
                as PromptAction;
        final props =
            action.inputSchema!.jsonSchema()['properties']
                as Map<String, dynamic>;
        expect(props['tags'], {
          'type': 'array',
          'items': {'type': 'string'},
        });
      });

      // Pre-2.0 Dart-only syntax is now rejected. It is reported at load time
      // since it does not depend on what is registered.
      for (final (label, field) in [
        ('a bad parenthetical type', 'tags(list): string'),
        ('the old description syntax', 'email(the email): string'),
        ('a duplicate optional field', 'a: string\n    a?: string'),
      ]) {
        test('$label fails at load time', () {
          File(p.join(tempDir.path, 'bad.prompt')).writeAsStringSync('''
---
output:
  schema:
    $field
---
hi
''');
          expect(
            () => loadPromptFolder(registry, dpRegistry, dir: tempDir.path),
            throwsA(
              isA<GenkitException>()
                  .having((e) => e.status, 'status', StatusCode.invalidArgument)
                  .having(
                    (e) => e.message,
                    'message',
                    contains("Invalid schema in prompt 'bad'"),
                  ),
            ),
          );
        });
      }

      test('an unknown scalar-like name is an undefined type', () async {
        // `int` is not a Picoschema type, so it is looked up as a named
        // schema, which fails at render with a hint about scalar types.
        await expectLater(
          render('''
---
output:
  schema:
    n: int
---
hi
'''),
          throwsA(
            isA<GenkitException>().having(
              (e) => e.message,
              'message',
              allOf(contains("'int'"), contains('integer')),
            ),
          ),
        );
      });

      test('top-level JSON Schema is passed through untouched', () async {
        final options = await render('''
---
output:
  schema:
    type: [string, "null"]
---
hi
''');
        expect(options.output!.jsonSchema, {
          'type': ['string', 'null'],
        });
      });
    });

    test('parses bare-string middleware from the `use` frontmatter', () async {
      File(p.join(tempDir.path, 'retrying.prompt')).writeAsStringSync('''
---
use:
  - retry
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'retrying');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      final use = options.use!;
      expect(use, hasLength(1));
      expect(use.single.name, equals('retry'));
      expect(use.single.config, anyOf(isNull, isEmpty));
    });

    test('parses middleware with config from the `use` frontmatter', () async {
      File(p.join(tempDir.path, 'retrying.prompt')).writeAsStringSync('''
---
use:
  - name: retry
    config:
      maxRetries: 3
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'retrying');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      final use = options.use!;
      expect(use, hasLength(1));
      expect(use.single.name, equals('retry'));
      expect(use.single.config, containsPair('maxRetries', 3));
    });

    test('surfaces normalized `use` on the prompt metadata', () async {
      File(p.join(tempDir.path, 'retrying.prompt')).writeAsStringSync('''
---
toolChoice: required
use:
  - logging
  - name: retry
    config:
      maxRetries: 3
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action =
          await registry.lookupAction(.executablePrompt, 'retrying')
              as PromptAction;
      final promptMeta = action.metadata['prompt'] as Map<String, dynamic>;

      // Mirrors the JS loader's `metadata.prompt.use` / `toolChoice`.
      expect(promptMeta['toolChoice'], equals('required'));
      final useMeta = promptMeta['use'] as List;
      expect(useMeta, hasLength(2));
      expect(useMeta[0], equals({'name': 'logging'}));
      expect(
        useMeta[1],
        equals({
          'name': 'retry',
          'config': {'maxRetries': 3},
        }),
      );
    });

    test('skips malformed and unsupported `use` entries', () async {
      // A map without a `name`, and a non-string/non-map entry, are both
      // dropped rather than throwing; the valid entry is still parsed.
      File(p.join(tempDir.path, 'mixed.prompt')).writeAsStringSync('''
---
use:
  - retry
  - config:
      maxRetries: 3
  - 42
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'mixed');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      final use = options.use!;
      expect(use, hasLength(1));
      expect(use.single.name, equals('retry'));
    });

    test('parses toolChoice from frontmatter onto rendered options', () async {
      File(p.join(tempDir.path, 'choosy.prompt')).writeAsStringSync('''
---
toolChoice: required
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'choosy');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      expect(options.toolChoice, ToolChoice.required);
    });

    test('parses maxTurns and returnToolRequests from frontmatter', () async {
      File(p.join(tempDir.path, 'looped.prompt')).writeAsStringSync('''
---
maxTurns: 7
returnToolRequests: true
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'looped');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      expect(options.maxTurns, equals(7));
      expect(options.returnToolRequests, isTrue);
    });

    test('returnToolRequests can be false in frontmatter', () async {
      File(p.join(tempDir.path, 'noreturn.prompt')).writeAsStringSync('''
---
returnToolRequests: false
---
Hello {{name}}!
''');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'noreturn');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      expect(options.returnToolRequests, isFalse);
    });

    test('omits maxTurns/returnToolRequests when absent', () async {
      File(
        p.join(tempDir.path, 'bare.prompt'),
      ).writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'bare');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      expect(options.maxTurns, isNull);
      expect(options.returnToolRequests, isNull);
      expect(options.toolChoice, isNull);
    });

    test('throws a clear error for a wrong-typed maxTurns', () {
      File(p.join(tempDir.path, 'badturns.prompt')).writeAsStringSync('''
---
maxTurns: not-a-number
---
Hello {{name}}!
''');

      // A wrong-typed scalar option is an authoring error and must fail fast
      // with a GenkitException, not a raw TypeError or silent default.
      expect(
        () => loadPromptFolder(registry, dpRegistry, dir: tempDir.path),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            allOf(contains('maxTurns'), contains('badturns')),
          ),
        ),
      );
    });

    test('throws a clear error for a wrong-typed toolChoice', () {
      File(p.join(tempDir.path, 'badchoice.prompt')).writeAsStringSync('''
---
toolChoice:
  - not
  - a
  - string
---
Hello {{name}}!
''');

      expect(
        () => loadPromptFolder(registry, dpRegistry, dir: tempDir.path),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('toolChoice'),
          ),
        ),
      );
    });

    test('throws a clear error for a wrong-typed returnToolRequests', () {
      File(p.join(tempDir.path, 'badreturn.prompt')).writeAsStringSync('''
---
returnToolRequests: 3
---
Hello {{name}}!
''');

      expect(
        () => loadPromptFolder(registry, dpRegistry, dir: tempDir.path),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.message,
            'message',
            contains('returnToolRequests'),
          ),
        ),
      );
    });

    test('ignores a prompt with no `use` frontmatter', () async {
      File(
        p.join(tempDir.path, 'plain.prompt'),
      ).writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final ep = await registry.lookupAction(.executablePrompt, 'plain');
      final options = await (ep as PromptAction).prompt!.render({
        'name': 'World',
      });

      expect(options.use, anyOf(isNull, isEmpty));
    });
  });

  group('DotpromptRegistry', () {
    late DotpromptRegistry dpRegistry;

    setUp(() {
      dpRegistry = DotpromptRegistry();
    });

    test('defineSchema registers a named schema', () {
      dpRegistry.defineSchema('MyAddress', {
        'type': 'object',
        'properties': {
          'street': {'type': 'string'},
          'city': {'type': 'string'},
        },
        'required': ['street', 'city'],
      });

      // The schema should not throw - it's registered internally
      // We verify it works by using it in a picoschema prompt below
    });

    test(
      'defineSchema makes schema available in picoschema resolution',
      () async {
        dpRegistry.defineSchema('MyAddress', {
          'type': 'object',
          'properties': {
            'street': {'type': 'string'},
            'city': {'type': 'string'},
          },
          'required': ['street', 'city'],
        });

        // Create a prompt with picoschema output referencing the named schema.
        // A primitive field (name: string) is needed so isPicoschema() detects
        // this as Picoschema and triggers conversion.
        final metadata = await dpRegistry.renderMetadata('''
---
output:
  schema:
    name: string
    address: MyAddress
---
Tell me an address
''');

        // The output schema should have resolved MyAddress to its JSON Schema
        expect(metadata.output, isNotNull);
        expect(metadata.output!.schema, isNotNull);
        final props =
            metadata.output!.schema!['properties'] as Map<String, dynamic>;
        // The primitive field should be present
        expect(props, contains('name'));
        // The named schema reference should be resolved
        expect(props, containsPair('address', isA<Map>()));
        final addressSchema = props['address'] as Map<String, dynamic>;
        expect(addressSchema['type'], equals('object'));
        expect(addressSchema['properties'], isNotNull);
        final addressProps =
            addressSchema['properties'] as Map<String, dynamic>;
        expect(addressProps, contains('street'));
        expect(addressProps, contains('city'));
      },
    );

    test('schema resolver callback is used for schema lookup', () async {
      final resolvedSchemas = <String, Map<String, dynamic>>{
        'RemoteSchema': {
          'type': 'object',
          'properties': {
            'id': {'type': 'integer'},
            'name': {'type': 'string'},
          },
          'required': ['id', 'name'],
        },
      };

      final registry = DotpromptRegistry(
        schemaResolver: (name) async => resolvedSchemas[name],
      );

      // While schemaResolver is wired through DotpromptOptions,
      // the current dotprompt implementation uses _schemas (defineSchema)
      // for picoschema resolution. The resolver is available for future use.
      // Verify the registry can be created with a schemaResolver without error.
      expect(registry.dotprompt, isNotNull);
    });

    test('parses a template', () {
      final parsed = dpRegistry.parse('Hello {{name}}!');
      expect(parsed.template, isNotEmpty);
    });

    test('parses template with frontmatter', () {
      final parsed = dpRegistry.parse('''
---
model: test-model
config:
  temperature: 0.5
---
Hello {{name}}!
''');
      expect(parsed.metadata.model, equals('test-model'));
      expect(parsed.template, contains('Hello'));
    });

    test('compiles and renders a template', () async {
      final compiled = await dpRegistry.compile('Hello {{name}}!');
      final result = await compiled.render(
        dp.DataArgument(input: {'name': 'World'}),
      );
      expect(result.messages, isNotEmpty);
      final text = (result.messages.first.content.first as dp.TextPart).text;
      expect(text, contains('Hello World!'));
    });

    test('defines and uses partials', () async {
      dpRegistry.definePartial('greet', 'Hi {{name}}!');
      final compiled = await dpRegistry.compile('{{> greet}}');
      final result = await compiled.render(
        dp.DataArgument(input: {'name': 'Dart'}),
      );
      final text = (result.messages.first.content.first as dp.TextPart).text;
      expect(text, contains('Hi Dart!'));
    });

    test('renders a template directly', () async {
      final result = await dpRegistry.render(
        'Hello {{name}}!',
        dp.DataArgument(input: {'name': 'World'}),
      );
      expect(result.messages, isNotEmpty);
    });
  });
}
