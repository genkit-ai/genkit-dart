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

import '../ai/generate_middleware.dart';
import '../ai/model.dart';
import '../exception.dart';
import 'action.dart';

/// A plugin for Genkit.
///
/// Plugin implementers can extend this class and override the methods to provide
/// actions, models, etc.
abstract class GenkitPlugin {
  String get name;

  /// Middleware provided by the plugin.
  List<GenerateMiddlewareDef> middleware() {
    return [];
  }

  /// Called when the plugin is initialized.
  Future<List<Action>> init() async {
    return [];
  }

  /// Called to resolve an action by name.
  Action? resolve(ActionType actionType, String name) {
    return null;
  }

  /// Called to list actions provided by the plugin.
  Future<List<ActionMetadata>> list() async {
    return [];
  }

  Model<T> model<T>(String name) {
    final m = resolve(ActionType.model, name);
    if (m == null || m is! Model) {
      throw GenkitException(
        'Model $name not found',
        status: StatusCodes.NOT_FOUND,
      );
    }
    return m as Model<T>;
  }
}
