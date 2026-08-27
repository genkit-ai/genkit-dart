// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'agent.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

base class GetWeatherInput {
  /// Creates a [GetWeatherInput] from a JSON map.
  factory GetWeatherInput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetWeatherInput._(this._json);

  GetWeatherInput({required String city}) {
    _json = {'city': city};
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetWeatherInput].
  static const SchemanticType<GetWeatherInput> $schema =
      _GetWeatherInputTypeFactory();

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

  /// Serializes this [GetWeatherInput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetWeatherInputTypeFactory extends SchemanticType<GetWeatherInput> {
  const _GetWeatherInputTypeFactory();

  @override
  GetWeatherInput parse(Object? json) {
    return GetWeatherInput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetWeatherInput',
    definition: $Schema
        .object(
          properties: {
            'city': $Schema.string(
              description: 'The city to get the weather for.',
            ),
          },
          required: ['city'],
        )
        .value,
    dependencies: [],
  );
}

base class GetWeatherOutput {
  /// Creates a [GetWeatherOutput] from a JSON map.
  factory GetWeatherOutput.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  GetWeatherOutput._(this._json);

  GetWeatherOutput({
    required String city,
    required double tempC,
    required String condition,
    required int humidity,
  }) {
    _json = {
      'city': city,
      'tempC': tempC,
      'condition': condition,
      'humidity': humidity,
    };
  }

  late final Map<String, dynamic> _json;

  /// The JSON schema and type descriptor for [GetWeatherOutput].
  static const SchemanticType<GetWeatherOutput> $schema =
      _GetWeatherOutputTypeFactory();

  String get city {
    return _json['city'] as String;
  }

  set city(String value) {
    _json['city'] = value;
  }

  double get tempC {
    return (_json['tempC'] as num).toDouble();
  }

  set tempC(double value) {
    _json['tempC'] = value;
  }

  String get condition {
    return _json['condition'] as String;
  }

  set condition(String value) {
    _json['condition'] = value;
  }

  int get humidity {
    return _json['humidity'] as int;
  }

  set humidity(int value) {
    _json['humidity'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  /// Serializes this [GetWeatherOutput] to a JSON map.
  Map<String, dynamic> toJson() {
    return _json;
  }
}

base class _GetWeatherOutputTypeFactory
    extends SchemanticType<GetWeatherOutput> {
  const _GetWeatherOutputTypeFactory();

  @override
  GetWeatherOutput parse(Object? json) {
    return GetWeatherOutput._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'GetWeatherOutput',
    definition: $Schema
        .object(
          properties: {
            'city': $Schema.string(),
            'tempC': $Schema.number(),
            'condition': $Schema.string(),
            'humidity': $Schema.integer(),
          },
          required: ['city', 'tempC', 'condition', 'humidity'],
        )
        .value,
    dependencies: [],
  );
}
