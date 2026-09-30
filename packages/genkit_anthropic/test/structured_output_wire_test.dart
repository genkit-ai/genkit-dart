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

import 'package:genkit/genkit.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';
import 'package:genkit_anthropic/src/plugin_impl.dart';
import 'package:test/test.dart';

import 'wire_harness.dart';

/// How an output schema reaches Anthropic: natively as `output_config.format`
/// on either surface, and the rewriting that needs.

void main() {
  group('structured output on the wire', () {
    // `output_config.format` is served on either surface, so these run on the
    // default one.
    final schema = <String, dynamic>{
      r'$schema': 'https://json-schema.org/draft/2020-12/schema',
      'type': 'object',
      'properties': {
        'name': {'type': 'string'},
        'pet': {
          'type': 'object',
          'properties': {
            'species': {'type': 'string'},
          },
        },
      },
    };

    test('a capable model sends a native json_schema format', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      final format =
          (body['output_config'] as Map)['format'] as Map<String, dynamic>;
      expect(format['type'], 'json_schema');
      expect(body, isNot(contains('tools')));
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization strips \$schema and closes nested objects', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent, isNot(contains(r'$schema')));
      expect(sent['additionalProperties'], false);

      final pet = (sent['properties'] as Map)['pet'] as Map;
      expect(pet['additionalProperties'], false);
    });

    test('native structured output composes with manual thinking', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
      );

      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('an uncurated model name goes native too', () async {
      // A model released after this plugin claims the same capabilities as a
      // curated one, so its schema is not left to anyone else.
      final body = await requestOnTheWire(
        model: 'claude-future-model',
        outputSchema: schema,
      );

      final format = (body['output_config'] as Map)['format'] as Map;
      expect(format['type'], 'json_schema');
      expect(body, isNot(contains('system')));
    });

    test('a dated snapshot of a capable model still goes native', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5-20250929',
        outputSchema: schema,
      );
      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization recurses through schema lists', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'tags': {
              'type': 'array',
              'items': {
                'type': 'object',
                'properties': {
                  'label': {'type': 'string'},
                },
              },
            },
            'either': {
              'anyOf': [
                {
                  'type': 'object',
                  'properties': {
                    'a': {'type': 'string'},
                  },
                },
              ],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final props = sent['properties'] as Map;
      final items = (props['tags'] as Map)['items'] as Map;
      expect(items['additionalProperties'], false);

      final anyOf = (props['either'] as Map)['anyOf'] as List;
      expect((anyOf.single as Map)['additionalProperties'], false);
    });

    test('a \$ref root keeps no sibling constraints', () async {
      // Named Genkit schemas arrive as a bare $ref plus $defs. Anthropic
      // rejects `$ref` alongside `type`/`additionalProperties`, so neither may
      // be added to the root - only to the definitions it points at.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
              'required': ['name'],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent.containsKey('type'), isFalse);
      expect(sent.containsKey('additionalProperties'), isFalse);

      final person = (sent[r'$defs'] as Map)['Person'] as Map;
      expect(person['additionalProperties'], false);
    });

    test('an untyped object schema is inferred and closed', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'properties': {
            'name': {'type': 'string'},
            'inner': {
              'required': ['x'],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent['type'], 'object');
      expect(sent['additionalProperties'], false);

      // Inferred from `required` alone, at depth.
      final inner = (sent['properties'] as Map)['inner'] as Map;
      expect(inner['type'], 'object');
      expect(inner['additionalProperties'], false);

      // A leaf with a declared non-object type is left alone.
      final name = (sent['properties'] as Map)['name'] as Map;
      expect(name.containsKey('additionalProperties'), isFalse);
    });

    test('type is not inferred onto a \$ref node', () async {
      // Inferring here would recreate the sibling-constraint 400 that the
      // $ref guard exists to prevent.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          'properties': {
            'name': {'type': 'string'},
          },
          r'$defs': {
            'Person': {'type': 'object'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent.containsKey('type'), isFalse);
      expect(sent.containsKey('additionalProperties'), isFalse);
    });

    test('a \$ref root passes through without sibling constraints', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {'type': 'object'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent[r'$ref'], '#/\$defs/Person');
      // A \$ref node may carry no siblings, so no inferred type is added.
      expect(sent.containsKey('type'), isFalse);
      expect(((sent[r'$defs'] as Map)['Person'] as Map)['type'], 'object');
    });

    test('a nullable object is still closed', () async {
      // `["object","null"]` is how schemantic spells an optional object. An
      // equality check against 'object' missed it, and Anthropic replied
      //   400 For 'object' type, 'additionalProperties' must be explicitly
      //   set to false
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'nested': {
              'type': ['object', 'null'],
              'properties': {
                'a': {'type': 'string'},
              },
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final nested = (sent['properties'] as Map)['nested'] as Map;
      expect(nested['additionalProperties'], false);
      expect(sent['additionalProperties'], false);
    });

    test('a field named like a keyword does not corrupt the schema', () async {
      // The recursion descended into every Map, so `properties` was itself
      // treated as a schema node: it gained `type: object` and a closed
      // marker as though the field names were keywords.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'required': {'type': 'boolean'},
            'type': {'type': 'string'},
            'properties': {'type': 'string'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final properties = sent['properties'] as Map;
      expect(
        properties.keys,
        unorderedEquals(['required', 'type', 'properties']),
      );
      expect(properties['required'], {'type': 'boolean'});
      expect(properties.containsKey('additionalProperties'), isFalse);
    });

    test('a \$defs map is not treated as a schema node', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': '#/\$defs/Person',
          r'$defs': {
            'Person': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
              },
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final defs = sent[r'$defs'] as Map;
      expect(defs.keys, ['Person']);
      expect((defs['Person'] as Map)['additionalProperties'], false);
      expect(defs.containsKey('type'), isFalse);
    });

    test('validation keywords are stripped from the native schema', () async {
      // output_config validates strictly: "For 'integer' type, properties
      // maximum, minimum are not supported". Genkit's generator emits these
      // from @IntegerField(minimum:), so ordinary annotated types hit it.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'n': {'type': 'integer', 'minimum': 1, 'maximum': 10},
            's': {'type': 'string', 'minLength': 2, 'pattern': '^a'},
            'l': {
              'type': 'array',
              'minItems': 1,
              'items': {'type': 'string'},
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final properties = sent['properties'] as Map;
      expect(properties['n'], {'type': 'integer'});
      expect(properties['s'], {'type': 'string'});
      expect(properties['l'], {
        'type': 'array',
        'items': {'type': 'string'},
      });
    });

    test('a dictionary field travels in the prompt', () async {
      // `additionalProperties` may only be `false` here, so an open map would
      // be closed to an object with no properties and the model would answer
      // `{}` - the value dropped, silently. The schema goes in the prompt
      // instead, where the map survives.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'scores': {
              'type': 'object',
              'additionalProperties': {'type': 'integer'},
            },
          },
        },
      );

      expect(body, isNot(contains('output_config')));
      expect(body['system'].toString(), contains('additionalProperties'));
    });

    test('an explicitly closed object still goes native', () async {
      // `additionalProperties: false` is what the validator wants, so a schema
      // that already says it is expressible as it stands.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'additionalProperties': false,
          'properties': {
            'a': {'type': 'string'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent['additionalProperties'], false);
    });

    test('oneOf is rewritten to anyOf', () async {
      // `oneOf` answers "Schema type 'oneOf' is not supported" while `anyOf`
      // with the same branches is accepted, and `SchemanticType.nullable()`
      // emits `oneOf`, so an optional field would otherwise 400.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'maybe': {
              'oneOf': [
                {'type': 'string'},
                {'type': 'null'},
              ],
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final maybe = (sent['properties'] as Map)['maybe'] as Map;
      expect(maybe.containsKey('oneOf'), isFalse);
      expect(maybe['anyOf'], [
        {'type': 'string'},
        {'type': 'null'},
      ]);
    });

    test('an empty sub-schema travels in the prompt instead', () async {
      // A `dynamic` or `Object?` field compiles to the empty schema `{}`, and
      // the validator answers "Empty schema ({}) that accepts any
      // JSON value is not supported. Please specify a concrete type." The
      // request still goes out, with the shape in the system prompt.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'name': {'type': 'string'},
            'extra': <String, dynamic>{},
          },
        },
      );

      expect(body, isNot(contains('output_config')));
      expect(body['system'].toString(), contains('conform to the following'));
      expect(body['system'].toString(), contains('"name"'));
    });

    test('an empty schema nested in a list keyword is found too', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'either': {
              'anyOf': [
                {'type': 'string'},
                <String, dynamic>{},
              ],
            },
          },
        },
      );

      expect(body, isNot(contains('output_config')));
    });

    test('a recursive schema travels in the prompt', () async {
      // `class Node { List<Node> children; }` compiles to a `$defs` entry that
      // refers to itself, and Anthropic does not support recursive schemas.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': r'#/$defs/Node',
          r'$defs': {
            'Node': {
              'type': 'object',
              'properties': {
                'name': {'type': 'string'},
                'children': {
                  'type': 'array',
                  'items': {r'$ref': r'#/$defs/Node'},
                },
              },
            },
          },
        },
      );

      expect(body, isNot(contains('output_config')));
      expect(body['system'].toString(), contains('conform to the following'));
      expect(body['system'].toString(), contains('children'));
    });

    test('recursion through another definition is found too', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': r'#/$defs/A',
          r'$defs': {
            'A': {
              'type': 'object',
              'properties': {
                'b': {r'$ref': r'#/$defs/B'},
              },
            },
            'B': {
              'type': 'object',
              'properties': {
                'a': {r'$ref': r'#/$defs/A'},
              },
            },
          },
        },
      );

      expect(body, isNot(contains('output_config')));
    });

    test('a \$ref inside default data is not a reference', () async {
      // `{"$ref": "#"}` as a `default` is an object *value* two characters
      // wide, not a cycle. Reading it as one would send an expressible schema
      // to the prompt instead of constraining it.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'cfg': {
              'type': 'object',
              'properties': {
                'x': {'type': 'string'},
              },
              'default': {r'$ref': '#'},
            },
          },
        },
      );

      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('system')));
    });

    test('a \$ref inside enum or const data is not a reference', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'e': {
              'type': 'object',
              'enum': [
                {r'$ref': '#'},
              ],
            },
            'c': {
              'type': 'object',
              'const': {r'$ref': r'#/$defs/Node'},
            },
          },
          r'$defs': {
            'Node': {
              'type': 'object',
              'properties': {
                'a': {'type': 'string'},
              },
            },
          },
        },
      );

      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('recursion through a slash-bearing definition key is found', () async {
      // `#/$defs/a~1b` names the definition `a/b`: `~1` is an escaped slash,
      // so the key has to be escaped back before the two are compared.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          r'$ref': r'#/$defs/a~1b',
          r'$defs': {
            'a/b': {
              'type': 'object',
              'properties': {
                'self': {r'$ref': r'#/$defs/a~1b'},
              },
            },
          },
        },
      );

      expect(body, isNot(contains('output_config')));
      expect(body['system'].toString(), contains('conform to the following'));
    });

    test('a definition shared by two fields still goes native', () async {
      // Reused, not recursive: `$defs/Pet` is reachable twice but never from
      // itself.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: {
          'type': 'object',
          'properties': {
            'first': {r'$ref': r'#/$defs/Pet'},
            'second': {r'$ref': r'#/$defs/Pet'},
          },
          r'$defs': {
            'Pet': {
              'type': 'object',
              'properties': {
                'species': {'type': 'string'},
              },
            },
          },
        },
      );

      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('the prompt fallback keeps the caller\'s own system prompt', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        messages: [
          Message(
            role: Role.system,
            content: [TextPart(text: 'you are terse')],
          ),
          Message(
            role: Role.user,
            content: [TextPart(text: 'hello')],
          ),
        ],
        outputSchema: {
          'type': 'object',
          'properties': {'extra': <String, dynamic>{}},
        },
      );

      final system = body['system'].toString();
      expect(system, contains('you are terse'));
      expect(system, contains('conform to the following'));
    });

    test('an ordinary schema still goes native', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('system')));
    });

    test('an unconstrained request is not constrained natively', () async {
      // `constrained: false` is the caller opting out of the mechanism, not
      // asking for a different one - and `output_config.format` binds.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        constrained: false,
      );

      expect(body, isNot(contains('output_config')));
      // And nothing stands in for it: there is no tool to add any more.
      expect(body, isNot(contains('tools')));
    });

    test('an unrecognised apiVersion is rejected, not read as stable', () {
      // Silently downgrading 'Beta' to stable would drop the header and the
      // features that depend on it, with nothing to point at.
      final invalidArgument = throwsA(
        isA<GenkitException>().having(
          (e) => e.status,
          'status',
          StatusCodes.INVALID_ARGUMENT,
        ),
      );

      for (final value in ['Beta', 'BETA', 'preview', '']) {
        // On the plugin, at construction: the claim this plugin advertises
        // depends on the surface, so an unusable value cannot wait for a
        // request to be noticed.
        expect(
          () => AnthropicPluginImpl(apiKey: 'k', apiVersion: value),
          invalidArgument,
          reason: value,
        );
        // And on the request.
        expect(
          () => requestOnTheWire(model: 'claude-sonnet-5', apiVersion: value),
          invalidArgument,
          reason: value,
        );
      }
    });

    test('effort and a native format ride in the same output_config', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
        outputConfig: AnthropicOutputConfig(effort: 'low'),
      );

      final outputConfig = body['output_config'] as Map;
      expect(outputConfig['effort'], 'low');
      expect((outputConfig['format'] as Map)['type'], 'json_schema');
    });

    test('a caller toolChoice is dropped when there are no tools', () async {
      // Anthropic rejects a choice with nothing to choose from - "tool_choice.
      // any may only be specified while providing tools" - and a native
      // output schema adds no tool for one to refer to.
      for (final model in ['claude-sonnet-4-5', 'claude-future-model']) {
        final body = await requestOnTheWire(
          model: model,
          apiVersion: 'beta',
          outputSchema: schema,
          toolChoice: 'required',
        );
        expect(body['tools'], isNull, reason: model);
        expect(body['tool_choice'], isNull, reason: model);
      }
    });
  });
}
