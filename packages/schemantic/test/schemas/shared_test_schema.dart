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

import 'package:schemantic/schemantic.dart';

part 'shared_test_schema.g.dart';

@Schematic()
abstract class $SharedChild {
  String get childId;
}

@Schematic()
abstract class $PartSchema {}

@Schematic()
abstract class $TextPartSchema implements $PartSchema {
  String get text;
  Map<String, dynamic>? get data;
  Map<String, dynamic>? get metadata;
  Map<String, dynamic>? get custom;
}
