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
      final retrievedAction = await registry.get('test', 'testAction');
      expect(retrievedAction, same(action));
    });

    test('get returns null when action not found', () async {
      final registry = Registry();
      final retrievedAction = await registry.get('test', 'nonExistent');
      expect(retrievedAction, isNull);
    });

    test('get returns null when plugin cannot resolve', () async {
      final registry = Registry();
      final plugin = TestPlugin('myPlugin');
      registry.registerPlugin(plugin);
      final retrievedAction = await registry.get('model', 'myPlugin/nonExistent');
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
      final retrievedAction = await registry.get('model', 'myPlugin/myModel');
      expect(plugin.initCount, 1);
      expect(retrievedAction, isNotNull);
      expect(retrievedAction!.name, 'myModel');

      // Verify that the action is now cached
      final cachedAction = await registry.get('model', 'myPlugin/myModel');
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

      final plugin = TestPlugin('myPlugin', listedActions: [
        ActionMetadata(
          actionType: pluginAction.actionType,
          name: 'myPlugin/${pluginAction.name}',
        )
      ]);
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

      final plugin = TestPlugin('myPlugin', listedActions: [
        ActionMetadata(
          actionType: action.actionType,
          name: action.name,
        )
      ]);
      registry.registerPlugin(plugin);

      final actions = await registry.listActions();
      expect(actions.length, 1);
    });
  });
}
