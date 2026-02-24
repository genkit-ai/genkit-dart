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

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

part of 'structured_output.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class MovieReviewInput {
  factory MovieReviewInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MovieReviewInput._(this._json);

  MovieReviewInput({required String title, int? year}) {
    _json = {'title': title, 'year': ?year};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MovieReviewInput> $schema =
      _MovieReviewInputTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  int? get year {
    return _json['year'] as int?;
  }

  set year(int? value) {
    if (value == null) {
      _json.remove('year');
    } else {
      _json['year'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MovieReviewInputTypeFactory extends SchemanticType<MovieReviewInput> {
  const _MovieReviewInputTypeFactory();

  @override
  MovieReviewInput parse(Object? json) {
    return MovieReviewInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MovieReviewInput',
    definition: Schema.object(
      properties: {'title': Schema.string(), 'year': Schema.integer()},
      required: ['title'],
    ),
    dependencies: [],
  );
}

class MovieReview {
  factory MovieReview.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MovieReview._(this._json);

  MovieReview({
    required String title,
    required double rating,
    required String summary,
    required List<String> pros,
    required List<String> cons,
    required String recommendedFor,
  }) {
    _json = {
      'title': title,
      'rating': rating,
      'summary': summary,
      'pros': pros,
      'cons': cons,
      'recommendedFor': recommendedFor,
    };
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MovieReview> $schema = _MovieReviewTypeFactory();

  String get title {
    return _json['title'] as String;
  }

  set title(String value) {
    _json['title'] = value;
  }

  double get rating {
    return (_json['rating'] as num).toDouble();
  }

  set rating(double value) {
    _json['rating'] = value;
  }

  String get summary {
    return _json['summary'] as String;
  }

  set summary(String value) {
    _json['summary'] = value;
  }

  List<String> get pros {
    return (_json['pros'] as List).cast<String>();
  }

  set pros(List<String> value) {
    _json['pros'] = value;
  }

  List<String> get cons {
    return (_json['cons'] as List).cast<String>();
  }

  set cons(List<String> value) {
    _json['cons'] = value;
  }

  String get recommendedFor {
    return _json['recommendedFor'] as String;
  }

  set recommendedFor(String value) {
    _json['recommendedFor'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MovieReviewTypeFactory extends SchemanticType<MovieReview> {
  const _MovieReviewTypeFactory();

  @override
  MovieReview parse(Object? json) {
    return MovieReview._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MovieReview',
    definition: Schema.object(
      properties: {
        'title': Schema.string(),
        'rating': Schema.number(),
        'summary': Schema.string(),
        'pros': Schema.list(items: Schema.string()),
        'cons': Schema.list(items: Schema.string()),
        'recommendedFor': Schema.string(),
      },
      required: [
        'title',
        'rating',
        'summary',
        'pros',
        'cons',
        'recommendedFor',
      ],
    ),
    dependencies: [],
  );
}
