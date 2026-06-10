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

import 'package:genkit/src/ai/agents/json_patch.dart';
import 'package:test/test.dart';

/// Asserts that applying `diff(a, b)` to `a` yields `b`.
void assertRoundTrip(Object? a, Object? b) {
  final patch = diff(a, b);
  expect(applyPatch(a, patch), b);
}

void main() {
  group('json-patch', () {
    group('diff', () {
      test('returns an empty patch for equal values', () {
        expect(
          diff({'a': 1}, {'a': 1}),
          <Map<String, dynamic>>[],
        );
        expect(
          diff([1, 2], [1, 2]),
          <Map<String, dynamic>>[],
        );
        expect(diff('x', 'x'), <Map<String, dynamic>>[]);
      });

      test('replaces a changed primitive member', () {
        expect(
          diff({'a': 1}, {'a': 2}),
          [
            {'op': 'replace', 'path': '/a', 'value': 2},
          ],
        );
      });

      test('adds a new member', () {
        expect(
          diff({'a': 1}, {'a': 1, 'b': 2}),
          [
            {'op': 'add', 'path': '/b', 'value': 2},
          ],
        );
      });

      test('removes a deleted member', () {
        expect(
          diff({'a': 1, 'b': 2}, {'a': 1}),
          [
            {'op': 'remove', 'path': '/b'},
          ],
        );
      });

      test('diffs nested objects', () {
        expect(
          diff(
            {
              'a': {
                'b': {'c': 1},
              },
            },
            {
              'a': {
                'b': {'c': 2},
              },
            },
          ),
          [
            {'op': 'replace', 'path': '/a/b/c', 'value': 2},
          ],
        );
      });

      test('appends array items using the "-" token', () {
        expect(
          diff(
            {
              'items': [1],
            },
            {
              'items': [1, 2, 3],
            },
          ),
          [
            {'op': 'add', 'path': '/items/-', 'value': 2},
            {'op': 'add', 'path': '/items/-', 'value': 3},
          ],
        );
      });

      test('removes trailing array items from the tail', () {
        expect(
          diff(
            {
              'items': [1, 2, 3],
            },
            {
              'items': [1],
            },
          ),
          [
            {'op': 'remove', 'path': '/items/2'},
            {'op': 'remove', 'path': '/items/1'},
          ],
        );
      });

      test('emits a whole-document replace when the root type changes', () {
        expect(
          diff({'a': 1}, [1, 2]),
          [
            {
              'op': 'replace',
              'path': '',
              'value': [1, 2],
            },
          ],
        );
        expect(
          diff('hello', 42),
          [
            {'op': 'replace', 'path': '', 'value': 42},
          ],
        );
      });

      test('escapes JSON Pointer tokens (~ and /)', () {
        expect(
          diff({}, {'a/b': 1, 'c~d': 2}),
          [
            {'op': 'add', 'path': '/a~1b', 'value': 1},
            {'op': 'add', 'path': '/c~0d', 'value': 2},
          ],
        );
      });

      test('round-trips a variety of mutations', () {
        assertRoundTrip(
          {
            'status': 'a',
            'items': [1, 2],
            'nested': {'x': 1},
          },
          {
            'status': 'b',
            'items': [1, 2, 3],
            'nested': {'x': 1, 'y': 2},
          },
        );
        assertRoundTrip({'a': 1, 'b': 2}, {'b': 2});
        assertRoundTrip(null, {'a': 1});
        assertRoundTrip({'a': 1}, null);
      });
    });

    group('applyPatch', () {
      test('does not mutate the input document', () {
        final doc = {'a': 1};
        applyPatch(doc, [
          {'op': 'replace', 'path': '/a', 'value': 2},
        ]);
        expect(doc, {'a': 1});
      });

      test('applies a whole-document replace at the root', () {
        expect(
          applyPatch({'a': 1}, [
            {
              'op': 'replace',
              'path': '',
              'value': {'b': 2},
            },
          ]),
          {'b': 2},
        );
      });

      test('initializes a missing parent when adding (lenient)', () {
        expect(
          applyPatch(null, [
            {'op': 'add', 'path': '/status', 'value': 'x'},
          ]),
          {'status': 'x'},
        );
        expect(
          applyPatch({}, [
            {'op': 'replace', 'path': '/a/b', 'value': 1},
          ]),
          {
            'a': {'b': 1},
          },
        );
      });

      test('treats removing a missing member as a no-op', () {
        expect(
          applyPatch({'a': 1}, [
            {'op': 'remove', 'path': '/missing'},
          ]),
          {'a': 1},
        );
      });

      test('honors test operations', () {
        expect(
          applyPatch({'a': 1}, [
            {'op': 'test', 'path': '/a', 'value': 1},
          ]),
          {'a': 1},
        );
        expect(
          () => applyPatch({'a': 1}, [
            {'op': 'test', 'path': '/a', 'value': 2},
          ]),
          throwsA(isA<StateError>()),
        );
      });

      test('supports move and copy', () {
        expect(
          applyPatch({'a': 1}, [
            {'op': 'move', 'from': '/a', 'path': '/b'},
          ]),
          {'b': 1},
        );
        expect(
          applyPatch({'a': 1}, [
            {'op': 'copy', 'from': '/a', 'path': '/b'},
          ]),
          {'a': 1, 'b': 1},
        );
      });

      test('appends to arrays via the "-" token', () {
        expect(
          applyPatch({
            'items': [1],
          }, [
            {'op': 'add', 'path': '/items/-', 'value': 2},
          ]),
          {
            'items': [1, 2],
          },
        );
      });
    });
  });
}
