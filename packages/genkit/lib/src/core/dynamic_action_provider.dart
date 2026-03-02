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

import 'action.dart';

class DynamicActionProvider<Input, Output, Chunk, Init>
    extends Action<void, Map<String, Object?>, void, void> {
  final List<Action> Function() listActionsFn;

  DynamicActionProvider({
    required super.name,
    required this.listActionsFn,
    super.metadata,
  }) : super(
         actionType: 'dynamic-action-provider',
         fn: (input, context) async {
           // TODO: implement when spec is finalized.
           return {};
         },
       );

  List<ActionMetadata> listActions() {
    return listActionsFn().toList();
  }

  Action? getAction(String name) {
    return listActionsFn().where((action) => action.name == name).firstOrNull;
  }
}
