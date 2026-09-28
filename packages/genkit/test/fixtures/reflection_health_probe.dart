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

/// Probe app for `reflection_v1_runtime_id_test.dart`.
///
/// It starts the reflection server the way the library does, under whatever
/// `GENKIT_*` environment the test gives it, reports where the server is
/// listening and where it wrote its runtime file, then stops once the test
/// closes its stdin.
library;

import 'dart:convert';
import 'dart:io';

import 'package:genkit/src/core/reflection.dart';
import 'package:genkit/src/core/registry.dart';
import 'package:path/path.dart' as p;

Future<void> main() async {
  final handle = startReflectionServer(Registry(), port: 0);
  final runtimeFile = await _awaitRuntimeFile();
  final runtime =
      jsonDecode(await runtimeFile.readAsString()) as Map<String, dynamic>;
  final port = Uri.parse(runtime['reflectionServerUrl'] as String).port;
  stdout.writeln(
    'probe-ready ${jsonEncode({'pid': pid, 'port': port, 'runtimeFile': runtimeFile.path})}',
  );

  await stdin.drain<void>().timeout(
    const Duration(seconds: 60),
    onTimeout: () {},
  );
  await handle.stop();
}

/// Polls for the runtime file, which the server writes once it is listening.
Future<File> _awaitRuntimeFile() async {
  final runtimesDir = Directory(
    p.join(Directory.current.path, '.genkit', 'runtimes'),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (DateTime.now().isBefore(deadline)) {
    if (await runtimesDir.exists()) {
      final files = (await runtimesDir.list().toList()).whereType<File>();
      if (files.length == 1 && (await files.single.readAsString()).isNotEmpty) {
        return files.single;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
  throw StateError('runtime file was not written under ${runtimesDir.path}');
}
