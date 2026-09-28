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

/// How reflection settings resolve into a configuration.
library;

import 'package:genkit/src/core/reflection/reflection_config.dart';
import 'package:test/test.dart';

/// Wildcard bind address, as test data rather than an actual bind.
const allInterfaces = '0.0.0.0';

void main() {
  group('resolveReflectionConfig', () {
    test('is off when nothing is set', () {
      expect(resolveReflectionConfig(), isA<ReflectionOff>());
      expect(resolveReflectionConfig().enabled, isFalse);
    });

    test('dev probes from 3100 on loopback', () {
      final config = resolveReflectionConfig(env: 'dev') as ReflectionV1Config;
      expect(config.host, defaultReflectionHost);
      expect(config.port, defaultReflectionPort);
      expect(config.pinned, isFalse);
    });

    test('enabled=true turns it on outside dev', () {
      final config =
          resolveReflectionConfig(enabled: 'true') as ReflectionV1Config;
      expect(config.host, defaultReflectionHost);
      expect(config.port, defaultReflectionPort);
    });

    test('enabled=false is a kill switch, even under dev', () {
      final config = resolveReflectionConfig(
        enabled: 'false',
        env: 'dev',
        port: '3100',
        v2ServerUrl: 'ws://127.0.0.1:3200',
      );
      expect(config, isA<ReflectionDisabled>());
      expect(config.enabled, isFalse);
    });

    test('an empty enabled value counts as unset', () {
      expect(resolveReflectionConfig(enabled: ''), isA<ReflectionOff>());
      expect(
        resolveReflectionConfig(enabled: '', env: 'dev'),
        isA<ReflectionV1Config>(),
      );
    });

    test('any other enabled value throws', () {
      for (final value in ['1', 'yes', 'on', 'TRUE', 'False']) {
        expect(
          () => resolveReflectionConfig(enabled: value, env: 'dev'),
          throwsA(isA<ReflectionConfigException>()),
          reason: value,
        );
      }
    });

    test('host and port do not turn it on', () {
      expect(
        resolveReflectionConfig(host: allInterfaces, port: '3100'),
        isA<ReflectionOff>(),
      );
    });

    test('a bad env port is ignored while off', () {
      expect(resolveReflectionConfig(port: 'abc'), isA<ReflectionOff>());
      expect(
        resolveReflectionConfig(enabled: 'false', port: 'abc'),
        isA<ReflectionDisabled>(),
      );
    });

    test('a bad programmatic port throws even while off', () {
      expect(
        () => resolveReflectionConfig(optionPort: 70000),
        throwsA(isA<ReflectionConfigException>()),
      );
    });

    test('v2 beats a configured v1 port', () {
      final config = resolveReflectionConfig(
        enabled: 'true',
        v2ServerUrl: 'ws://127.0.0.1:3200',
        port: '3100',
        secret: 's3cret',
      );
      expect(config, isA<ReflectionV2Config>());
      final v2 = config as ReflectionV2Config;
      expect(v2.url, 'ws://127.0.0.1:3200');
      expect(v2.secret, 's3cret');
    });

    test('host is used as given', () {
      final config =
          resolveReflectionConfig(enabled: 'true', host: allInterfaces)
              as ReflectionV1Config;
      expect(config.host, allInterfaces);
      expect(config.pinned, isFalse);
    });

    test('an env port is pinned', () {
      final config =
          resolveReflectionConfig(enabled: 'true', port: '4200')
              as ReflectionV1Config;
      expect(config.port, 4200);
      expect(config.pinned, isTrue);
    });

    test('env port 0 is valid and pinned', () {
      final config =
          resolveReflectionConfig(env: 'dev', port: '0') as ReflectionV1Config;
      expect(config.port, 0);
      expect(config.pinned, isTrue);
    });

    test('the environment beats the programmatic port', () {
      final config =
          resolveReflectionConfig(env: 'dev', port: '4200', optionPort: 9999)
              as ReflectionV1Config;
      expect(config.port, 4200);
      expect(config.pinned, isTrue);
    });

    test('an invalid env port throws rather than falling back', () {
      for (final value in [
        'abc',
        '-1',
        '70000',
        '3100.5',
        ' 3100',
        '+7',
        '0x10',
        '1e3',
        '1_000',
      ]) {
        expect(
          () => resolveReflectionConfig(env: 'dev', port: value),
          throwsA(isA<ReflectionConfigException>()),
          reason: value,
        );
      }
    });

    test('an empty secret counts as unset', () {
      final config =
          resolveReflectionConfig(env: 'dev', secret: '') as ReflectionV1Config;
      expect(config.secret, isNull);
    });
  });

  group('programmatic port', () {
    ReflectionV1Config withOption(int? optionPort) =>
        resolveReflectionConfig(env: 'dev', optionPort: optionPort)
            as ReflectionV1Config;

    test('null and 0 mean unset: probe from 3100', () {
      for (final value in [null, 0]) {
        final config = withOption(value);
        expect(config.port, defaultReflectionPort, reason: '$value');
        expect(config.pinned, isFalse, reason: '$value');
      }
    });

    test('a set port is exact', () {
      final config = withOption(9999);
      expect(config.port, 9999);
      expect(config.pinned, isTrue);
    });

    test('reflectionPortAuto lets the OS pick', () {
      final config = withOption(reflectionPortAuto);
      expect(config.port, 0);
      expect(config.pinned, isTrue);
    });

    test('out-of-range values throw', () {
      for (final value in [-2, 65536, 70000]) {
        expect(
          () => withOption(value),
          throwsA(isA<ReflectionConfigException>()),
          reason: '$value',
        );
      }
    });
  });

  group('resolveReflectionServerConfig', () {
    test('applies env settings with no on/off decision', () {
      final config =
          resolveReflectionServerConfig(host: allInterfaces, port: '4200')
              as ReflectionV1Config;
      expect(config.host, allInterfaces);
      expect(config.port, 4200);
      expect(config.pinned, isTrue);
    });

    test('prefers v2 when a URL is set', () {
      expect(
        resolveReflectionServerConfig(v2ServerUrl: 'ws://127.0.0.1:3200'),
        isA<ReflectionV2Config>(),
      );
    });
  });

  group('advertisedReflectionHost', () {
    test('advertises wildcard binds as loopback', () {
      for (final host in [allInterfaces, '::', '[::]']) {
        expect(advertisedReflectionHost(host), '127.0.0.1', reason: host);
      }
    });

    test('keeps a specific host and brackets IPv6', () {
      expect(advertisedReflectionHost('127.0.0.1'), '127.0.0.1');
      expect(advertisedReflectionHost('10.0.0.5'), '10.0.0.5');
      expect(advertisedReflectionHost('::1'), '[::1]');
      expect(advertisedReflectionHost('[::1]'), '[::1]');
    });
  });

  group('isLoopbackHost', () {
    test('recognizes loopback addresses', () {
      for (final host in ['127.0.0.1', '127.1.2.3', 'localhost', '::1']) {
        expect(isLoopbackHost(host), isTrue, reason: host);
      }
    });

    test('rejects routable addresses', () {
      for (final host in [allInterfaces, '192.168.1.5', 'example.com']) {
        expect(isLoopbackHost(host), isFalse, reason: host);
      }
    });
  });

  group('secretsEqual', () {
    test('compares by value, including different lengths', () {
      expect(secretsEqual('abc', 'abc'), isTrue);
      expect(secretsEqual('abc', 'abd'), isFalse);
      expect(secretsEqual('abc', 'much-longer-secret'), isFalse);
      expect(secretsEqual('', ''), isTrue);
      expect(secretsEqual('abc', ''), isFalse);
    });
  });
}
