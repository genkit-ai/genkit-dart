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
