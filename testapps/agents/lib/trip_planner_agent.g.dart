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

part of 'trip_planner_agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GetAttractionsInput {
  /// Creates a [GetAttractionsInput] from a JSON map.
  factory GetAttractionsInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetAttractionsInput._(this._json);

  GetAttractionsInput({required String city}) {
    _json = {'city': city};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetAttractionsInput].
  static const SchemanticType<GetAttractionsInput> $schema =
      _GetAttractionsInputTypeFactory();

  String get city {
    return _json['city'] as String;
  }

  set city(String value) {
    _json['city'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetAttractionsInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetAttractionsInputTypeFactory
    extends SchemanticType<GetAttractionsInput> {
  const _GetAttractionsInputTypeFactory();

  @override
  GetAttractionsInput parse(Object? json) {
    return GetAttractionsInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetAttractionsInput',
    definition: $Schema
        .object(properties: {'city': $Schema.string()}, required: ['city'])
        .value,
    dependencies: [],
  );
}

base class Attraction {
  /// Creates a [Attraction] from a JSON map.
  factory Attraction.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Attraction._(this._json);

  Attraction({required String name, required String description}) {
    _json = {'name': name, 'description': description};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Attraction].
  static const SchemanticType<Attraction> $schema = _AttractionTypeFactory();

  String get name {
    return _json['name'] as String;
  }

  set name(String value) {
    _json['name'] = value;
  }

  String get description {
    return _json['description'] as String;
  }

  set description(String value) {
    _json['description'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Attraction] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _AttractionTypeFactory extends SchemanticType<Attraction> {
  const _AttractionTypeFactory();

  @override
  Attraction parse(Object? json) {
    return Attraction._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Attraction',
    definition: $Schema
        .object(
          properties: {
            'name': $Schema.string(),
            'description': $Schema.string(),
          },
          required: ['name', 'description'],
        )
        .value,
    dependencies: [],
  );
}

base class GetAttractionsOutput {
  /// Creates a [GetAttractionsOutput] from a JSON map.
  factory GetAttractionsOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetAttractionsOutput._(this._json);

  GetAttractionsOutput({required List<Attraction> attractions}) {
    _json = {'attractions': attractions.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetAttractionsOutput].
  static const SchemanticType<GetAttractionsOutput> $schema =
      _GetAttractionsOutputTypeFactory();

  List<Attraction> get attractions {
    return (_json['attractions'] as List)
        .map((e) => Attraction.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set attractions(List<Attraction> value) {
    _json['attractions'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetAttractionsOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetAttractionsOutputTypeFactory
    extends SchemanticType<GetAttractionsOutput> {
  const _GetAttractionsOutputTypeFactory();

  @override
  GetAttractionsOutput parse(Object? json) {
    return GetAttractionsOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetAttractionsOutput',
    definition: $Schema
        .object(
          properties: {
            'attractions': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Attraction'}),
            ),
          },
          required: ['attractions'],
        )
        .value,
    dependencies: [Attraction.$schema],
  );
}

base class GetFlightInfoInput {
  /// Creates a [GetFlightInfoInput] from a JSON map.
  factory GetFlightInfoInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetFlightInfoInput._(this._json);

  GetFlightInfoInput({required String from, required String to, String? date}) {
    _json = {'from': from, 'to': to, 'date': ?date};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetFlightInfoInput].
  static const SchemanticType<GetFlightInfoInput> $schema =
      _GetFlightInfoInputTypeFactory();

  String get from {
    return _json['from'] as String;
  }

  set from(String value) {
    _json['from'] = value;
  }

  String get to {
    return _json['to'] as String;
  }

  set to(String value) {
    _json['to'] = value;
  }

  String? get date {
    return _json['date'] as String?;
  }

  set date(String? value) {
    if (value == null) {
      _json.remove('date');
    } else {
      _json['date'] = value;
    }
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetFlightInfoInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetFlightInfoInputTypeFactory
    extends SchemanticType<GetFlightInfoInput> {
  const _GetFlightInfoInputTypeFactory();

  @override
  GetFlightInfoInput parse(Object? json) {
    return GetFlightInfoInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetFlightInfoInput',
    definition: $Schema
        .object(
          properties: {
            'from': $Schema.string(),
            'to': $Schema.string(),
            'date': $Schema.string(),
          },
          required: ['from', 'to'],
        )
        .value,
    dependencies: [],
  );
}

base class Flight {
  /// Creates a [Flight] from a JSON map.
  factory Flight.fromJson(Map<String, dynamic> json) => $schema.parse(json);

  Flight._(this._json);

  Flight({
    required String airline,
    required String departure,
    required String arrival,
    required String price,
  }) {
    _json = {
      'airline': airline,
      'departure': departure,
      'arrival': arrival,
      'price': price,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [Flight].
  static const SchemanticType<Flight> $schema = _FlightTypeFactory();

  String get airline {
    return _json['airline'] as String;
  }

  set airline(String value) {
    _json['airline'] = value;
  }

  String get departure {
    return _json['departure'] as String;
  }

  set departure(String value) {
    _json['departure'] = value;
  }

  String get arrival {
    return _json['arrival'] as String;
  }

  set arrival(String value) {
    _json['arrival'] = value;
  }

  String get price {
    return _json['price'] as String;
  }

  set price(String value) {
    _json['price'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [Flight] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _FlightTypeFactory extends SchemanticType<Flight> {
  const _FlightTypeFactory();

  @override
  Flight parse(Object? json) {
    return Flight._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'Flight',
    definition: $Schema
        .object(
          properties: {
            'airline': $Schema.string(),
            'departure': $Schema.string(),
            'arrival': $Schema.string(),
            'price': $Schema.string(),
          },
          required: ['airline', 'departure', 'arrival', 'price'],
        )
        .value,
    dependencies: [],
  );
}

base class GetFlightInfoOutput {
  /// Creates a [GetFlightInfoOutput] from a JSON map.
  factory GetFlightInfoOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetFlightInfoOutput._(this._json);

  GetFlightInfoOutput({required List<Flight> flights}) {
    _json = {'flights': flights.map((e) => e.toJson()).toList()};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetFlightInfoOutput].
  static const SchemanticType<GetFlightInfoOutput> $schema =
      _GetFlightInfoOutputTypeFactory();

  List<Flight> get flights {
    return (_json['flights'] as List)
        .map((e) => Flight.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  set flights(List<Flight> value) {
    _json['flights'] = value.toList();
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetFlightInfoOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetFlightInfoOutputTypeFactory
    extends SchemanticType<GetFlightInfoOutput> {
  const _GetFlightInfoOutputTypeFactory();

  @override
  GetFlightInfoOutput parse(Object? json) {
    return GetFlightInfoOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetFlightInfoOutput',
    definition: $Schema
        .object(
          properties: {
            'flights': $Schema.list(
              items: $Schema.fromMap({'\$ref': r'#/$defs/Flight'}),
            ),
          },
          required: ['flights'],
        )
        .value,
    dependencies: [Flight.$schema],
  );
}
