// Copyright 2026 Google LLC
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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'simulated_output.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class Recipe {
  /// Creates a [Recipe] from a JSON map.
  factory Recipe.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Recipe._(this._json);

  Recipe({
    required String title,
    required List<String> ingredients,
    required int minutes,
  }) {
    _json = {'title': title, 'ingredients': ingredients, 'minutes': minutes};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Recipe].
  static const SchemanticType<Recipe> $schema = _RecipeTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  List<String> get ingredients {
    return (_json['ingredients'] as List).cast<String>();
  }

  set ingredients(List<String> value) {
    _json['ingredients'] = value;
  }

  int get minutes {
    return _json['minutes'] as int;
  }

  set minutes(int value) {
    _json['minutes'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Recipe] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _RecipeTypeFactory extends SchemanticType<Recipe> {
  const _RecipeTypeFactory();

  @override
  Recipe parse(Object? json) {
    return Recipe._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Recipe',
    definition: $Schema
        .object(
          properties: {
            'title': $Schema.string(),
            'ingredients': $Schema.list(items: $Schema.string()),
            'minutes': $Schema.integer(),
          },
          required: ['title', 'ingredients', 'minutes'],
        )
        .value,
    dependencies: [],
  );
}
