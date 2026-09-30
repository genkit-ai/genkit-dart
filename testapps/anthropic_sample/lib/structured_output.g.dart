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

part of 'structured_output.dart';

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
    String? tip,
  }) {
    _json = {
      'title': title,
      'ingredients': ingredients,
      'minutes': minutes,
      'tip': ?tip,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Recipe].
  static const SchemanticType<Recipe> $schema = _RecipeTypeFactory();

  /// Name of the dish
  String get title {
    return _json['title'] as String;
  }

  /// Name of the dish
  set title(String value) {
    _json['title'] = value;
  }

  /// Ingredients with quantities, e.g. "2 eggs"
  List<String> get ingredients {
    return (_json['ingredients'] as List).cast<String>();
  }

  /// Ingredients with quantities, e.g. "2 eggs"
  set ingredients(List<String> value) {
    _json['ingredients'] = value;
  }

  /// Total time in minutes
  int get minutes {
    return _json['minutes'] as int;
  }

  /// Total time in minutes
  set minutes(int value) {
    _json['minutes'] = value;
  }

  /// Optional tip for the cook
  String? get tip {
    return _json['tip'] as String?;
  }

  /// Optional tip for the cook
  set tip(String? value) {
    if (value == null) {
      _json.remove('tip');
    } else {
      _json['tip'] = value;
    }
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
            'tip': $Schema.string(),
          },
          required: ['title', 'ingredients', 'minutes'],
        )
        .value,
    dependencies: [],
  );
}

base class Scorecard {
  /// Creates a [Scorecard] from a JSON map.
  factory Scorecard.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Scorecard._(this._json);

  Scorecard({required String student, required Map<String, int> scores}) {
    _json = {'student': student, 'scores': scores};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Scorecard].
  static const SchemanticType<Scorecard> $schema = _ScorecardTypeFactory();

  String get student {
    return _json['student'] as String;
  }

  set student(String value) {
    _json['student'] = value;
  }

  /// Score per subject. A `Map` field can't be expressed in Anthropic's
  /// schema subset, so the plugin puts this schema in the prompt instead.
  Map<String, int> get scores {
    return (_json['scores'] as Map).cast<String, int>();
  }

  /// Score per subject. A `Map` field can't be expressed in Anthropic's
  /// schema subset, so the plugin puts this schema in the prompt instead.
  set scores(Map<String, int> value) {
    _json['scores'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Scorecard] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _ScorecardTypeFactory extends SchemanticType<Scorecard> {
  const _ScorecardTypeFactory();

  @override
  Scorecard parse(Object? json) {
    return Scorecard._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Scorecard',
    definition: $Schema
        .object(
          properties: {
            'student': $Schema.string(),
            'scores': $Schema.object(additionalProperties: $Schema.integer()),
          },
          required: ['student', 'scores'],
        )
        .value,
    dependencies: [],
  );
}

base class Category {
  /// Creates a [Category] from a JSON map.
  factory Category.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Category._(this._json);

  Category({required String name, List<Category>? subcategories}) {
    _json = {
      'name': name,
      'subcategories': ?subcategories?.map((e) => e.toJson()).toList(),
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Category].
  static const SchemanticType<Category> $schema = _CategoryTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  /// Recursive, so this schema also travels in the prompt.
  List<Category>? get subcategories {
    return (_json['subcategories'] as List?)
        ?.map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Recursive, so this schema also travels in the prompt.
  set subcategories(List<Category>? value) {
    if (value == null) {
      _json.remove('subcategories');
    } else {
      _json['subcategories'] = value.map((e) => e.toJson()).toList();
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Category] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _CategoryTypeFactory extends SchemanticType<Category> {
  const _CategoryTypeFactory();

  @override
  Category parse(Object? json) {
    return Category._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Category',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'subcategories': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Category'}),
            ),
          },
          required: ['name'],
        )
        .value,
    dependencies: [Category.$schema],
  );
}

base class PantryQuery {
  /// Creates a [PantryQuery] from a JSON map.
  factory PantryQuery.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  PantryQuery._(this._json);

  PantryQuery({required String item}) {
    _json = {'item': item};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [PantryQuery].
  static const SchemanticType<PantryQuery> $schema = _PantryQueryTypeFactory();

  String get item {
    return _json['item'] as String;
  }

  set item(String value) {
    _json['item'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [PantryQuery] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _PantryQueryTypeFactory extends SchemanticType<PantryQuery> {
  const _PantryQueryTypeFactory();

  @override
  PantryQuery parse(Object? json) {
    return PantryQuery._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'PantryQuery',
    definition: $Schema
        .object(properties: {'item': $Schema.string()}, required: ['item'])
        .value,
    dependencies: [],
  );
}
