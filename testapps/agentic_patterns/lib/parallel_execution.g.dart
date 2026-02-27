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

part of 'parallel_execution.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ProductInput {
  factory ProductInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ProductInput._(this._json);

  ProductInput({required String product}) {
    _json = {'product': product};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ProductInput> $schema =
      _ProductInputTypeFactory();

  String get product {
    return _json['product'] as String;
  }

  set product(String value) {
    _json['product'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ProductInputTypeFactory extends SchemanticType<ProductInput> {
  const _ProductInputTypeFactory();

  @override
  ProductInput parse(Object? json) {
    return ProductInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ProductInput',
    definition: $Schema
        .object(
          properties: {'product': $Schema.string()},
          required: ['product'],
        )
        .value,
    dependencies: [],
  );
}

class MarketingCopy {
  factory MarketingCopy.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  MarketingCopy._(this._json);

  MarketingCopy({required String name, required String tagline}) {
    _json = {'name': name, 'tagline': tagline};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<MarketingCopy> $schema =
      _MarketingCopyTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get tagline {
    return _json['tagline'] as String;
  }

  set tagline(String value) {
    _json['tagline'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _MarketingCopyTypeFactory extends SchemanticType<MarketingCopy> {
  const _MarketingCopyTypeFactory();

  @override
  MarketingCopy parse(Object? json) {
    return MarketingCopy._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'MarketingCopy',
    definition: $Schema
        .object(
          properties: {'name': $Schema.string(), 'tagline': $Schema.string()},
          required: ['name', 'tagline'],
        )
        .value,
    dependencies: [],
  );
}
