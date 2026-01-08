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
