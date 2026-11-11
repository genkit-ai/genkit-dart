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

import 'package:a2ui_eval/src/renderer.dart';
import 'package:a2ui_eval/src/runner.dart';
import 'package:a2ui_eval/src/scenario.dart';
import 'package:genkit/genkit.dart';
import 'package:test/test.dart';

void main() {
  group('HeadlessRenderer', () {
    test('handles v0.9 split messages and {path} bindings', () {
      final r = HeadlessRenderer();
      final res = r.applyTurn(0, [
        {
          'version': 'v0.9',
          'deleteSurface': {'surfaceId': 's'},
        },
        {
          'version': 'v0.9',
          'createSurface': {'surfaceId': 's', 'catalogId': 'c'},
        },
        {
          'version': 'v0.9',
          'updateComponents': {
            'surfaceId': 's',
            'components': [
              {
                'id': 'root',
                'component': 'Text',
                'text': {'path': '/t'},
              },
            ],
          },
        },
        {
          'version': 'v0.9',
          'updateDataModel': {'surfaceId': 's', 'path': '/t', 'value': '18C'},
        },
      ]);
      expect(res.violations, isEmpty);
      expect(res.changes, {'s': SurfaceChange.created});
      expect(r['s']!.version, 'v0.9');
      expect(r['s']!.labelOf('root'), '18C');
    });

    test('handles v1.0 inlined createSurface and {@path} bindings', () {
      final r = HeadlessRenderer();
      final res = r.applyTurn(0, [
        {
          'version': '1.0',
          'deleteSurface': {'surfaceId': 's'},
        },
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 's',
            'catalogId': 'c',
            'components': [
              {'id': 'root', 'component': 'Button', 'child': 'lbl'},
              {
                'id': 'lbl',
                'component': 'Text',
                'text': {'@path': '/lbl'},
              },
            ],
            'dataModel': {'lbl': 'Refresh'},
          },
        },
      ]);
      expect(res.violations, isEmpty);
      expect(res.changes, {'s': SurfaceChange.created});
      expect(r['s']!.version, '1.0');
      expect(r['s']!.labelOf('root'), 'Refresh');

      // Re-rendering under the same id reads as a replacement.
      final replace = r.applyTurn(1, [
        {
          'version': '1.0',
          'deleteSurface': {'surfaceId': 's'},
        },
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 's',
            'catalogId': 'c',
            'components': [
              {'id': 'root', 'component': 'Text', 'text': 'New'},
            ],
          },
        },
      ]);
      expect(replace.violations, isEmpty);
      expect(replace.changes, {'s': SurfaceChange.replaced});
    });

    test('reports missing root and dangling component references', () {
      final r = HeadlessRenderer();
      final res = r.applyTurn(0, [
        {
          'version': '1.0',
          'createSurface': {
            'surfaceId': 's',
            'catalogId': 'c',
            'components': [
              {'id': 'a', 'component': 'Card', 'child': 'missing'},
            ],
          },
        },
      ]);
      expect(
        res.violations,
        containsAll([
          contains('no root component'),
          contains('references missing "missing"'),
        ]),
      );
    });

    test('excludes components orphaned by updateComponents', () {
      final r = HeadlessRenderer()
        ..applyTurn(0, [
          {
            'version': '1.0',
            'createSurface': {
              'surfaceId': 's',
              'catalogId': 'c',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['keep', 'drop'],
                },
                {'id': 'keep', 'component': 'Text', 'text': 'Live'},
                {'id': 'drop', 'component': 'Gauge', 'label': 'Stale'},
              ],
            },
          },
        ])
        ..applyTurn(1, [
          {
            'version': '1.0',
            'updateComponents': {
              'surfaceId': 's',
              'components': [
                {
                  'id': 'root',
                  'component': 'Column',
                  'children': ['keep'],
                },
              ],
            },
          },
        ]);

      final s = r['s']!;
      expect(s.reachableComponents.keys, ['root', 'keep']);
      expect(s.searchableText, contains('live'));
      expect(s.searchableText, isNot(contains('stale')));
      expect(s.componentTypes, {'Column', 'Text'});
    });

    test(
      'deep-copies updateDataModel payloads and tolerates non-Map roots',
      () {
        final rootMsg = <String, dynamic>{
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': 's',
            'path': '/',
            'value': <String, Object?>{
              'user': <String, Object?>{'name': 'Ada'},
            },
          },
        };
        final subMsg = <String, dynamic>{
          'version': '1.0',
          'updateDataModel': {
            'surfaceId': 's',
            'path': '/items',
            'value': [
              {'label': 'first'},
            ],
          },
        };
        final r = HeadlessRenderer()
          ..applyTurn(0, [
            {
              'version': '1.0',
              'createSurface': {
                'surfaceId': 's',
                'catalogId': 'c',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'hi'},
                ],
              },
            },
            rootMsg,
            subMsg,
          ]);

        writePointer(r['s']!.data, '/user/name', 'Grace');
        writePointer(r['s']!.data, '/items/0/label', 'mutated');
        expect(((rootMsg['updateDataModel'] as Map)['value'] as Map)['user'], {
          'name': 'Ada',
        });
        expect((subMsg['updateDataModel'] as Map)['value'], [
          {'label': 'first'},
        ]);

        // Malformed non-Map at `/` resets to empty map and records a violation.
        final bad = r.applyTurn(1, [
          {
            'version': '1.0',
            'updateDataModel': {'surfaceId': 's', 'path': '/', 'value': 'oops'},
          },
        ]);
        expect(r['s']!.data, isEmpty);
        expect(bad.violations, [contains('root value must be an object')]);
      },
    );

    test(
      'applies a2ui_core DataModel rules: append, delete, and error reporting',
      () {
        final r = HeadlessRenderer()
          ..applyTurn(0, [
            {
              'version': '1.0',
              'createSurface': {
                'surfaceId': 's',
                'catalogId': 'c',
                'components': [
                  {'id': 'root', 'component': 'Text', 'text': 'hi'},
                ],
                'dataModel': {'a': 1, 'b': 2, 'user': 'Ada'},
              },
            },
          ]);

        // Appending/auto-vivifying a list and deleting a key with omitted value.
        final ok = r.applyTurn(1, [
          {
            'version': '1.0',
            'updateDataModel': {
              'surfaceId': 's',
              'path': '/items/0',
              'value': 'x',
            },
          },
          {
            'version': '1.0',
            'updateDataModel': {
              'surfaceId': 's',
              'path': '/items/1',
              'value': 'y',
            },
          },
          {
            'version': '1.0',
            'updateDataModel': {'surfaceId': 's', 'path': '/a'},
          },
        ]);
        expect(ok.violations, isEmpty);
        expect(r['s']!.data, {
          'b': 2,
          'user': 'Ada',
          'items': ['x', 'y'],
        });

        // Writing through a primitive or non-numeric list index records violations.
        final errs = r.applyTurn(2, [
          {
            'version': '1.0',
            'updateDataModel': {
              'surfaceId': 's',
              'path': '/user/name',
              'value': 'Grace',
            },
          },
          {
            'version': '1.0',
            'updateDataModel': {
              'surfaceId': 's',
              'path': '/items/foo',
              'value': 'z',
            },
          },
        ]);
        expect(errs.violations, hasLength(2));
      },
    );

    test(
      'searchableText includes only displayed values and resolved bindings',
      () {
        final r = HeadlessRenderer()
          ..applyTurn(0, [
            {
              'version': '1.0',
              'createSurface': {
                'surfaceId': 's',
                'catalogId': 'c',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['berlinRow', 'btn', 'cityList'],
                  },
                  {
                    'id': 'berlinRow',
                    'component': 'Text',
                    'text': {'@path': '/cities/berlin/temp'},
                  },
                  {
                    'id': 'btn',
                    'component': 'Button',
                    'child': 'btnLbl',
                    'action': {
                      'event': {'name': 'refresh_rome'},
                    },
                  },
                  {'id': 'btnLbl', 'component': 'Text', 'text': 'Refresh'},
                  {
                    'id': 'cityList',
                    'component': 'List',
                    'children': {'path': '/rows', 'componentId': 'rowTpl'},
                  },
                  {
                    'id': 'rowTpl',
                    'component': 'Text',
                    'text': {'@path': 'label'},
                  },
                ],
                'dataModel': {
                  'unused': 'HiddenSecret',
                  'rows': [
                    {'label': 'Tokyo 18C'},
                  ],
                },
              },
            },
          ]);

        final shown = r['s']!.searchableText;
        expect(shown, contains('refresh'));
        expect(shown, contains('tokyo 18c'));
        expect(shown, isNot(contains('berlin')));
        expect(shown, isNot(contains('rome')));
        expect(shown, isNot(contains('column')));
        expect(shown, isNot(contains('hiddensecret')));
      },
    );
  });

  group('writePointer', () {
    test('traverses and appends lists without clobbering them', () {
      final root = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'name': 'old'},
        ],
        'tags': <dynamic>['x', 'y'],
      };
      writePointer(root, '/items/0/name', 'new');
      writePointer(root, '/tags/1', 'z');
      writePointer(root, '/tags/2', 'w');
      expect(root, {
        'items': [
          {'name': 'new'},
        ],
        'tags': ['x', 'z', 'w'],
      });
    });

    test('preserves existing maps with numeric keys', () {
      final root = <String, dynamic>{
        'items': <String, dynamic>{
          '0': <String, dynamic>{'name': 'old'},
        },
      };
      writePointer(root, '/items/0/name', 'new');
      expect(root['items'], isA<Map>());
      expect(root, {
        'items': {
          '0': {'name': 'new'},
        },
      });
    });
  });

  group('Press, Fill, and Expect', () {
    test(
      'Fill writes {@path} and Press resolves nested context + userMessage',
      () {
        final r = HeadlessRenderer()
          ..applyTurn(0, [
            {
              'version': '1.0',
              'createSurface': {
                'surfaceId': 'signup',
                'catalogId': 'c',
                'components': [
                  {
                    'id': 'root',
                    'component': 'Column',
                    'children': ['nameInput', 'submitBtn'],
                  },
                  {
                    'id': 'nameInput',
                    'component': 'TextField',
                    'label': 'Full name',
                    'value': {'@path': '/form/name'},
                  },
                  {
                    'id': 'submitBtn',
                    'component': 'Button',
                    'child': 'submitLbl',
                    'action': {
                      'event': {
                        'name': 'submit',
                        'userMessage': {'@path': '/form/name'},
                        'context': {
                          'nested': {
                            'who': {'@path': '/form/name'},
                            // Plain v0.9 `{path}` is not a binding in v1.0.
                            'literal': {'path': '/form/name'},
                          },
                        },
                      },
                    },
                  },
                  {'id': 'submitLbl', 'component': 'Text', 'text': 'Submit'},
                ],
              },
            },
          ]);

        expect(
          fillInput(r, SurfaceRef.last, 'Full name', 'Ada Lovelace'),
          isNull,
        );
        final press = findAction(r, SurfaceRef.last, ['Submit']);
        expect(press.error, isNull);
        final action =
            ((press.message!.content.single.data!['messages'] as List).single
                    as Map)['action']
                as Map;
        expect(action['userMessage'], 'Ada Lovelace');
        expect(action['context'], {
          'nested': {
            'who': 'Ada Lovelace',
            'literal': {'path': '/form/name'},
          },
        });

        // Expect.acknowledges ignores local Fill edits if the agent did not echo them.
        final ctx = CheckContext(
          before: const [],
          after: [SurfaceSnapshot(r['signup']!)],
          changes: {'signup': SurfaceChange.updated},
          prose: 'Signed up!',
          streamed: const [
            {
              'version': '1.0',
              'updateDataModel': {
                'surfaceId': 'signup',
                'path': '/status',
                'value': 'ok',
              },
            },
          ],
          renderer: r,
        );
        expect(Expect.acknowledges('Ada').fn(ctx), isNotNull);
        expect(Expect.acknowledges('Signed up').fn(ctx), isNull);
      },
    );

    test('Press rejects relative template bindings in event context', () {
      final r = HeadlessRenderer()
        ..applyTurn(0, [
          {
            'version': '1.0',
            'createSurface': {
              'surfaceId': 's',
              'catalogId': 'c',
              'components': [
                {
                  'id': 'root',
                  'component': 'Button',
                  'child': 'lbl',
                  'action': {
                    'event': {
                      'name': 'pick',
                      'context': {
                        'item': {'@path': 'relName'},
                      },
                    },
                  },
                },
                {'id': 'lbl', 'component': 'Text', 'text': 'Pick'},
              ],
            },
          },
        ]);
      final res = findAction(r, SurfaceRef.last, ['Pick']);
      expect(res.message, isNull);
      expect(res.error, contains('relative binding'));
    });

    test('TurnRecord.repairFailed counts all failed-repair log outcomes', () {
      final t = TurnRecord(0, 'say', 'hi')
        ..logs.addAll([
          'WARNING genkit_a2ui: repair failed for "x": y',
          'WARNING genkit_a2ui: repair returned nothing',
          'WARNING genkit_a2ui: repair turned a partial update into a full render, discarding it',
          'WARNING genkit_a2ui: A2UI repair ran out of time',
          'WARNING genkit_a2ui: A2UI repair limit reached',
        ]);
      expect(t.repairFailed, 5);
    });
  });

  group('SurfaceRef.nth', () {
    test('returns null for negative and out-of-range indices', () {
      final r = HeadlessRenderer()
        ..applyTurn(0, [
          {
            'version': '1.0',
            'createSurface': {
              'surfaceId': 's',
              'catalogId': 'c',
              'components': [
                {'id': 'root', 'component': 'Text', 'text': 'hi'},
              ],
            },
          },
        ]);
      final snapshots = [SurfaceSnapshot(r['s']!)];
      expect(SurfaceRef.nth(-1).resolve(snapshots), isNull);
      expect(SurfaceRef.nth(0).resolve(snapshots)?.id, 's');
      expect(SurfaceRef.nth(1).resolve(snapshots), isNull);
    });
  });
}
