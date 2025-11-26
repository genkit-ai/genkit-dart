import 'dart:async';

import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/core/action.dart';

/// A plugin for Genkit.
///
/// Plugin implementers can extend this class and override the methods to provide
/// actions, models, etc.
abstract class GenkitPlugin {
  String get name;

  /// Called when the plugin is initialized.
  Future<List<Action>> init() async {
    return [];
  }

  /// Called to resolve an action by name.
  Action? resolve(String actionType, String name) {
    return null;
  }

  /// Called to list actions provided by the plugin.
  Future<List<ActionMetadata>> list() async {
    return [];
  }

  Model model(String name) {
    final m = resolve('model', name);
    if (m == null || m is! Model) {
      throw Exception('Model $name not found');
    }
    return m;
  }
}
