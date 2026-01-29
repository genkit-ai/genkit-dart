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
//
// GENERATED CODE BY schemantic - DO NOT MODIFY BY HAND
// To regenerate, run `dart run build_runner build -d`

part of 'schemantic_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class Address {
  factory Address.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Address(this._json);

  factory Address.from({
    required String street,
    required String city,
    required ZipCode zipCode,
  }) {
    return Address({'street': street, 'city': city, 'zipCode': zipCode.value});
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Address> $schema = _AddressTypeFactory();

  String get street {
    return _json['street'] as String;
  }

  set street(String value) {
    _json['street'] = value;
  }

  String get city {
    return _json['city'] as String;
  }

  set city(String value) {
    _json['city'] = value;
  }

  set zipCodeAsInt(int value) {
    _json['zipCode'] = value;
  }

  set zipCodeAsString(String value) {
    _json['zipCode'] = value;
  }

  // Possible return values are `int`, `String`
  Object? get zipCode {
    return _json['zipCode'] as Object?;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class ZipCode {
  ZipCode.int(int this.value);

  ZipCode.string(String this.value);

  final Object? value;
}

class _AddressTypeFactory extends SchemanticType<Address> {
  const _AddressTypeFactory();

  @override
  Address parse(Object? json) {
    return Address(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Address',
    definition: Schema.object(
      properties: {
        'street': Schema.string(),
        'city': Schema.string(),
        'zipCode': Schema.combined(anyOf: [Schema.integer(), Schema.string()]),
      },
      required: ['street', 'city', 'zipCode'],
    ),
    dependencies: [],
  );
}

class User {
  factory User.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  User(this._json);

  factory User.from({
    required String name,
    int? age,
    required bool isAdmin,
    Address? address,
  }) {
    return User({
      'name': name,
      if (age != null) 'years_old': age,
      'isAdmin': isAdmin,
      if (address != null) 'address': address.toJson(),
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<User> $schema = _UserTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  int? get age {
    return _json['years_old'] as int?;
  }

  set age(int? value) {
    if (value == null) {
      _json.remove('years_old');
    } else {
      _json['years_old'] = value;
    }
  }

  bool get isAdmin {
    return _json['isAdmin'] as bool;
  }

  set isAdmin(bool value) {
    _json['isAdmin'] = value;
  }

  Address? get address {
    return _json['address'] == null
        ? null
        : Address(_json['address'] as Map<String, dynamic>);
  }

  set address(Address? value) {
    if (value == null) {
      _json.remove('address');
    } else {
      _json['address'] = value;
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

class _UserTypeFactory extends SchemanticType<User> {
  const _UserTypeFactory();

  @override
  User parse(Object? json) {
    return User(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'User',
    definition: Schema.object(
      properties: {
        'name': Schema.string(
          minLength: 1,
          maxLength: 150,
          pattern: r'^[a-zA-Z\s]+$',
        ),
        'years_old': Schema.integer(
          description: 'Age of the user',
          minimum: 0,
          maximum: 200,
        ),
        'isAdmin': Schema.boolean(description: 'Is this user an admin?'),
        'address': Schema.fromMap({'\$ref': r'#/$defs/Address'}),
      },
      required: ['name', 'isAdmin'],
    ),
    dependencies: [Address.$schema],
  );
}

class Product {
  factory Product.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Product(this._json);

  factory Product.from({
    required String id,
    required String name,
    required double price,
    List<String>? tags,
  }) {
    return Product({
      'id': id,
      'name': name,
      'price': price,
      if (tags != null) 'tags': tags,
    });
  }

  Map<String, dynamic> _json;

  static const SchemanticType<Product> $schema = _ProductTypeFactory();

  String get id {
    return _json['id'] as String;
  }

  set id(String value) {
    _json['id'] = value;
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  double get price {
    return _json['price'] as double;
  }

  set price(double value) {
    _json['price'] = value;
  }

  List<String>? get tags {
    return (_json['tags'] as List?)?.cast<String>();
  }

  set tags(List<String>? value) {
    if (value == null) {
      _json.remove('tags');
    } else {
      _json['tags'] = value;
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

class _ProductTypeFactory extends SchemanticType<Product> {
  const _ProductTypeFactory();

  @override
  Product parse(Object? json) {
    return Product(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Product',
    definition: Schema.object(
      properties: {
        'id': Schema.string(),
        'name': Schema.string(),
        'price': Schema.number(),
        'tags': Schema.list(items: Schema.string()),
      },
      required: ['id', 'name', 'price'],
    ),
    dependencies: [],
  );
}
