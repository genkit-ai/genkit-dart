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

import 'package:dotprompt/dotprompt.dart' as dp;
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/dotprompt_registry.dart';
import 'package:genkit/src/ai/prompt.dart';
import 'package:genkit/src/ai/prompt_loader.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PromptConfig', () {
    test('creates with required name', () {
      final config = PromptConfig(name: 'test');
      expect(config.name, equals('test'));
      expect(config.variant, isNull);
      expect(config.fullName, equals('test'));
    });

    test('fullName includes variant', () {
      final config = PromptConfig(
        name: 'test',
        variant: 'v2',
      );
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
        toolChoice: 'auto',
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
  });

  group('PromptGenerateOptions', () {
    test('creates with all optional fields', () {
      final opts = PromptGenerateOptions(
        model: modelRef('override-model'),
        config: {'temperature': 0.5},
        toolChoice: 'required',
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

    test('returns an ExecutablePrompt', () {
      final config = PromptConfig(
        name: 'greet',
        prompt: 'Hello {{name}}',
      );

      final ep = definePromptAction(
        registry,
        dpRegistry,
        config,
      );

      expect(ep, isA<ExecutablePrompt>());
      expect(ep.ref.name, equals('greet'));
    });

    test('registers a PromptAction in the registry', () async {
      final config = PromptConfig(
        name: 'greet',
        prompt: 'Hello {{name}}',
      );

      definePromptAction(registry, dpRegistry, config);

      final action = await registry.lookupAction('prompt', 'greet');
      expect(action, isNotNull);
      expect(action, isA<PromptAction>());
    });

    test('registers with variant in name', () async {
      final config = PromptConfig(
        name: 'greet',
        variant: 'formal',
        prompt: 'Good day, {{name}}',
      );

      final ep = definePromptAction(
        registry,
        dpRegistry,
        config,
      );

      expect(ep.ref.name, equals('greet.formal'));

      final action = await registry.lookupAction('prompt', 'greet.formal');
      expect(action, isNotNull);
    });

    test('includes metadata in registration', () async {
      final config = PromptConfig(
        name: 'greet',
        model: modelRef('test-model'),
        prompt: 'Hello {{name}}',
        toolNames: ['tool1'],
        toolChoice: 'auto',
      );

      definePromptAction(registry, dpRegistry, config);

      final action = await registry.lookupAction('prompt', 'greet');
      expect(action, isNotNull);
      final pa = action as PromptAction;
      expect(pa.metadata['type'], equals('prompt'));
      expect(pa.metadata['prompt']['model'], equals('test-model'));
      expect(pa.metadata['prompt']['tools'], equals(['tool1']));
      expect(pa.metadata['prompt']['toolChoice'], equals('auto'));
    });
  });

  group('ExecutablePrompt.render', () {
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
      expect(options.messages!.length, equals(1));
      expect(options.messages![0].role, equals(Role.user));
      expect(
        options.messages![0].content[0].toJson()['text'],
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
      expect(options.messages!.length, equals(2));
      expect(options.messages![0].role, equals(Role.system));
      expect(
        options.messages![0].content[0].toJson()['text'],
        equals('You are a helpful assistant'),
      );
      expect(options.messages![1].role, equals(Role.user));
      expect(
        options.messages![1].content[0].toJson()['text'],
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

      expect(options.messages!.first.role, equals(Role.system));
      final sysText = options.messages!.first.content[0].toJson()['text'];
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
        PromptConfig(
          name: 'test',
          messages: history,
          prompt: 'New question',
        ),
      );

      final options = await ep.render({});

      // Should have history + new prompt
      expect(options.messages!.length, equals(3));
      expect(options.messages![0].role, equals(Role.user));
      expect(options.messages![1].role, equals(Role.model));
      expect(options.messages![2].role, equals(Role.user));
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
        PromptConfig(
          name: 'test',
          toolChoice: 'required',
          prompt: 'Hello',
        ),
      );

      final options = await ep.render({});

      expect(options.toolChoice, equals('required'));
    });

    test('opts toolChoice overrides config', () async {
      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(
          name: 'test',
          toolChoice: 'auto',
          prompt: 'Hello',
        ),
      );

      final options = await ep.render(
        {},
        PromptGenerateOptions(toolChoice: 'required'),
      );

      expect(options.toolChoice, equals('required'));
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
      expect(options.messages!.length, equals(3));
      expect(options.messages![0].role, equals(Role.user));
      expect(
        options.messages![0].content[0].toJson()['text'],
        equals('Old question'),
      );
      expect(options.messages![1].role, equals(Role.model));
      expect(
        options.messages![1].content[0].toJson()['text'],
        equals('Old answer'),
      );
      expect(options.messages![2].role, equals(Role.user));
      expect(
        options.messages![2].content[0].toJson()['text'],
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
      final lastMsg = options.messages!.last;
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

      expect(options.messages!.length, equals(2));
      expect(options.messages![0].role, equals(Role.system));
      expect(
        options.messages![0].content[0].toJson()['text'],
        equals('System instruction'),
      );
      expect(options.messages![1].role, equals(Role.user));
      expect(
        options.messages![1].content[0].toJson()['text'],
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
      final text = options.messages!.last.content[0].toJson()['text'];
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
      final text = options.messages!.last.content[0].toJson()['text'];
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
      expect(options.messages!.length, equals(1));
      final text = options.messages![0].content[0].toJson()['text'];
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

      final text = options.messages!.last.content[0].toJson()['text'];
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

      final sysText = options.messages!.first.content[0].toJson()['text'];
      expect(sysText, contains('Template system helpful'));
    });

    test(
      'renders system + messages + prompt in correct order',
      () async {
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
        expect(options.messages!.length, equals(4));
        expect(options.messages![0].role, equals(Role.system));
        expect(
          options.messages![0].content[0].toJson()['text'],
          contains('system foo'),
        );
        expect(options.messages![1].role, equals(Role.user));
        expect(
          options.messages![1].content[0].toJson()['text'],
          equals('hi'),
        );
        expect(options.messages![2].role, equals(Role.model));
        expect(
          options.messages![2].content[0].toJson()['text'],
          equals('bye'),
        );
        expect(options.messages![3].role, equals(Role.user));
        expect(
          options.messages![3].content[0].toJson()['text'],
          contains('user prompt foo'),
        );
      },
    );

    test(
      'renders multi-role messagesTemplate with {{role}} helper',
      () async {
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

        expect(options.messages!.length, equals(2));
        expect(options.messages![0].role, equals(Role.system));
        expect(
          options.messages![0].content[0].toJson()['text'],
          contains('system foo'),
        );
        expect(options.messages![1].role, equals(Role.user));
        expect(
          options.messages![1].content[0].toJson()['text'],
          contains('user foo'),
        );
      },
    );

    test(
      'messagesTemplate with opts.messages prepends history',
      () async {
        final ep = definePromptAction(
          registry,
          dpRegistry,
          PromptConfig(
            name: 'test',
            messagesTemplate: 'hello {{name}}',
          ),
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

        final options = await ep.render(
          {'name': 'World'},
          PromptGenerateOptions(messages: history),
        );

        // JS: messages: [template, history user, history model] — 3 messages
        // History is inserted after the template content
        expect(options.messages!.length, equals(3));
        // Verify all messages are present with correct content
        final texts = options.messages!
            .map((m) => m.content[0].toJson()['text'] as String)
            .toList();
        expect(texts.any((t) => t.contains('hello World')), isTrue);
        expect(texts.any((t) => t.contains('hi')), isTrue);
        expect(texts.any((t) => t.contains('bye')), isTrue);
        // History messages should have purpose metadata
        final historyMsgs = options.messages!
            .where((m) => m.toJson()['metadata']?['purpose'] == 'history')
            .toList();
        expect(historyMsgs.length, equals(2));
      },
    );

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

        final options = await ep.render(
          {'name': 'World'},
          PromptGenerateOptions(messages: history),
        );

        // JS: messages: [template user, history user (purpose:history),
        //                history model (purpose:history)]
        expect(options.messages!.length, equals(3));
        // First message should be from the template
        expect(options.messages![0].role, equals(Role.user));
        expect(
          options.messages![0].content[0].toJson()['text'],
          contains('hello World'),
        );
        // History messages should have purpose metadata
        final historyMsgs = options.messages!
            .where((m) => m.toJson()['metadata']?['purpose'] == 'history')
            .toList();
        expect(historyMsgs.length, equals(2));
        expect(
          historyMsgs[0].content[0].toJson()['text'],
          equals('prev Q'),
        );
        expect(
          historyMsgs[1].content[0].toJson()['text'],
          equals('prev A'),
        );
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
      final text = options.messages!.last.content[0].toJson()['text'];
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
      expect(ep, isA<ExecutablePrompt>());
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
      expect(ep, isA<ExecutablePrompt>());
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

      final ep = definePromptAction(
        registry,
        dpRegistry,
        PromptConfig(name: 'test', prompt: 'Hello {{name}}'),
      );

      final action = await registry.lookupAction('prompt', 'test');
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
      final opts = result as GenerateActionOptions;
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

    test('definePrompt returns ExecutablePrompt', () {
      final ep = genkit.definePrompt(
        name: 'hi',
        prompt: 'Say hi to {{name}}',
      );

      expect(ep, isA<ExecutablePrompt>());
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
      genkit.definePrompt(
        name: 'greeting',
        prompt: 'Hello {{name}}',
      );

      final ep = await genkit.prompt('greeting');
      expect(ep, isA<ExecutablePrompt>());
    });

    test('prompt() with variant', () async {
      genkit.definePrompt(
        name: 'greeting',
        variant: 'formal',
        prompt: 'Good day, {{name}}',
      );

      final ep = await genkit.prompt('greeting', variant: 'formal');
      expect(ep, isA<ExecutablePrompt>());
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

      final options = await ep.render({
        'kind': 'coding',
        'task': 'Dart',
      });

      expect(options.messages!.length, equals(2));
      expect(options.messages![0].role, equals(Role.system));
      expect(options.messages![1].role, equals(Role.user));
    });

    test('definePrompt with config options', () async {
      final ep = genkit.definePrompt(
        name: 'creative',
        model: modelRef('test/model'),
        config: {'temperature': 0.9},
        maxTurns: 3,
        toolChoice: 'auto',
        prompt: 'Write a story',
      );

      final options = await ep.render({});
      expect(options.model, equals('test/model'));
      expect(options.config!['temperature'], equals(0.9));
      expect(options.maxTurns, equals(3));
      expect(options.toolChoice, equals('auto'));
    });

    test('defineLegacyPrompt works for backwards compatibility', () async {
      final pa = genkit.defineLegacyPrompt<String>(
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
      final text = options.messages!.last.content[0].toJson()['text'];
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
      File(p.join(tempDir.path, 'hello.prompt'))
          .writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action = await registry.lookupAction('prompt', 'hello');
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

      final action = await registry.lookupAction('prompt', 'greeting');
      expect(action, isNotNull);
      final pa = action as PromptAction;
      expect(pa.metadata['prompt']['model'], equals('test-model'));
    });

    test('loads variant prompts', () async {
      File(p.join(tempDir.path, 'greeting.prompt'))
          .writeAsStringSync('Hi {{name}}!');
      File(p.join(tempDir.path, 'greeting.formal.prompt'))
          .writeAsStringSync('Good day, {{name}}.');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final defaultAction =
          await registry.lookupAction('prompt', 'greeting');
      final formalAction =
          await registry.lookupAction('prompt', 'greeting.formal');

      expect(defaultAction, isNotNull);
      expect(formalAction, isNotNull);
    });

    test('registers underscore-prefixed files as partials', () async {
      // Create a partial
      File(p.join(tempDir.path, '_header.prompt'))
          .writeAsStringSync('Welcome, {{name}}!');
      // Create a prompt that uses the partial
      File(p.join(tempDir.path, 'page.prompt'))
          .writeAsStringSync('{{> header}} How can I help?');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      // The partial should not be registered as a prompt action
      final partialAction = await registry.lookupAction('prompt', 'header');
      expect(partialAction, isNull);

      // But the main prompt should be registered
      final pageAction = await registry.lookupAction('prompt', 'page');
      expect(pageAction, isNotNull);
    });

    test('loads prompts from subdirectories', () async {
      final subDir = Directory(p.join(tempDir.path, 'sub'));
      subDir.createSync();
      File(p.join(subDir.path, 'nested.prompt'))
          .writeAsStringSync('Nested prompt');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      final action = await registry.lookupAction('prompt', 'sub/nested');
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
      File(p.join(tempDir.path, 'hello.prompt'))
          .writeAsStringSync('Hello {{name}}!');

      loadPromptFolder(
        registry,
        dpRegistry,
        dir: tempDir.path,
        ns: 'myapp',
      );

      final action = await registry.lookupAction('prompt', 'myapp/hello');
      expect(action, isNotNull);
    });

    test('loads multiple prompts', () async {
      File(p.join(tempDir.path, 'a.prompt')).writeAsStringSync('Prompt A');
      File(p.join(tempDir.path, 'b.prompt')).writeAsStringSync('Prompt B');
      File(p.join(tempDir.path, 'c.prompt')).writeAsStringSync('Prompt C');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      expect(await registry.lookupAction('prompt', 'a'), isNotNull);
      expect(await registry.lookupAction('prompt', 'b'), isNotNull);
      expect(await registry.lookupAction('prompt', 'c'), isNotNull);
    });

    test('ignores non-prompt files', () async {
      File(p.join(tempDir.path, 'hello.prompt'))
          .writeAsStringSync('Hello {{name}}!');
      File(p.join(tempDir.path, 'readme.md'))
          .writeAsStringSync('# Not a prompt');
      File(p.join(tempDir.path, 'config.json'))
          .writeAsStringSync('{"key": "value"}');

      loadPromptFolder(registry, dpRegistry, dir: tempDir.path);

      // Only the .prompt file should be loaded
      final action = await registry.lookupAction('prompt', 'hello');
      expect(action, isNotNull);

      final mdAction = await registry.lookupAction('prompt', 'readme');
      expect(mdAction, isNull);
    });
  });

  group('DotpromptRegistry', () {
    late DotpromptRegistry dpRegistry;

    setUp(() {
      dpRegistry = DotpromptRegistry();
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

