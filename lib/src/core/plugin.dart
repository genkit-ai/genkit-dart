import 'dart:async';

import 'package:genkit/src/core/action.dart';

typedef ResolvableAction = ({
  Action? action,
  // TODO: add when BackgroundAction implemented
  // BackgroundAction? backgroundAction
});

/// A plugin for Genkit.
///
/// Plugin implementers can extend this class and override the methods to provide
/// actions, models, etc.
abstract class GenkitPlugin {
  String get name;

  /// Called when the plugin is initialized.
  Future<List<ResolvableAction>> init() async {
    return [];
  }

  /// Called to resolve an action by name.
  Future<ResolvableAction?> resolve(String actionType, String name) async {
    return null;
  }

  /// Called to list actions provided by the plugin.
  Future<List<ActionMetadata>> list() async {
    return [];
  }
}
