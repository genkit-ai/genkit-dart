// Copyright 2024 Google LLC
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

/// Test runner
///
/// This file imports and runs all test files.
/// Run all tests with `dart test test/test_runner.dart` command.
library;

import 'client_test.dart' as client_test;
import 'exception_test.dart' as exception_test;
import 'streaming_test.dart' as streaming_test;

void main() {
  print('🧪 Running all tests for Genkit Dart library...\n');

  print('📋 Test list:');
  print(
    '  - client_test.dart: RemoteAction core functionality and error handling',
  );
  print('  - exception_test.dart: GenkitException exception handling');
  print('  - streaming_test.dart: Comprehensive streaming functionality tests');
  print('');

  // Run each test
  client_test.main();
  exception_test.main();
  streaming_test.main();

  print('✅ All tests completed!');
}
