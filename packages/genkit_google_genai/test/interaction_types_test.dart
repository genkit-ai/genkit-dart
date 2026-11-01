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

import 'dart:convert';

import 'package:genkit_google_genai/src/interaction_types.dart';
import 'package:test/test.dart';

// A googleAI file-search response, as received live (JS testapp `file-search`
// flow, Oct 23 2026), shortened: signatures and the cited source text are
// replaced, and usage keeps only some fields.
const _fileSearchResponse = '''
{
  "status": "completed",
  "usage": {
    "total_tokens": 1101,
    "total_input_tokens": 48,
    "input_tokens_by_modality": [{"modality": "text", "tokens": 48}],
    "total_cached_tokens": 0,
    "total_output_tokens": 62,
    "total_tool_use_tokens": 908,
    "tool_use_tokens_by_modality": [{"modality": "text", "tokens": 908}],
    "total_thought_tokens": 83,
    "raw_prompt_token": 420
  },
  "created": "2026-10-23T18:10:13Z",
  "updated": "2026-10-23T18:10:13Z",
  "service_tier": "standard",
  "steps": [
    {"id": "call_481000", "signature": "sig-call", "type": "file_search_call"},
    {"call_id": "call_481000", "signature": "sig-result",
     "type": "file_search_result"},
    {"signature": "sig-thought", "type": "thought"},
    {
      "content": [
        {
          "text": "The main character is **Elara**.",
          "annotations": [
            {
              "start_index": 0,
              "end_index": 67,
              "document_uri": "fileSearchStores/6gndml060k16-4oi3oqnk6p8x",
              "file_name": "",
              "source": "The Whispering Woods ...",
              "custom_metadata": {"author": "foo"},
              "type": "file_citation"
            }
          ],
          "type": "text"
        }
      ],
      "type": "model_output"
    }
  ],
  "object": "interaction",
  "model": "gemini-3.8-flash"
}
''';

Map<String, Object?> _decode(String json) =>
    (jsonDecode(json) as Map).cast<String, Object?>();

void main() {
  group('GeminiInteraction from a live response', () {
    final interaction = GeminiInteraction.fromJson(
      _decode(_fileSearchResponse),
    );

    test('reads the top-level fields', () {
      expect(interaction.status, 'completed');
      expect(interaction.model, 'gemini-3.8-flash');
      expect(interaction.created, '2026-10-23T18:10:13Z');
      expect(interaction.id, isNull); // not stored
    });

    test('reads usage, including fields from nested lists', () {
      final usage = interaction.usage!;
      expect(usage.totalTokens, 1101);
      expect(usage.totalInputTokens, 48);
      expect(usage.totalToolUseTokens, 908);
      expect(usage.totalThoughtTokens, 83);
      final input = usage.inputTokensByModality!.single;
      expect(input.modality, ResponseModality.text);
      expect(input.tokens, 48);
    });

    test('tells steps apart by type and wraps them', () {
      final steps = interaction.steps!;
      expect(steps.map((s) => s.type), [
        'file_search_call',
        'file_search_result',
        'thought',
        'model_output',
      ]);

      final call = FileSearchCallStep.fromJson(steps[0].json);
      expect(call.id, 'call_481000');
      expect(call.signature, 'sig-call');

      final result = FileSearchResultStep.fromJson(steps[1].json);
      expect(result.callId, 'call_481000');
      expect(result.result, isNull);

      expect(ThoughtStep.fromJson(steps[2].json).signature, 'sig-thought');
    });

    test('reads text content and its file citations', () {
      final output = ModelOutputStep.fromJson(interaction.steps![3].json);
      final text = TextContent.fromJson(output.content!.single.json);
      expect(text.text, 'The main character is **Elara**.');

      final annotation = text.annotations!.single;
      expect(annotation.type, 'file_citation');
      expect(annotation.startIndex, 0);
      expect(annotation.endIndex, 67);
      final citation = FileCitation.fromJson(annotation.json);
      expect(
        citation.documentUri,
        'fileSearchStores/6gndml060k16-4oi3oqnk6p8x',
      );
      expect(citation.customMetadata, {'author': 'foo'});
    });

    test('keeps every field, known or not, for raw and resent history', () {
      expect(
        jsonEncode(interaction.json),
        jsonEncode(_decode(_fileSearchResponse)),
      );
      expect(interaction.json['service_tier'], 'standard');
      expect(interaction.usage!.json['raw_prompt_token'], 420);
    });
  });

  group('built-in tool steps from a live Google Maps response', () {
    // vertexAI gemini-3.8-flash, JS testapp `maps-grounding` (Oct 22 2026).
    final steps = [
      {'id': 'rxbackug', 'type': 'google_maps_call'},
      {
        'call_id': 'rxbackug',
        'type': 'google_maps_result',
        'result': [
          {
            'places': [
              {
                'place_id': 'ChIJefTaTQZD04kRzuh2lpwlV-A',
                'name': 'Queen Victoria Park',
              },
            ],
          },
        ],
      },
    ].map(Step.fromJson).toList();

    test('reads a call without arguments or signature', () {
      final call = GoogleMapsCallStep.fromJson(steps[0].json);
      expect(call.id, 'rxbackug');
      expect(call.arguments, isNull);
      expect(call.signature, isNull);
    });

    test('reads a result as a list of maps', () {
      final result = GoogleMapsResultStep.fromJson(steps[1].json);
      expect(result.callId, 'rxbackug');
      expect(result.result!.single['places'], isA<List<Object?>>());
    });
  });

  group('constructors', () {
    test('write the API keys in snake_case and leave out nulls', () {
      final step = FunctionResultStep(
        callId: 'c1',
        name: 'getWeather',
        result: {'temp': 72},
        isError: false,
      );
      expect(step.json, {
        'type': 'function_result',
        'name': 'getWeather',
        'call_id': 'c1',
        'is_error': false,
        'result': {'temp': 72},
      });
      expect(FunctionCallStep(name: 'f', id: 'c2').json, {
        'type': 'function_call',
        'name': 'f',
        'id': 'c2',
      });
    });

    test('nest wrapped types as their maps', () {
      final request = CreateInteractionRequest(
        model: 'gemini-3.8-flash',
        input: [
          UserInputStep(content: [TextContent(text: 'Hi')]),
        ],
        tools: [
          InteractionFunctionTool(name: 'getWeather', description: 'Weather'),
          InteractionFileSearchTool(fileSearchStoreNames: ['stores/1']),
        ],
        generationConfig: ModelGenerationConfig(
          temperature: 0.5,
          maxOutputTokens: 100,
        ),
        serviceTier: ServiceTier.flex,
        store: false,
      );
      expect(jsonDecode(jsonEncode(request.json)), {
        'model': 'gemini-3.8-flash',
        'input': [
          {
            'type': 'user_input',
            'content': [
              {'type': 'text', 'text': 'Hi'},
            ],
          },
        ],
        'tools': [
          {'type': 'function', 'name': 'getWeather', 'description': 'Weather'},
          {
            'type': 'file_search',
            'file_search_store_names': ['stores/1'],
          },
        ],
        'store': false,
        'generation_config': {'temperature': 0.5, 'max_output_tokens': 100},
        'service_tier': 'flex',
      });
    });

    test('a dynamic tool keeps its own type and fields', () {
      expect(InteractionDynamicTool('new_tool', {'some_option': 1}).json, {
        'some_option': 1,
        'type': 'new_tool',
      });
    });
  });

  group('setters', () {
    test('set a field, and remove it when set to null', () {
      final config = ModelGenerationConfig();
      config.thinkingLevel = 'low';
      expect(config.json, {'thinking_level': 'low'});
      config.thinkingLevel = null;
      expect(config.json, isEmpty);
    });

    test('write through to the wrapped map', () {
      final json = <String, Object?>{'type': 'function_call', 'id': 'c1'};
      FunctionCallStep.fromJson(json).arguments = {'city': 'Boston'};
      expect(json['arguments'], {'city': 'Boston'});
    });
  });

  group('values from JSON', () {
    test('numbers convert between int and double', () {
      final tool = InteractionGoogleMapsTool.fromJson({
        'type': 'google_maps',
        'latitude': 43,
        'longitude': -79.0849,
      });
      expect(tool.latitude, 43.0);
      expect(tool.longitude, -79.0849);
      expect(Usage.fromJson({'total_tokens': 12.0}).totalTokens, 12);
    });

    test('a missing or mistyped nested value reads as null', () {
      final step = ModelOutputStep.fromJson({'type': 'model_output'});
      expect(step.content, isNull);
      expect(GeminiInteraction.fromJson({'usage': 'oops'}).usage, isNull);
    });
  });

  group('stream events', () {
    test('tell events apart by event_type and wrap their payloads', () {
      final start = InteractionSseEvent.fromJson(
        _decode(
          '{"event_type": "step.start", "index": 0, '
          '"step": {"type": "model_output"}, "event_id": "e1"}',
        ),
      );
      expect(start.eventType, 'step.start');
      expect(start.eventId, 'e1');
      expect(StepStart.fromJson(start.json).step!.type, 'model_output');

      final delta = StepDelta.fromJson(
        _decode(
          '{"event_type": "step.delta", "index": 0, '
          '"delta": {"type": "text", "text": "Hel"}}',
        ),
      );
      expect(delta.index, 0);
      expect(delta.delta!.type, 'text');
      expect(TextDelta.fromJson(delta.delta!.json).text, 'Hel');

      final error = ErrorEvent.fromJson(
        _decode(
          '{"event_type": "error", '
          '"error": {"code": "safety", "message": "Blocked"}}',
        ),
      );
      expect(error.error!.code, 'safety');
      expect(error.error!.message, 'Blocked');
    });
  });
}
