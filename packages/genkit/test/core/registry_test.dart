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
import 'package:genkit/src/core/plugin.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:test/test.dart';

class TestPlugin extends GenkitPlugin {
  @override
  final String name;
  final Action? resolvedAction;
  final List<ActionMetadata> listedActions;
  final List<Action> initActions;
  int initCount = 0;

  TestPlugin(
    this.name, {
    this.resolvedAction,
    this.listedActions = const [],
    this.initActions = const [],
  });

  @override
  Future<List<Action>> init() async {
    initCount++;
    return initActions;
  }

  @override
  Action? resolve(String actionType, String name) {
    if (resolvedAction != null && resolvedAction!.name == name) {
      return resolvedAction;
    }
    return null;
  }

  @override
  Future<List<ActionMetadata>> list() async {
    return listedActions;
  }
}

void main() {
  group('Registry', () {
    test('register and get action', () async {
      final registry = Registry();
      final action = Action(
        actionType: 'test',
        name: 'testAction',
        fn: (input, context) async => 'output',
      );
      registry.register(action);
      final retrievedAction = await registry.lookupAction('test', 'testAction');
      expect(retrievedAction, same(action));
    });

    test('get returns null when action not found', () async {
      final registry = Registry();
      final retrievedAction = await registry.lookupAction(
        'test',
        'nonExistent',
      );
      expect(retrievedAction, isNull);
    });

    test('get returns null when plugin cannot resolve', () async {
      final registry = Registry();
      final plugin = TestPlugin('myPlugin');
      registry.registerPlugin(plugin);
      final retrievedAction = await registry.lookupAction(
        'model',
        'myPlugin/nonExistent',
      );
      expect(retrievedAction, isNull);
    });

    test('get action from plugin', () async {
      final registry = Registry();
      final action = Action(
        actionType: 'model',
        name: 'myModel',
        fn: (input, context) async => 'output',
      );
      final plugin = TestPlugin('myPlugin', resolvedAction: action);
      registry.registerPlugin(plugin);

      expect(plugin.initCount, 0);
      final retrievedAction = await registry.lookupAction(
        'model',
        'myPlugin/myModel',
      );
      expect(plugin.initCount, 1);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, 'myModel');

      // Verify that the action is now cached
      final cachedAction = await registry.lookupAction(
        'model',
        'myPlugin/myModel',
      );
      expect(cachedAction, same(retrievedAction));
    });

    test('list actions with plugins', () async {
      final registry = Registry();
      final directAction = Action(
        actionType: 'flow',
        name: 'directFlow',
        fn: (input, context) async => 'output',
      );
      registry.register(directAction);

      final pluginAction = Action(
        actionType: 'flow',
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
        actions.any((a) => a.actionType == 'flow' && a.name == 'directFlow'),
        isTrue,
      );
      expect(
        actions.any(
          (a) => a.actionType == 'flow' && a.name == 'myPlugin/pluginFlow',
        ),
        isTrue,
      );
    });

    test('list actions without plugins', () async {
      final registry = Registry();
      final action = Action(
        actionType: 'test',
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
        actionType: 'model',
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
        actionType: 'test',
        name: 'parentAction',
        fn: (input, context) async => 'parent',
      );
      parent.register(parentAction);

      final childAction = Action(
        actionType: 'test',
        name: 'childAction',
        fn: (input, context) async => 'child',
      );
      child.register(childAction);

      expect(
        await child.lookupAction('test', 'childAction'),
        same(childAction),
      );
      expect(
        await child.lookupAction('test', 'parentAction'),
        same(parentAction),
      );
    });

    test('lookupAction prefers local action over parent', () async {
      final parent = Registry();
      final child = Registry.childOf(parent);

      final parentAction = Action(
        actionType: 'test',
        name: 'shared',
        fn: (input, context) async => 'parent',
      );
      parent.register(parentAction);

      final childAction = Action(
        actionType: 'test',
        name: 'shared',
        fn: (input, context) async => 'child',
      );
      child.register(childAction);

      expect(await child.lookupAction('test', 'shared'), same(childAction));
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

    test('listActions merges parent and local actions', () async {
      final parent = Registry();
      final child = Registry.childOf(parent);

      final parentAction = Action(
        actionType: 'test',
        name: 'parentAction',
        fn: (input, context) async => 'parent',
      );
      parent.register(parentAction);

      final sharedParent = Action(
        actionType: 'test',
        name: 'shared',
        fn: (input, context) async => 'parent',
      );
      parent.register(sharedParent);

      final childAction = Action(
        actionType: 'test',
        name: 'childAction',
        fn: (input, context) async => 'child',
      );
      child.register(childAction);

      final sharedChild = Action(
        actionType: 'test',
        name: 'shared',
        fn: (input, context) async => 'child',
      );
      child.register(sharedChild);

      final actions = await child.listActions();
      expect(actions.length, 3);

      final parentMeta = actions.firstWhere((a) => a.name == 'parentAction');
      expect(parentMeta.name, 'parentAction');

      final childMeta = actions.firstWhere((a) => a.name == 'childAction');
      expect(childMeta.name, 'childAction');

      final sharedMeta = actions.firstWhere((a) => a.name == 'shared');
      // The child one should shadow the parent one, so it should satisfy 'child' check if we inspected implementation,
      // but listActions returns Metadata.
      // We can verify it's the child action effectively because `lookupAction` would return it?
      // Actually `listActions` returns `ActionMetadata` which often IS `Action` (subclass).
      // Action implements ActionMetadata.
      expect(sharedMeta, same(sharedChild));
    });
  });
}
