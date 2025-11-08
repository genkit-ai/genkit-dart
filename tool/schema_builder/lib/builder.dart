import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';
import 'package:schema_builder/src/schema_generator.dart';

Builder schemaBuilder(BuilderOptions options) {
  return PartBuilder([SchemaGenerator()], '.schema.g.dart');
}
