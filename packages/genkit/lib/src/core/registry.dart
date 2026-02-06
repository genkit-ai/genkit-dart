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

import '../../genkit.dart' show Flow;
import '../ai/formatters/types.dart' show Formatter;
import '../ai/generate_middleware.dart' show GenerateMiddlewareDef;
import '../ai/model.dart' show BidiModel, Model;
import '../ai/tool.dart' show Tool;
import './action.dart';
import './plugin.dart';

class Registry {
  final Map<String, Action> _actions = {};
  final Map<String, dynamic> _values = {};
  final List<GenkitPlugin> _plugins = [];
  final Set<String> _initializedPlugins = {};
  final Registry? parent;
  final ToolRegistry toolRegistry = ToolRegistry();

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

  String _getKey(ActionType actionType, String name) =>
      '/${actionType.value}/$name';

  void registerValue(ActionType type, String name, dynamic value) {
    final key = _getKey(type, name);
    _values[key] = value;
  }

  T? lookupValue<T>(ActionType type, String name) {
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

  Future<T?> lookupAction<
    T extends Action<Input, Output, Chunk, Init>,
    Input,
    Output,
    Chunk,
    Init
  >(ActionType actionType, String name) async {
    final key = _getKey(actionType, name);
    if (_actions.containsKey(key)) {
      return _actions[key] as T;
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
            return _actions[key] as T;
          }
          final action = plugin.resolve(actionType, resolvedActionName);
          if (action != null) {
            register(action);
            return action as T;
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

  // First steps to replacing the action storage with individual storages

  Formatter<Output>? lookUpFormatter<Output>(String name) =>
      lookupValue(ActionType.format, name);

  GenerateMiddlewareDef<C>? lookUpMiddleware<C>(String name) =>
      lookupValue(ActionType.middleware, name);

  Future<Action<Input, Output, Chunk, Init>?>
  lookupEmbedder<Input, Output, Chunk, Init>(String name) async =>
      lookupAction(ActionType.embedder, name);

  Future<Model<C>?> lookUpModel<C>(String name) async =>
      lookupAction(ActionType.model, name) as Model<C>;

  Future<Tool<Input, Output>?> lookupTool<Input, Output>(
    String toolName,
  ) async => lookupAction(ActionType.tool, toolName) as Tool<Input, Output>?;

  Future<BidiModel<C>?> lookUpBidiModel<C>(String name) async =>
      lookupAction(ActionType.bidiModel, name) as BidiModel<C>?;

  Future<Flow?> lookUpFlow<Input, Output, Chunk, Init>(String flowName) async =>
      lookupAction(ActionType.flow, flowName)
          as Flow<Input, Output, Chunk, Init>?;

  void registerFormatter<T>(Formatter<T> formatter) {
    _values[_getKey(ActionType.format, formatter.name)] = formatter;
  }

  void registerMiddleware(GenerateMiddlewareDef mw) {
    _values[_getKey(ActionType.middleware, mw.name)] = mw;
  }
}

class ToolRegistry {
  void register(Tool<Object?, Object?> tool) {}
}

String getKey(ActionType actionType, String name) {
  return '/${actionType.value}/$name';
}
