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

/// How an output schema reaches Anthropic: natively on beta, through the
/// forced `return_output` tool on stable, and the rewriting each needs.

void main() {
  group('structured output on the wire', () {
    // `output_config.format` is beta-gated, so every native-path case asks
    // for the beta surface. Stable serves the same schema through the forced
    // `return_output` tool, and an uncurated name reaches neither: it claims
    // nothing, so core simulates and the schema never arrives here at all.
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
        outputSchema: schema,
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent, isNot(contains(r'$schema')));
      expect(sent['additionalProperties'], false);

      final pet = (sent['properties'] as Map)['pet'] as Map;
      expect(pet['additionalProperties'], false);
    });

    test('the stable surface falls back to the forced tool', () async {
      // Outside beta there is no `output_config.format` to put the schema in,
      // so it travels as a tool the model is forced to call.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        outputSchema: schema,
      );

      expect(body, isNot(contains('output_config')));
      final tool = (body['tools'] as List).single as Map<String, dynamic>;
      expect(tool['name'], 'return_output');
      expect(body['tool_choice'], {'type': 'tool', 'name': 'return_output'});
    });

    test('native structured output composes with manual thinking', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: schema,
        thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
      );

      expect(body['thinking'], {'type': 'enabled', 'budget_tokens': 1024});
      expect((body['output_config'] as Map)['format'], isNotNull);
    });

    test('the fallback rejects manual thinking rather than the wire '
        'doing it', () async {
      // The forced tool choice is what Anthropic refuses alongside extended
      // thinking, so the stable path says so before spending the request.
      await expectLater(
        requestOnTheWire(
          model: 'claude-sonnet-4-5',
          outputSchema: schema,
          thinking: ThinkingConfig(type: 'enabled', budgetTokens: 1024),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('manual thinking')),
        ),
      );
    });

    test('the fallback refuses a request that also carries tools', () async {
      // Only reachable by overriding apiVersion to stable after core read the
      // beta claim; forcing `return_output` would strand the caller's tools.
      await expectLater(
        requestOnTheWire(
          model: 'claude-sonnet-4-5',
          pluginApiVersion: 'beta',
          apiVersion: 'stable',
          outputSchema: schema,
          tools: ['lookup'],
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCodes.INVALID_ARGUMENT)
              .having((e) => e.message, 'message', contains('beta API')),
        ),
      );
    });

    test('a dated snapshot of a capable model still goes native', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5-20250929',
        apiVersion: 'beta',
        outputSchema: schema,
      );
      expect((body['output_config'] as Map)['format'], isNotNull);
      expect(body, isNot(contains('tool_choice')));
    });

    test('normalization recurses through schema lists', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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
        apiVersion: 'beta',
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

    test('a dictionary field keeps its value schema', () async {
      // `additionalProperties` holds a schema for a `Map<String, T>` field -
      // which is what schemantic emits for one - so closing the object must
      // not overwrite it. It did, and Anthropic then constrained the model to
      // return `{}` for every map-valued field.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          'type': 'object',
          'properties': {
            'labels': {
              'type': 'object',
              'additionalProperties': {'type': 'string'},
            },
            'plain': {
              'type': 'object',
              'properties': {
                'a': {'type': 'string'},
              },
            },
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      final properties = sent['properties'] as Map;
      expect((properties['labels'] as Map)['additionalProperties'], {
        'type': 'string',
      });
      // A plain object is still closed.
      expect((properties['plain'] as Map)['additionalProperties'], false);
      expect(sent['additionalProperties'], false);
    });

    test('an explicit additionalProperties: true survives', () async {
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: {
          'type': 'object',
          'additionalProperties': true,
          'properties': {
            'a': {'type': 'string'},
          },
        },
      );

      final sent =
          ((body['output_config'] as Map)['format'] as Map)['schema'] as Map;
      expect(sent['additionalProperties'], true);
    });

    test('replacing the betas takes the native path away', () async {
      // `betas` replaces the curated list rather than adding to it, so opting
      // into some other beta by name drops `structured-outputs`. Sending
      // `output_config.format` without it is a 400, so the schema falls back
      // to the tool.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        betas: ['some-new-beta-2026-01-01'],
        outputSchema: schema,
      );

      expect(body, isNot(contains('output_config')));
      expect(body['tool_choice'], {'type': 'tool', 'name': 'return_output'});
    });

    test('pinning a newer structured-outputs revision still goes native', () {
      return expectLater(
        requestOnTheWire(
          model: 'claude-sonnet-4-5',
          apiVersion: 'beta',
          betas: ['structured-outputs-2027-01-01'],
          outputSchema: schema,
        ).then((body) => (body['output_config'] as Map)['format']),
        completion(isNotNull),
      );
    });

    test('an unconstrained request is not constrained natively', () async {
      // `constrained: false` is the caller opting out of the mechanism, not
      // asking for a different one - and `output_config.format` is every bit
      // as binding as the forced tool.
      final body = await requestOnTheWire(
        model: 'claude-sonnet-4-5',
        apiVersion: 'beta',
        outputSchema: schema,
        constrained: false,
      );

      expect(body, isNot(contains('output_config')));
      // The tool is offered, as it is on the stable surface, but not pinned.
      final toolNames = (body['tools'] as List)
          .map((t) => (t as Map)['name'])
          .toList();
      expect(toolNames, contains('return_output'));
      expect(body, isNot(contains('tool_choice')));
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
        apiVersion: 'beta',
        outputSchema: schema,
        outputConfig: AnthropicOutputConfig(effort: 'low'),
      );

      final outputConfig = body['output_config'] as Map;
      expect(outputConfig['effort'], 'low');
      expect((outputConfig['format'] as Map)['type'], 'json_schema');
    });

    test('a caller toolChoice is dropped when there are no tools', () async {
      // Anthropic rejects a choice with nothing to choose from - "tool_choice.
      // any may only be specified while providing tools". Newly reachable:
      // an output schema used to always append `return_output`, so a caller's
      // toolChoice always had a tool to refer to. Both routes get there now:
      // the curated model goes native on beta, and the uncurated one is
      // simulated by core, which strips the schema before it arrives.
      for (final model in ['claude-sonnet-4-5', 'claude-future-model']) {
        final body = await requestOnTheWire(
          model: model,
          apiVersion: 'beta',
          outputSchema: schema,
          toolChoice: 'any',
        );
        expect(body['tools'], isNull, reason: model);
        expect(body['tool_choice'], isNull, reason: model);
      }
    });
  });
}
