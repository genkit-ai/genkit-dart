// Copyright 2026 Google LLC
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

import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:test/test.dart';

import 'wire_harness.dart';

/// Which API surface a request goes to, and the header that says so.

void main() {
  group('api version on the wire', () {
    test('stable is the default and sends no beta header', () async {
      await requestOnTheWire(model: 'claude-sonnet-5');
      expect(lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('request apiVersion beta sends the curated list', () async {
      await requestOnTheWire(model: 'claude-sonnet-5', apiVersion: 'beta');
      expect(lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('plugin-level beta applies when the request is silent', () async {
      await requestOnTheWire(
        model: 'claude-sonnet-5',
        pluginApiVersion: 'beta',
      );
      expect(lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('request stable overrides a beta plugin default', () async {
      await requestOnTheWire(
        model: 'claude-sonnet-5',
        pluginApiVersion: 'beta',
        apiVersion: 'stable',
      );
      expect(lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('a supplied betas list replaces the default', () async {
      await requestOnTheWire(
        model: 'claude-sonnet-5',
        apiVersion: 'beta',
        betas: ['my-beta-2026-01-01'],
      );
      expect(lastHeaders['anthropic-beta'], 'my-beta-2026-01-01');
    });

    test('betas are ignored on the stable surface', () async {
      await requestOnTheWire(
        model: 'claude-sonnet-5',
        betas: ['my-beta-2026-01-01'],
      );
      expect(lastHeaders, isNot(contains('anthropic-beta')));
    });

    test('the streaming path sends the beta header too', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-5',
        apiVersion: 'beta',
        streaming: true,
      );
      expect(body['stream'], true);
      expect(lastHeaders['anthropic-beta'], defaultAnthropicBetas.join(','));
    });

    test('the streaming path stays stable by default', () async {
      await requestOnTheWire(model: 'claude-sonnet-5', streaming: true);
      expect(lastHeaders, isNot(contains('anthropic-beta')));
    });
  });
}
