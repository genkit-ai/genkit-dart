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

import 'action.dart';

class DynamicActionProvider<Input, Output, Chunk, Init>
    extends Action<void, Map<String, Object?>, void, void> {
  final FutureOr<Iterable<ActionMetadata>> Function()? listActionsFn;
  final FutureOr<Action?> Function(String)? getActionFn;

  DynamicActionProvider({
    required super.name,
    this.listActionsFn,
    this.getActionFn,
    super.metadata,
  }) : super(
         actionType: 'dynamic-action-provider',
         fn: (input, context) async {
           // TODO: implement when spec is finalized.
           return {};
         },
       );

  Future<List<ActionMetadata>> listActions() async {
    if (listActionsFn == null) return [];
    final actions = await listActionsFn!();
    return actions.toList();
  }

  Future<Action?> getAction(String name) async {
    if (getActionFn != null) {
      return await getActionFn!(name);
    }
    if (listActionsFn != null) {
      final actions = await listActionsFn!();
      return actions.where((action) => action.name == name).firstOrNull
          as Action?;
    }
    return null;
  }
}
