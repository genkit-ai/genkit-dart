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

import './action.dart';
import './plugin.dart';

class Registry {
  final Map<String, Action> _actions = {};
  final Map<String, dynamic> _values = {};
  final List<GenkitPlugin> _plugins = [];
  final Set<String> _initializedPlugins = {};
  final Registry? parent;

  Registry({this.parent});

  factory Registry.childOf(Registry parent) {
    return Registry(parent: parent);
  }

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

  void registerValue(String type, String name, dynamic value) {
    final key = _getKey(type, name);
    _values[key] = value;
  }

  T? lookupValue<T>(String type, String name) {
    final key = _getKey(type, name);
    if (_values.containsKey(key)) {
      return _values[key] as T?;
    }
    return parent?.lookupValue<T>(type, name);
  }

  Map<String, T> listValues<T>(String type) {
    final prefix = '/$type/';
    final result = <String, T>{};
    if (parent != null) {
      result.addAll(parent!.listValues<T>(type));
    }
    for (final key in _values.keys) {
      if (key.startsWith(prefix)) {
        result[key] = _values[key] as T;
      }
    }
    return result;
  }

  void register(Action action) {
    final key = _getKey(action.actionType, action.name);
    _actions[key] = action;
  }

  Future<Action?> lookupAction(String actionType, String name) async {
    final key = _getKey(actionType, name);
    if (_actions.containsKey(key)) {
      return _actions[key];
    }
    final parts = name.split('/');
    if (parts.length == 2) {
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
    }
    return parent?.lookupAction(actionType, name);
  }

  Future<List<ActionMetadata>> listActions() async {
    await _ensureAllPluginsInitialized();
    final allActions = <String, ActionMetadata>{};
    for (final action in _actions.values) {
      final key = _getKey(action.actionType, action.name);
      allActions[key] = action;
    }

    for (final plugin in _plugins) {
      try {
        final pluginActions = await plugin.list();
        for (final action in pluginActions) {
          final key = _getKey(action.actionType, action.name);
          if (!allActions.containsKey(key)) {
            allActions[key] = action;
          }
        }
      } catch (e, st) {
        print('Failed to list actions from plugin ${plugin.name}: $e $st');
      }
    }
    return allActions.values.toList();
  }
}

String getKey(String actionType, String name) {
  return '/$actionType/$name';
}
