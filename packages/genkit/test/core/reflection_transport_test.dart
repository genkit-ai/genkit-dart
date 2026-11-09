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

/// Which reflection transport each platform and configuration selects.
///
/// The v1 server serves unauthenticated `runAction` on a loopback socket. A
/// `--dart-define` is baked into the binary and cannot be turned off at
/// runtime, so a stray `GENKIT_ENV=dev` in a release build would otherwise ship
/// that socket inside the app, where loopback is shared between installed apps.
library;

import 'package:genkit/src/core/reflection/reflection_io.dart';
import 'package:test/test.dart';

void main() {
  group('reflectionTransportFor', () {
    test('dials out over v2 when a server URL is set', () {
      expect(
        reflectionTransportFor(v2ServerUrl: 'ws://host:4033', isMobile: false),
        ReflectionTransport.v2,
      );
    });

    test('dials out over v2 on mobile when a server URL is set', () {
      expect(
        reflectionTransportFor(v2ServerUrl: 'ws://host:4033', isMobile: true),
        ReflectionTransport.v2,
      );
    });

    test('falls back to the loopback server off mobile', () {
      expect(
        reflectionTransportFor(v2ServerUrl: null, isMobile: false),
        ReflectionTransport.v1,
      );
    });

    test('starts nothing on mobile without a server URL', () {
      expect(
        reflectionTransportFor(v2ServerUrl: null, isMobile: true),
        ReflectionTransport.none,
      );
    });
  });
}
