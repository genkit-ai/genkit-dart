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

import 'package:genkit/src/core/action.dart';
import 'package:genkit/src/core/dynamic_action_provider.dart';
import 'package:genkit/src/core/plugin.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:test/test.dart';

class TestPlugin extends GenkitPlugin {
  @override
  final String name;
  final Action? resolvedAction;
  final List<ActionMetadata> listedActions;
  final List<Action> initActions;
  final Duration? listDelay;
  int initCount = 0;
  int listCount = 0;

  TestPlugin(
    this.name, {
    this.resolvedAction,
    this.listedActions = const [],
    this.initActions = const [],
    this.listDelay,
  });

  @override
  Future<List<Action>> init() async {
    initCount++;
    return initActions;
  }

  @override
  Action? resolve(ActionType actionType, String name) {
    if (resolvedAction != null && resolvedAction!.name == name) {
      return resolvedAction;
    }
    return null;
  }

  @override
  Future<List<ActionMetadata>> list() async {
    listCount++;
    if (listDelay != null) {
      await Future.delayed(listDelay!);
    }
    return listedActions;
  }
}

void main() {
  group('Registry', () {
    test('register and get action', () async {
      final registry = Registry();
      final action = Action(
        actionType: ActionType('test'),
        name: 'testAction',
        fn: (input, context) async => 'output',
      );
      registry.register(action);
      final retrievedAction = await registry.lookupAction(
        ActionType('test'),
        'testAction',
      );
      expect(retrievedAction, same(action));
    });

    test('get returns null when action not found', () async {
      final registry = Registry();
      final retrievedAction = await registry.lookupAction(
        ActionType('test'),
        'nonExistent',
      );
      expect(retrievedAction, isNull);
    });

    test('get returns null when plugin cannot resolve', () async {
      final registry = Registry();
      final plugin = TestPlugin('myPlugin');
      registry.registerPlugin(plugin);
      final retrievedAction = await registry.lookupAction(
        .model,
        'myPlugin/nonExistent',
      );
      expect(retrievedAction, isNull);
    });

    test('get action from plugin', () async {
      final registry = Registry();
      final action = Action(
        actionType: .model,
        name: 'myModel',
        fn: (input, context) async => 'output',
      );
      final plugin = TestPlugin('myPlugin', resolvedAction: action);
      registry.registerPlugin(plugin);

      expect(plugin.initCount, 0);
      final retrievedAction = await registry.lookupAction(
        .model,
        'myPlugin/myModel',
      );
      expect(plugin.initCount, 1);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, 'myModel');

      // Verify that the action is now cached
      final cachedAction = await registry.lookupAction(
        .model,
        'myPlugin/myModel',
      );
      expect(cachedAction, same(retrievedAction));
    });

    test('get action from plugin with slash in action name', () async {
      final registry = Registry();
      final action = Action(
        actionType: .model,
        name: 'zai-org/glm-5-maas',
        fn: (input, context) async => 'output',
      );
      final plugin = TestPlugin('openai', resolvedAction: action);
      registry.registerPlugin(plugin);

      expect(plugin.initCount, 0);
      final retrievedAction = await registry.lookupAction(
        .model,
        'openai/zai-org/glm-5-maas',
      );
      expect(plugin.initCount, 1);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, 'zai-org/glm-5-maas');
    });

    test('list actions with plugins', () async {
      final registry = Registry();
      final directAction = Action(
        actionType: .flow,
        name: 'directFlow',
        fn: (input, context) async => 'output',
      );
      registry.register(directAction);

      final pluginAction = Action(
        actionType: .flow,
        name: 'pluginFlow',
        fn: (input, context) async => 'output',
      );

      final plugin = TestPlugin(
        'myPlugin',
        listedActions: [
          ActionMetadata(
            actionType: pluginAction.actionType,
            name: 'myPlugin/${pluginAction.name}',
          ),
        ],
      );
      registry.registerPlugin(plugin);

      expect(plugin.initCount, 0);
      final actions = await registry.listActions();
      expect(plugin.initCount, 1);
      expect(actions.length, 2);
      expect(
        actions.any((a) => a.actionType == .flow && a.name == 'directFlow'),
        isTrue,
      );
      expect(
        actions.any(
          (a) => a.actionType == .flow && a.name == 'myPlugin/pluginFlow',
        ),
        isTrue,
      );
    });

    test('list actions without plugins', () async {
      final registry = Registry();
      final action = Action(
        actionType: ActionType('test'),
        name: 'testAction',
        fn: (input, context) async => 'output',
      );
      registry.register(action);
      final actions = await registry.listActions();
      expect(actions.length, 1);
      expect(actions.first.name, 'testAction');
    });

    test('list actions does not add duplicates', () async {
      final registry = Registry();
      final action = Action(
        actionType: .model,
        name: 'myModel',
        fn: (input, context) async => 'output',
      );
      registry.register(action);

      final plugin = TestPlugin(
        'myPlugin',
        listedActions: [
          ActionMetadata(actionType: action.actionType, name: action.name),
        ],
      );
      registry.registerPlugin(plugin);

      final actions = await registry.listActions();
      expect(actions.length, 1);
    });

    test('list actions caching', () async {
      final registry = Registry();
      final plugin = TestPlugin(
        'myPlugin',
        listedActions: [
          ActionMetadata(actionType: .model, name: 'myPlugin/myModel'),
        ],
      );
      registry.registerPlugin(plugin);

      expect(plugin.initCount, 0);

      // First call should trigger discovery
      final actions1 = await registry.listActions();
      expect(actions1.length, 1);
      expect(plugin.initCount, 1);
      expect(plugin.listCount, 1);

      // Second call should use cache
      final actions2 = await registry.listActions();
      expect(actions2.length, 1);
      expect(plugin.initCount, 1);
      expect(plugin.listCount, 1); // Should still be 1
    });

    test('list actions caching concurrent', () async {
      final registry = Registry();
      final plugin = TestPlugin(
        'myPlugin',
        listedActions: [
          ActionMetadata(actionType: .model, name: 'myPlugin/myModel'),
        ],
        listDelay: Duration(milliseconds: 100),
      );
      registry.registerPlugin(plugin);

      // Invoke listActions multiple times concurrently
      final futures = Iterable.generate(5, (_) => registry.listActions());
      final results = await Future.wait(futures);

      expect(results.length, 5);
      for (final actions in results) {
        expect(actions.length, 1);
        expect(actions.first.name, 'myPlugin/myModel');
      }

      expect(plugin.listCount, 1); // Should ONLY be called once
    });

    test('list actions retry on failure', () async {
      final registry = Registry();
      var fail = true;
      final plugin = TestPlugin(
        'myPlugin',
        listedActions: [
          ActionMetadata(actionType: .model, name: 'myPlugin/myModel'),
        ],
      );

      // A plugin that fails the first time
      final failingPlugin = _FailingPlugin(plugin, () => fail);
      registry.registerPlugin(failingPlugin);

      // First call fails (silently in listActions, but logged)
      fail = true;
      final actionsEmpty = await registry.listActions();
      expect(actionsEmpty, isEmpty);
      expect(failingPlugin.listCount, 1);
      expect(plugin.listCount, 0);

      // Second call should retry since first one failed
      fail = false;
      final actions = await registry.listActions();
      expect(actions.length, 1);
      expect(failingPlugin.listCount, 2);
      expect(plugin.listCount, 1);

      // Third call should use cache
      final actionsCached = await registry.listActions();
      expect(actionsCached.length, 1);
      expect(failingPlugin.listCount, 2); // Should still be 2
      expect(plugin.listCount, 1);
    });
  });

  group('Registry Hierarchy', () {
    test('lookupValue delegates to parent if not found locally', () {
      final parent = Registry();
      final child = Registry.childOf(parent);

      parent.registerValue('test', 'parentValue', 'parent');
      child.registerValue('test', 'childValue', 'child');

      expect(child.lookupValue<String>('test', 'childValue'), 'child');
      expect(child.lookupValue<String>('test', 'parentValue'), 'parent');
    });

    test('lookupValue prefers local value over parent', () {
      final parent = Registry();
      final child = Registry.childOf(parent);

      parent.registerValue('test', 'shared', 'parent');
      child.registerValue('test', 'shared', 'child');

      expect(child.lookupValue<String>('test', 'shared'), 'child');
    });

    test('lookupAction delegates to parent if not found locally', () async {
      final parent = Registry();
      final child = Registry.childOf(parent);

      final parentAction = Action(
        actionType: ActionType('test'),
        name: 'parentAction',
        fn: (input, context) async => 'parent',
      );
      parent.register(parentAction);

      final childAction = Action(
        actionType: ActionType('test'),
        name: 'childAction',
        fn: (input, context) async => 'child',
      );
      child.register(childAction);

      expect(
        await child.lookupAction(ActionType('test'), 'childAction'),
        same(childAction),
      );
      expect(
        await child.lookupAction(ActionType('test'), 'parentAction'),
        same(parentAction),
      );
    });

    test('lookupAction prefers local action over parent', () async {
      final parent = Registry();
      final child = Registry.childOf(parent);

      final parentAction = Action(
        actionType: ActionType('test'),
        name: 'shared',
        fn: (input, context) async => 'parent',
      );
      parent.register(parentAction);

      final childAction = Action(
        actionType: ActionType('test'),
        name: 'shared',
        fn: (input, context) async => 'child',
      );
      child.register(childAction);

      expect(
        await child.lookupAction(ActionType('test'), 'shared'),
        same(childAction),
      );
    });

    test('listValues merges parent and local values', () {
      final parent = Registry();
      final child = Registry.childOf(parent);

      parent.registerValue('test', 'parentValue', 'parent');
      parent.registerValue('test', 'shared', 'parent');
      child.registerValue('test', 'childValue', 'child');
      child.registerValue('test', 'shared', 'child');

      final values = child.listValues<String>('test');
      expect(values, containsPair('/test/parentValue', 'parent'));
      expect(values, containsPair('/test/childValue', 'child'));
      expect(values, containsPair('/test/shared', 'child'));
    });
  });

  group('parseRegistryKey', () {
    test('parses a plugin-scoped key', () {
      final parsed = parseRegistryKey('/model/googleai/gemini-flash-latest');
      expect(parsed, isNotNull);
      expect(parsed!.dynamicActionHost, isNull);
      expect(parsed.actionType, ActionType.model);
      expect(parsed.actionName, 'gemini-flash-latest');
    });

    test('parses a nested action name', () {
      final parsed = parseRegistryKey('/prompt/my-plugin/folder/my-prompt');
      expect(parsed, isNotNull);
      expect(parsed!.actionType, ActionType('prompt'));
      expect(parsed.actionName, 'folder/my-prompt');
    });

    test('parses a util key', () {
      final parsed = parseRegistryKey('/util/generate');
      expect(parsed, isNotNull);
      expect(parsed!.actionType, ActionType.util);
      expect(parsed.actionName, 'generate');
    });

    test('parses a DAP key', () {
      final parsed = parseRegistryKey(
        '/dynamic-action-provider/my-host:tool.v2/weatherTool',
      );
      expect(parsed, isNotNull);
      expect(parsed!.dynamicActionHost, 'my-host');
      expect(parsed.actionType, ActionType.tool);
      expect(parsed.actionName, 'weatherTool');
    });

    test('preserves colons inside a DAP action name', () {
      final parsed = parseRegistryKey(
        '/dynamic-action-provider/my-host:resource/scheme://a:b/c',
      );
      expect(parsed, isNotNull);
      expect(parsed!.dynamicActionHost, 'my-host');
      expect(parsed.actionType, ActionType('resource'));
      // Everything after the first colon and the action type segment is the
      // name, colons included.
      expect(parsed.actionName, 'scheme://a:b/c');
    });

    test('parses a host-only DAP key', () {
      final parsed = parseRegistryKey('/dynamic-action-provider/my-host');
      expect(parsed, isNotNull);
      expect(parsed!.dynamicActionHost, isNull);
      expect(parsed.actionType, ActionType.dynamicActionProvider);
      expect(parsed.actionName, 'my-host');
    });

    test('returns null for a malformed key', () {
      expect(parseRegistryKey('/model'), isNull);
      expect(parseRegistryKey('nope'), isNull);
    });
  });

  group('lookupActionByKey', () {
    test('resolves a plain registered action key', () async {
      final registry = Registry();
      final action = Action(
        actionType: ActionType('test'),
        name: 'testAction',
        fn: (input, context) async => 'output',
      );
      registry.register(action);

      final resolved = await registry.lookupActionByKey('/test/testAction');
      expect(resolved, same(action));
    });

    test('resolves a plugin-namespaced key by its full name', () async {
      final registry = Registry();
      final action = Action(
        actionType: .model,
        name: 'myModel',
        fn: (input, context) async => 'output',
      );
      registry.registerPlugin(TestPlugin('myPlugin', resolvedAction: action));

      final resolved = await registry.lookupActionByKey(
        '/model/myPlugin/myModel',
      );
      expect(resolved, isNotNull);
      expect(resolved!.name, 'myModel');
    });

    test(
      'resolves a dynamic-action-provider key through its provider',
      () async {
        final registry = Registry();
        final tool = Action(
          actionType: .tool,
          name: 'weatherTool',
          fn: (input, context) async => 'sunny',
        );
        final dap = DynamicActionProvider(
          name: 'my-host',
          listActionsFn: () => [
            ActionMetadata(actionType: .tool, name: 'weatherTool'),
          ],
          getActionFn: (actionType, name) async =>
              actionType == ActionType.tool && name == 'weatherTool'
              ? tool
              : null,
        );
        registry.register(dap);

        final resolved = await registry.lookupActionByKey(
          dapActionKey('my-host', ActionType.tool, 'weatherTool'),
        );
        expect(resolved, same(tool));
      },
    );

    test('returns null for a wildcard dynamic-action-provider key', () async {
      final registry = Registry();
      final dap = DynamicActionProvider(
        name: 'my-host',
        listActionsFn: () => [
          ActionMetadata(actionType: .tool, name: 'weatherTool'),
        ],
        getActionFn: (actionType, name) async => null,
      );
      registry.register(dap);

      final resolved = await registry.lookupActionByKey(
        dapActionKey('my-host', ActionType.tool, '*'),
      );
      expect(resolved, isNull);
    });

    test('returns null for a malformed key', () async {
      final registry = Registry();
      expect(await registry.lookupActionByKey('/model'), isNull);
      expect(await registry.lookupActionByKey('nope'), isNull);
    });
  });
}

class _FailingPlugin extends GenkitPlugin {
  final GenkitPlugin _plugin;
  final bool Function() _shouldFail;
  int listCount = 0;

  _FailingPlugin(this._plugin, this._shouldFail);

  @override
  String get name => _plugin.name;

  @override
  Future<List<Action>> init() => _plugin.init();

  @override
  Action? resolve(ActionType actionType, String name) =>
      _plugin.resolve(actionType, name);

  @override
  Future<List<ActionMetadata>> list() async {
    listCount++;
    if (_shouldFail()) {
      throw Exception('Failing on purpose');
    }
    return _plugin.list();
  }
}
