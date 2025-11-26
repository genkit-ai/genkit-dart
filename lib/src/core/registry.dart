import './action.dart';
import './plugin.dart';

class Registry {
  final Map<String, Action> _actions = {};
  final List<GenkitPlugin> _plugins = [];
  final Set<String> _initializedPlugins = {};

  Future<void> _ensurePluginInitialized(GenkitPlugin plugin) async {
    if (!_initializedPlugins.contains(plugin.name)) {
      final actions = await plugin.init();
      for (final action in actions) {
        register(action);
      }
      _initializedPlugins.add(plugin.name);
    }
  }

  Future<void> _ensureAllPluginsInitialized() async {
    for (final plugin in _plugins) {
      await _ensurePluginInitialized(plugin);
    }
  }

  void registerPlugin(GenkitPlugin plugin) {
    _plugins.add(plugin);
  }

  String _getKey(String actionType, String name) {
    return '/$actionType/$name';
  }

  void register(Action action) {
    final key = _getKey(action.actionType, action.name);
    _actions[key] = action;
  }

  Future<Action?> get(String actionType, String name) async {
    final key = _getKey(actionType, name);
    if (_actions.containsKey(key)) {
      return _actions[key];
    }
    final parts = name.split('/');
    if (parts.length != 2) {
      return null;
    }
    final pluginName = parts[0];
    final resolvedActionName = parts[1];
    for (final plugin in _plugins) {
      if (plugin.name == pluginName) {
        await _ensurePluginInitialized(plugin);
        // The action might have been registered during init.
        if (_actions.containsKey(key)) {
          return _actions[key];
        }
        final action = plugin.resolve(actionType, resolvedActionName);
        if (action != null) {
          register(action);
          return action;
        }
      }
    }
    return null;
  }

  Future<List<ActionMetadata>> listActions() async {
    await _ensureAllPluginsInitialized();
    final allActions = <String, ActionMetadata>{};
    for (final action in _actions.values) {
      final key = _getKey(action.actionType, action.name);
      allActions[key] = action;
    }

    for (final plugin in _plugins) {
      final pluginActions = await plugin.list();
      for (final action in pluginActions) {
        final key = _getKey(action.actionType, action.name);
        if (!allActions.containsKey(key)) {
          allActions[key] = action;
        }
      }
    }
    return allActions.values.toList();
  }
}

String getKey(String actionType, String name) {
  return '/$actionType/$name';
}
