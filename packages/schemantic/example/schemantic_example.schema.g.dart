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

part of 'schemantic_example.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

extension type Address(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory Address.from({
    required String street,
    required String city,
    required String zipCode,
  }) {
    return Address({'street': street, 'city': city, 'zipCode': zipCode});
  }

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

  String get zipCode {
    return _json['zipCode'] as String;
  }

  set zipCode(String value) {
    _json['zipCode'] = value;
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class AddressTypeFactory extends JsonExtensionType<Address> {
  const AddressTypeFactory();

  @override
  Address parse(Object json) {
    return Address(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Address',
    definition: Schema.object(
      properties: {
        'street': Schema.string(),
        'city': Schema.string(),
        'zipCode': Schema.string(),
      },
      required: ['street', 'city', 'zipCode'],
    ),
    dependencies: [],
  );
}

// ignore: constant_identifier_names
const AddressType = AddressTypeFactory();

extension type User(Map<String, dynamic> _json)
    implements Map<String, dynamic> {
  factory User.from({
    required String name,
    int? age,
    required bool isAdmin,
    Address? address,
  }) {
    return User({
      'name': name,
      if (age != null) 'age': age,
      'isAdmin': isAdmin,
      if (address != null) 'address': address.toJson(),
    });
  }

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  int? get age {
    return _json['age'] as int?;
  }

  set age(int? value) {
    if (value == null) {
      _json.remove('age');
    } else {
      _json['age'] = value;
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

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class UserTypeFactory extends JsonExtensionType<User> {
  const UserTypeFactory();

  @override
  User parse(Object json) {
    return User(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'User',
    definition: Schema.object(
      properties: {
        'name': Schema.string(),
        'age': Schema.integer(),
        'isAdmin': Schema.boolean(),
        'address': Schema.fromMap({'\$ref': r'#/$defs/Address'}),
      },
      required: ['name', 'isAdmin'],
    ),
    dependencies: [AddressType],
  );
}

// ignore: constant_identifier_names
const UserType = UserTypeFactory();
