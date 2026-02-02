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

part 'model.g.dart';

@Schematic()
abstract class $WeatherToolInput {
  @Field(
    description:
        'The location (ex. city, state, country) to get the weather for',
  )
  String get location;
}

// --- Schemas for Structured Streaming Example ---

@Schematic()
abstract class $Category {
  String get name;
  @Schematic(
    description: 'make sure there are at least 2-3 levels of subcategories',
  )
  List<$Category>? get subcategories;
}

@Schematic()
abstract class $Weapon {
  String get name;
  double get damage;
  $Category get category;
}

@Schematic()
abstract class $RpgCharacter {
  @Schematic(description: 'name of the character')
  String get name;

  @Schematic(description: "character's backstory, about a paragraph")
  String get backstory;

  List<$Weapon> get weapons;

  @StringField(enumValues: ['RANGER', 'WIZZARD', 'TANK', 'HEALER', 'ENGINEER'])
  String get classType;

  String? get affiliation;
}

@Schematic()
abstract class $CharacterProfile {
  String get name;
  String get bio;
  int get age;
}
