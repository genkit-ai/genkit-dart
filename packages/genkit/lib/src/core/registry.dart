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

import '../ai/generate_middleware.dart';
import './action.dart';
import './dynamic_action_provider.dart';
import './plugin.dart';

/// The parsed components of a registry key.
///
/// A key is either a plain action key (`/model/googleai/gemini-flash-latest`,
/// `/util/generate`) or a dynamic-action-provider key
/// (`/dynamic-action-provider/<host>:<actionType>/<name>`). Mirrors JS's
/// `ParsedRegistryKey`.
class ParsedRegistryKey {
  final String? dynamicActionHost;
  final ActionType actionType;
  final String actionName;

  ParsedRegistryKey({
    this.dynamicActionHost,
    required this.actionType,
    required this.actionName,
  });
}

/// Parses a registry [key] into its components, or returns null when the key
/// is malformed. Mirrors JS's `parseRegistryKey`.
ParsedRegistryKey? parseRegistryKey(String key) {
  if (key.startsWith('/dynamic-action-provider')) {
    // Format: /dynamic-action-provider/<host>:<actionType>/<name>
    // (or just /dynamic-action-provider/<host> with no action suffix).
    final keyTokens = key.split(':');
    final hostTokens = keyTokens[0].split('/');
    if (hostTokens.length < 3) return null;
    if (keyTokens.length < 2) {
      return ParsedRegistryKey(
        actionType: .dynamicActionProvider,
        actionName: hostTokens[2],
      );
    }
    final tokens = keyTokens[1].split('/');
    if (tokens.length < 2) return null;
    return ParsedRegistryKey(
      dynamicActionHost: hostTokens[2],
      actionType: ActionType(tokens[0]),
      actionName: tokens.sublist(1).join('/'),
    );
  }

  final tokens = key.split('/');
  if (tokens.length < 3) return null;
  // ex: /model/googleai/gemini-flash-latest or /prompt/my-plugin/folder/prompt
  if (tokens.length >= 4) {
    return ParsedRegistryKey(
      actionType: ActionType(tokens[1]),
      actionName: tokens.sublist(3).join('/'),
    );
  }
  // ex: /util/generate
  return ParsedRegistryKey(
    actionType: ActionType(tokens[1]),
    actionName: tokens[2],
  );
}

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
    _plugins.add(_ListActionsCachingPluginAdapter(plugin));
  }

  String _getKey(String type, String name) {
    return '/$type/$name';
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
    final key = _getKey(action.actionType.value, action.name);
    _actions[key] = action;
  }

  Future<Action?> lookupAction(ActionType actionType, String name) async {
    final key = _getKey(actionType.value, name);
    if (_actions.containsKey(key)) {
      return _actions[key];
    }
    final separatorIndex = name.indexOf('/');
    if (separatorIndex > 0 && separatorIndex < name.length - 1) {
      final pluginName = name.substring(0, separatorIndex);
      final resolvedActionName = name.substring(separatorIndex + 1);
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
      final key = _getKey(action.actionType.value, action.name);
      allActions[key] = action;
    }

    for (final plugin in _plugins) {
      try {
        final pluginActions = await plugin.list();
        for (final action in pluginActions) {
          final key = _getKey(action.actionType.value, action.name);
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

  /// Resolves an action addressed through a dynamic action provider, given a
  /// [parsedKey] whose `dynamicActionHost` is set. Returns null when the host
  /// is not a registered provider, the name is a wildcard (which addresses
  /// many actions, not one), or the provider cannot resolve it.
  Future<Action?> getDynamicAction(ParsedRegistryKey parsedKey) async {
    final host = parsedKey.dynamicActionHost;
    if (host == null || parsedKey.actionName.contains('*')) return null;
    final dap =
        await lookupAction(.dynamicActionProvider, host)
            as DynamicActionProvider?;
    if (dap == null) return null;
    return dap.getAction(parsedKey.actionType, parsedKey.actionName);
  }

  /// Expands a possibly-wildcard [key] into the concrete keys it addresses.
  ///
  /// A dynamic-action-provider key with a `*` or `prefix*` name expands to one
  /// key per matching action; any other resolvable key returns itself. Mirrors
  /// JS's `resolveActionNames`.
  Future<List<String>> resolveActionNames(String key) async {
    final parsed = parseRegistryKey(key);
    final host = parsed?.dynamicActionHost;
    if (parsed != null && host != null) {
      final dap =
          await lookupAction(.dynamicActionProvider, host)
              as DynamicActionProvider?;
      if (dap == null) return const [];
      final metas = await dap.listActionMetadata(
        parsed.actionType,
        parsed.actionName,
      );
      return metas
          .map(
            (m) =>
                '/dynamic-action-provider/$host:${parsed.actionType.value}/${m.name}',
          )
          .toList();
    }
    return const [];
  }

  /// Returns every action that can be resolved, keyed by registry key, with
  /// dynamic action providers expanded into their individual actions. Used by
  /// the reflection API / Dev UI so DAP-provided tools, prompts, and resources
  /// are individually listable. Mirrors JS's `listResolvableActions`.
  Future<Map<String, ActionMetadata>> listResolvableActions() async {
    final resolvable = <String, ActionMetadata>{};
    for (final action in await listActions()) {
      final key = _getKey(action.actionType.value, action.name);
      resolvable[key] = action;
      if (action is DynamicActionProvider) {
        try {
          resolvable.addAll(await action.getActionMetadataRecord());
        } catch (e, st) {
          print(
            'Error listing actions for Dynamic Action Provider '
            '${action.name}: $e $st',
          );
        }
      }
    }
    return resolvable;
  }
}

String getKey(String actionType, String name) {
  return '/$actionType/$name';
}

// Plugin adapter/wrapper that caches the list actions result.
class _ListActionsCachingPluginAdapter extends GenkitPlugin {
  final GenkitPlugin _plugin;
  Future<List<ActionMetadata>>? _listFuture;

  _ListActionsCachingPluginAdapter(this._plugin);

  @override
  String get name => _plugin.name;

  @override
  List<GenerateMiddlewareDef> middleware() => _plugin.middleware();

  @override
  Future<List<Action>> init() => _plugin.init();

  @override
  Action? resolve(ActionType actionType, String name) =>
      _plugin.resolve(actionType, name);

  @override
  Future<List<ActionMetadata>> list() async {
    if (_listFuture != null) return _listFuture!;
    try {
      return await (_listFuture = _plugin.list());
    } catch (e) {
      // Clear the future so that the next call will retry.
      _listFuture = null;
      rethrow;
    }
  }
}
