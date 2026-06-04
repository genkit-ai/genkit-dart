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

/// The `build_runner` entry point for the `schemantic` code generator.
///
/// This library exposes the [schemaBuilder] factory referenced by
/// `build.yaml`. It is not intended to be imported directly in application
/// code; instead it is invoked by `build_runner` to generate the `*.g.dart`
/// part files for classes annotated with `@Schema`.
library;

import 'package:build/build.dart';
import 'package:source_gen/source_gen.dart';

import 'src/schema_generator.dart';

/// Creates the [Builder] used by `build_runner` to generate `schemantic`
/// data classes and JSON schemas.
///
/// The builder emits a shared part file (with the `schemantic` extension) for
/// every input library, running the schema generator over each `@Schema`
/// annotated declaration. The [options] are supplied by `build_runner` based
/// on the configuration in `build.yaml`.
Builder schemaBuilder(BuilderOptions options) =>
    SharedPartBuilder([SchemaGenerator()], 'schemantic');
