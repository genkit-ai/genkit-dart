# Genkit Dart Library Tests

This directory contains comprehensive tests to ensure the quality of the Genkit Dart library.

## Test Structure

Tests are divided by functionality into the following files:

### Core Test Files

- `client_test.dart` - RemoteAction class core functionality tests
  - HTTP request/response processing
  - Custom header sending
  - Type safety verification
  - Error handling

- **`exception_test.dart` - GenkitException class tests
  - Accurate exception information setting
  - toString() method behavior
  - Exception inheritance relationships

- **`streaming_test.dart` - Dedicated streaming functionality tests
  - Server-Sent Events (SSE) processing
  - Chunk-by-chunk data transformation
  - Stream lifecycle management

### Supporting Files

- `schemas/` - Test data type definitions
  - `my_schemas.dart` - Basic test data types
  - `stream_schemas.dart` - Streaming data types
- `mocks/client_test.mocks.dart` - Mock objects using Mockito
- `test_runner.dart` - Integrated test runner for all tests

## How to Run Tests

### Run All Tests

```bash
# Recommended: Integrated execution of all tests
dart test test/test_runner.dart

# Or standard method
dart test
```

### Run Individual Tests

```bash
# Core functionality tests
dart test test/client_test.dart

# Exception handling tests
dart test test/exception_test.dart

# Streaming functionality tests
dart test test/streaming_test.dart
```

### Run Specific Test Groups

```bash
# RemoteAction core functionality only
dart test test/client_test.dart --name "RemoteAction - Core Functionality"

# Error handling only
dart test test/client_test.dart --name "RemoteAction - Error Handling"

# Streaming core functionality only
dart test test/streaming_test.dart --name "Streaming - Core Functionality"
```

## Test Coverage

### ✅ Covered Functionality

1. HTTP Communication
   - Normal request/response
   - Custom header sending
   - Error status code handling

2. Streaming
   - Server-Sent Events (SSE) parsing
   - Chunk-by-chunk data processing

3. Error Handling
   - Network errors
   - JSON parsing errors
   - Server error responses
   - Type conversion errors

4. Type Safety
   - String ⇔ String conversion
   - Object ⇔ Object conversion
   - Stream chunk type conversion

## Mocks and Test Doubles

The tests use the following mock libraries:

- **Mockito**: HTTP client mocking
- **MockClient**: Test double for `http.Client`