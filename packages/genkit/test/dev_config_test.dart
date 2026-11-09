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

/// The precedence every dev-mode setting shares. Which compile-time key each
/// setting is wired to is a separate question, covered by
/// `dev_config_dart_define_test.dart`.
library;

import 'package:genkit/src/dev_config.dart';
import 'package:test/test.dart';

void main() {
  group('resolveDevConfig', () {
    test('takes the environment value when the define is unset', () {
      expect(resolveDevConfig('from-env', ''), 'from-env');
    });

    test('takes the environment value over the define', () {
      expect(resolveDevConfig('from-env', 'from-define'), 'from-env');
    });

    test('falls back to the define when the environment is unset', () {
      expect(resolveDevConfig(null, 'from-define'), 'from-define');
    });

    test('falls back to the define when the environment value is empty', () {
      expect(resolveDevConfig('', 'from-define'), 'from-define');
    });

    test('is null when the environment is unset and the define is empty', () {
      expect(resolveDevConfig(null, ''), isNull);
    });

    test('is null when both values are empty', () {
      expect(resolveDevConfig('', ''), isNull);
    });
  });
}
