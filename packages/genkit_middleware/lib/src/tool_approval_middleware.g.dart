// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tool_approval_middleware.dart';

// **************************************************************************
// SchemaGenerator
// **************************************************************************

class ToolApprovalOptions {
  factory ToolApprovalOptions.fromJson(Map<String, dynamic> json) =>
      $schema.parse(json);

  ToolApprovalOptions._(this._json);

  ToolApprovalOptions({required List<String> approved}) {
    _json = {'approved': approved};
  }

  late final Map<String, dynamic> _json;

  static const SchemanticType<ToolApprovalOptions> $schema =
      _ToolApprovalOptionsTypeFactory();

  List<String> get approved {
    return (_json['approved'] as List).cast<String>();
  }

  set approved(List<String> value) {
    _json['approved'] = value;
  }

  @override
  String toString() {
    return _json.toString();
  }

  Map<String, dynamic> toJson() {
    return _json;
  }
}

class _ToolApprovalOptionsTypeFactory
    extends SchemanticType<ToolApprovalOptions> {
  const _ToolApprovalOptionsTypeFactory();

  @override
  ToolApprovalOptions parse(Object? json) {
    return ToolApprovalOptions._(json as Map<String, dynamic>);
  }

  @override
  JsonSchemaMetadata get schemaMetadata => JsonSchemaMetadata(
    name: 'ToolApprovalOptions',
    definition: Schema.object(
      properties: {'approved': Schema.list(items: Schema.string())},
      required: ['approved'],
    ),
    dependencies: [],
  );
}
