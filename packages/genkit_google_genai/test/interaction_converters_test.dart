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

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/src/interaction_converters.dart';
import 'package:genkit_google_genai/src/interaction_types.dart';
import 'package:genkit_google_genai/src/model.dart';
import 'package:test/test.dart';

/// The parts as JSON, for comparisons.
List<Map<String, dynamic>> _json(List<Part> parts) =>
    parts.map((p) => p.toJson()).toList();

/// The steps as JSON (through an encode/decode, like on the wire).
List<Object?> _wire(List<Step> steps) =>
    jsonDecode(jsonEncode([for (final s in steps) s.json])) as List<Object?>;

Message _message(Role role, List<Map<String, dynamic>> parts) =>
    Message(role: role, content: parts.map(Part.fromJson).toList());

// Stream events, as in the JS tests.
InteractionSseEvent _start(int index, Map<String, Object?> step) =>
    InteractionSseEvent.fromJson({
      'event_type': 'step.start',
      'index': index,
      'step': step,
    });
InteractionSseEvent _delta(int index, Map<String, Object?> d) =>
    InteractionSseEvent.fromJson({
      'event_type': 'step.delta',
      'index': index,
      'delta': d,
    });
InteractionSseEvent _stop(int index, [Map<String, Object?>? usage]) =>
    InteractionSseEvent.fromJson({
      'event_type': 'step.stop',
      'index': index,
      'usage': ?usage,
    });
InteractionSseEvent _completed(Map<String, Object?> interaction) =>
    InteractionSseEvent.fromJson({
      'event_type': 'interaction.completed',
      'interaction': interaction,
    });
List<InteractionSseEvent> _thoughtEvents(int index) => [
  _start(index, {'type': 'thought'}),
  _delta(index, {'type': 'thought_signature', 'signature': 'sig_thought'}),
  _stop(index),
];

/// The chunk parts for each event, in order, as JSON.
List<List<Map<String, dynamic>>> _chunksFor(List<InteractionSseEvent> events) {
  final toChunkParts = createInteractionChunkConverter();
  return [for (final event in events) _json(toChunkParts(event))];
}

void main() {
  group('createInteractionChunkConverter', () {
    // Event sequences seen live (Oct 2026), from the JS tests; signatures
    // and text shortened. Every tool step streams the same way: step.start
    // with the ids, one delta with everything else, then step.stop.

    test('streams a function call as a tool request when the interaction '
        'completes', () {
      // vertexAI gemini-3.8-flash (tool-calling flow).
      final chunks = _chunksFor([
        ..._thoughtEvents(0),
        _start(1, {
          'id': 'call_7227796',
          'type': 'function_call',
          'name': 'getWeather',
          'arguments': <String, Object?>{},
        }),
        _delta(1, {
          'type': 'arguments_delta',
          'arguments': '{"location":"Paris, France"}',
        }),
        _stop(1, {'total_tokens': 210}),
        _completed({'id': '', 'status': 'requires_action'}),
      ]);
      expect(chunks, [
        <Object?>[],
        [
          {
            'metadata': {'thoughtSignature': 'sig_thought'},
          },
        ],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        <Object?>[],
        [
          {
            'toolRequest': {
              'ref': 'call_7227796',
              'name': 'getWeather',
              'input': {'location': 'Paris, France'},
            },
          },
        ],
      ]);
    });

    test('streams a long function call argument from a single '
        'arguments_delta', () {
      // googleAI gemini-3.8-flash (streaming-tool-calling flow): a 300+ word
      // argument still came as one delta.
      final longText = 'In the misty heart of the Whispering Woods. ' * 40;
      final args = {
        'longText': longText,
        'nestedData': {
          'arrayItems': ['a'],
          'id': 101,
        },
      };
      final chunks = _chunksFor([
        ..._thoughtEvents(0),
        _start(1, {
          'id': 'call_958433',
          'type': 'function_call',
          'name': 'getCharacterName',
          'arguments': <String, Object?>{},
        }),
        _delta(1, {'type': 'arguments_delta', 'arguments': jsonEncode(args)}),
        _stop(1),
        _completed({'status': 'requires_action'}),
      ]);
      expect(chunks.last, [
        {
          'toolRequest': {
            'ref': 'call_958433',
            'name': 'getCharacterName',
            'input': args,
          },
        },
      ]);
    });

    test('does not stream a server-side function call as a tool request', () {
      // Seen live with MCP on googleAI: the call and its result in the same
      // response, with status requires_action. Nothing for Genkit to run.
      final chunks = _chunksFor([
        _start(0, {
          'id': 'call_1',
          'type': 'function_call',
          'name': 'complex_server:analyze_data',
          'arguments': <String, Object?>{},
        }),
        _delta(0, {'type': 'arguments_delta', 'arguments': '{"x":1}'}),
        _stop(0),
        _start(1, {
          'type': 'function_result',
          'call_id': 'call_1',
          'name': 'complex_server:analyze_data',
          'result': 'ok',
        }),
        _stop(1),
        _completed({'status': 'requires_action'}),
      ]);
      final parts = chunks.expand((c) => c).toList();
      expect(parts.where((p) => p.containsKey('toolRequest')), isEmpty);
      expect(parts.map((p) => (p['custom'] as Map).keys.toList()).toList(), [
        ['serverFunctionCall'],
        ['serverFunctionResult'],
      ]);
    });

    test('streams Google Search steps with their ids when each step stops, '
        'matching the final response', () {
      // googleAI gemini-3.6-flash (streaming-google-search flow).
      final queries = ['Nobel Prize in Physics 2026 winner'];
      final result = [
        {'search_suggestions': '<div>...</div>'},
      ];
      final chunks = _chunksFor([
        _start(0, {
          'id': 'call_1725402',
          'signature': '',
          'type': 'google_search_call',
          'search_type': 'web_search',
        }),
        _delta(0, {
          'type': 'google_search_call',
          'signature': 'sig_call',
          'arguments': {'queries': queries},
        }),
        _stop(0),
        _start(1, {
          'call_id': 'call_1725402',
          'signature': '',
          'type': 'google_search_result',
        }),
        _delta(1, {
          'type': 'google_search_result',
          'signature': 'sig_result',
          'result': result,
          'is_error': false,
        }),
        _stop(1),
        ..._thoughtEvents(2),
        _start(3, {'type': 'model_output'}),
        _delta(3, {'type': 'text', 'text': 'The 2026 Nobel Prize '}),
        _delta(3, {'type': 'text', 'text': 'in Physics...'}),
        _stop(3),
        _completed({'status': 'completed'}),
      ]);
      final finalContent = _json(
        fromInteractionSync(
          GeminiInteraction.fromJson({
            'status': 'completed',
            'steps': [
              {
                'id': 'call_1725402',
                'signature': 'sig_call',
                'type': 'google_search_call',
                'search_type': 'web_search',
                'arguments': {'queries': queries},
              },
              {
                'call_id': 'call_1725402',
                'signature': 'sig_result',
                'type': 'google_search_result',
                'result': result,
                'is_error': false,
              },
            ],
          }),
        ).message!.content,
      );
      expect(finalContent.first, {
        'custom': {
          'googleSearchCall': {
            'id': 'call_1725402',
            'arguments': {'queries': queries},
            'searchType': 'web_search',
          },
        },
        'metadata': {'thoughtSignature': 'sig_call'},
      });
      // Nothing at the deltas; each step's part (as in the final response)
      // when it stops.
      expect(chunks.sublist(0, 6), [
        <Object?>[],
        <Object?>[],
        [finalContent[0]],
        <Object?>[],
        <Object?>[],
        [finalContent[1]],
      ]);
      // Text still streams as it arrives.
      expect(chunks[10], [
        {'text': 'The 2026 Nobel Prize '},
      ]);
      expect(chunks[11], [
        {'text': 'in Physics...'},
      ]);
      expect(chunks[12], isEmpty);
      expect(chunks[13], isEmpty);
    });

    test('streams other built-in tool steps when they stop', () {
      final chunks = _chunksFor([
        _start(0, {
          'id': 'call_1',
          'type': 'url_context_call',
          'signature': '',
        }),
        _delta(0, {
          'type': 'url_context_call',
          'signature': 'sig_url',
          'arguments': {
            'urls': ['https://example.com'],
          },
        }),
        _stop(0),
        _start(1, {'id': 'proc_1', 'type': 'processing_call', 'signature': ''}),
        _delta(1, {'type': 'processing_call', 'signature': 'sig_proc'}),
        _stop(1),
      ]);
      expect(chunks, [
        <Object?>[],
        <Object?>[],
        [
          {
            'custom': {
              'urlContextCall': {
                'id': 'call_1',
                'arguments': {
                  'urls': ['https://example.com'],
                },
              },
            },
            'metadata': {'thoughtSignature': 'sig_url'},
          },
        ],
        <Object?>[],
        <Object?>[],
        [
          {
            'custom': {
              'processingCall': {'id': 'proc_1'},
            },
            'metadata': {'thoughtSignature': 'sig_proc'},
          },
        ],
      ]);
    });

    test('does not change the events it reads', () {
      // The final response is assembled from the same event objects.
      final startEvent = _start(0, {'id': 'c1', 'type': 'google_search_call'});
      _chunksFor([
        startEvent,
        _delta(0, {
          'type': 'google_search_call',
          'arguments': {
            'queries': ['q'],
          },
        }),
        _stop(0),
      ]);
      expect(startEvent.json, {
        'event_type': 'step.start',
        'index': 0,
        'step': {'id': 'c1', 'type': 'google_search_call'},
      });
    });
  });

  group('built-in tool steps round trip', () {
    // Steps as received live, with signatures. Each comes back as a custom
    // part and goes back into the history as the same step.
    final steps = <Map<String, Object?>>[
      {'id': 'call_481000', 'signature': 'sig1', 'type': 'file_search_call'},
      {
        'call_id': 'call_481000',
        'signature': 'sig2',
        'type': 'file_search_result',
      },
      // vertexAI Google Maps: no arguments, no signature.
      {'id': 'rxbackug', 'type': 'google_maps_call'},
      {
        'call_id': 'rxbackug',
        'type': 'google_maps_result',
        'result': [
          {
            'places': [
              {'place_id': 'ChIJefTaTQZD04kRzuh2lpwlV-A'},
            ],
          },
        ],
      },
      {
        'id': 'u1',
        'type': 'url_context_call',
        'arguments': {
          'urls': ['https://example.com'],
        },
        'signature': 'sig3',
      },
      {
        'call_id': 'u1',
        'type': 'url_context_result',
        'result': [
          {'url': 'https://example.com', 'status': 'success'},
        ],
        'is_error': false,
        'signature': 'sig4',
      },
      {
        'id': 'm1',
        'type': 'mcp_server_tool_call',
        'name': 'analyze',
        'server_name': 'docs',
        'arguments': {'x': 1},
      },
      {
        'call_id': 'm1',
        'type': 'mcp_server_tool_result',
        'name': 'analyze',
        'server_name': 'docs',
        'result': 'ok',
      },
      {
        'id': 'g1',
        'type': 'google_search_call',
        'arguments': {
          'queries': ['q'],
        },
        'search_type': 'web_search',
        'signature': 'sig5',
      },
      {
        'call_id': 'g1',
        'type': 'google_search_result',
        'result': [
          {'search_suggestions': '<div/>'},
        ],
        'is_error': false,
        'signature': 'sig6',
      },
      {
        'id': 'c1',
        'type': 'code_execution_call',
        'arguments': {'code': 'print(1)', 'language': 'PYTHON'},
        'signature': 'sig7',
      },
      {
        'call_id': 'c1',
        'type': 'code_execution_result',
        'result': '1',
        'signature': 'sig8',
      },
      {'id': 'p1', 'type': 'processing_call', 'signature': 'sig9'},
      {'call_id': 'p1', 'type': 'processing_result'},
    ];

    test('every step becomes one part and goes back unchanged', () {
      final parts = [
        for (final s in steps) ...fromInteractionStep(Step.fromJson(s)),
      ];
      expect(parts, hasLength(steps.length));
      final resent = toInteractionSteps([
        Message(role: Role.model, content: parts),
      ]);
      expect(_wire(resent), steps);
    });

    test('keeps the signature in metadata.thoughtSignature', () {
      final part = fromInteractionStep(Step.fromJson(steps.first)).single;
      expect(part.toJson(), {
        'custom': {
          'fileSearchCall': {'id': 'call_481000'},
        },
        'metadata': {'thoughtSignature': 'sig1'},
      });
    });

    test('an unknown step comes back as unknownStep', () {
      final step = {'type': 'retrieval_call', 'id': 'r1'};
      expect(_json(fromInteractionStep(Step.fromJson(step))), [
        {
          'custom': {'unknownStep': step},
        },
      ]);
    });

    test('a built-in tool part without its id throws', () {
      expect(
        () => toInteractionSteps([
          _message(Role.model, [
            {
              'custom': {'urlContextCall': <String, Object?>{}},
            },
          ]),
        ]),
        throwsA(
          isA<GenkitException>().having(
            (e) => e.status,
            'status',
            StatusCode.invalidArgument,
          ),
        ),
      );
    });
  });

  group('toInteractionSteps', () {
    test('sends a tool loop as steps, with signatures', () {
      final steps = toInteractionSteps([
        _message(Role.user, [
          {'text': 'Weather in Boston?'},
        ]),
        _message(Role.model, [
          {
            'reasoning': '',
            'metadata': {'thoughtSignature': 'sig_t'},
          },
          {
            'toolRequest': {
              'ref': 'call_1',
              'name': 'getWeather',
              'input': {'location': 'Boston'},
            },
            'metadata': {'thoughtSignature': 'sig_f'},
          },
        ]),
        _message(Role.tool, [
          {
            'toolResponse': {
              'ref': 'call_1',
              'name': 'getWeather',
              'output': '72 and sunny',
            },
          },
        ]),
      ]);
      expect(_wire(steps), [
        {
          'type': 'user_input',
          'content': [
            {'type': 'text', 'text': 'Weather in Boston?'},
          ],
        },
        {'type': 'thought', 'signature': 'sig_t'},
        {
          'type': 'function_call',
          'name': 'getWeather',
          'arguments': {'location': 'Boston'},
          'id': 'call_1',
          'signature': 'sig_f',
        },
        {
          'type': 'function_result',
          'name': 'getWeather',
          'call_id': 'call_1',
          'result': '72 and sunny',
        },
      ]);
    });

    test('wraps a non-object tool output in {result}', () {
      final steps = toInteractionSteps([
        _message(Role.tool, [
          {
            'toolResponse': {'ref': 'c', 'name': 'count', 'output': 3},
          },
        ]),
      ]);
      expect(_wire(steps).single, containsPair('result', {'result': 3}));
    });

    test('sends multipart tool output as text and image content', () {
      final steps = toInteractionSteps([
        _message(Role.tool, [
          {
            'toolResponse': {
              'ref': 'c',
              'name': 'chart',
              'output': {'title': 'Sales'},
              'content': [
                {
                  'media': {
                    'url': 'data:image/png;base64,AAAA',
                    'contentType': 'image/png',
                  },
                },
              ],
            },
          },
        ]),
      ]);
      expect((_wire(steps).single as Map)['result'], [
        {'type': 'text', 'text': '{"title":"Sales"}'},
        {'type': 'image', 'mime_type': 'image/png', 'data': 'AAAA'},
      ]);
    });

    test('sends Word and other document types as documents', () {
      // The server decides which document types it accepts (no client-side
      // list: that caused the "Unsupported media type" bug in JS 1.43).
      const docx =
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      final steps = toInteractionSteps([
        _message(Role.user, [
          {
            'media': {'url': 'data:$docx;base64,UEsDBA==', 'contentType': docx},
          },
          {
            'media': {
              'url': 'gs://bucket/notes.txt',
              'contentType': 'text/plain',
            },
          },
        ]),
      ]);
      expect((_wire(steps).single as Map)['content'], [
        {'type': 'document', 'mime_type': docx, 'data': 'UEsDBA=='},
        {
          'type': 'document',
          'mime_type': 'text/plain',
          'uri': 'gs://bucket/notes.txt',
        },
      ]);
    });

    test('sends a YouTube link as video and an unknown URI as a document', () {
      final steps = toInteractionSteps([
        _message(Role.user, [
          {
            'media': {'url': 'https://www.youtube.com/watch?v=abc'},
          },
          {
            'media': {'url': 'https://files.example/abc'},
          },
        ]),
      ]);
      expect((_wire(steps).single as Map)['content'], [
        {'type': 'video', 'uri': 'https://www.youtube.com/watch?v=abc'},
        {'type': 'document', 'uri': 'https://files.example/abc'},
      ]);
    });
  });

  group('fromInteractionSync', () {
    test('converts a live file-search response', () {
      // googleAI gemini-3.8-flash (JS file-search flow, Oct 23), shortened.
      final response = fromInteractionSync(
        GeminiInteraction.fromJson({
          'status': 'completed',
          'usage': {
            'total_tokens': 1101,
            'total_input_tokens': 48,
            'input_tokens_by_modality': [
              {'modality': 'text', 'tokens': 48},
            ],
            'total_output_tokens': 62,
            'total_tool_use_tokens': 908,
            'total_thought_tokens': 83,
            'grounding_tool_count': [
              {'type': 'google_search', 'count': 2},
            ],
          },
          'steps': [
            {'id': 'call_1', 'signature': 's1', 'type': 'file_search_call'},
            {
              'call_id': 'call_1',
              'signature': 's2',
              'type': 'file_search_result',
            },
            {'signature': 's3', 'type': 'thought'},
            {
              'type': 'model_output',
              'content': [
                {
                  'type': 'text',
                  'text': 'Elara.',
                  'annotations': [
                    {'type': 'file_citation', 'start_index': 0},
                  ],
                },
              ],
            },
          ],
          'model': 'gemini-3.8-flash',
        }),
      );
      expect(response.finishReason, FinishReason.stop);
      expect(response.message!.metadata, isNull); // not stored: no id
      expect(_json(response.message!.content), [
        {
          'custom': {
            'fileSearchCall': {'id': 'call_1'},
          },
          'metadata': {'thoughtSignature': 's1'},
        },
        {
          'custom': {
            'fileSearchResult': {'callId': 'call_1'},
          },
          'metadata': {'thoughtSignature': 's2'},
        },
        {
          'reasoning': '',
          'metadata': {'thoughtSignature': 's3'},
          'custom': {
            'thought': {'signature': 's3', 'type': 'thought'},
          },
        },
        {
          'text': 'Elara.',
          'metadata': {
            'annotations': [
              {'type': 'file_citation', 'start_index': 0},
            ],
          },
        },
      ]);
      expect(response.usage!.toJson(), {
        'inputTokens': 48,
        'outputTokens': 62,
        'totalTokens': 1101,
        'custom': {
          'inputTextTokens': 48,
          'toolUseTokens': 908,
          'googleSearchCount': 2,
        },
        'thoughtsTokens': 83,
      });
      expect(response.raw!['model'], 'gemini-3.8-flash');
    });

    test('carries the interaction id for store: true', () {
      final response = fromInteractionSync(
        GeminiInteraction.fromJson({'id': 'v1_abc', 'status': 'completed'}),
      );
      expect(response.message!.metadata, {'interactionId': 'v1_abc'});
    });

    test('turns a pending function call into a tool request', () {
      final response = fromInteractionSync(
        GeminiInteraction.fromJson({
          'status': 'requires_action',
          'steps': [
            {
              'type': 'function_call',
              'id': 'c1',
              'name': 'getWeather',
              'arguments': {'location': 'Boston'},
              'signature': 'sig',
            },
          ],
        }),
      );
      expect(_json(response.message!.content), [
        {
          'toolRequest': {
            'ref': 'c1',
            'name': 'getWeather',
            'input': {'location': 'Boston'},
          },
          'metadata': {'thoughtSignature': 'sig'},
        },
      ]);
    });

    test('maps incomplete to length and cancelled to aborted', () {
      final incomplete = fromInteractionSync(
        GeminiInteraction.fromJson({'status': 'incomplete'}),
      );
      expect(incomplete.finishReason, FinishReason.length);
      expect(
        incomplete.finishMessage,
        'Interaction incomplete (truncated output)',
      );
      final cancelled = fromInteractionSync(
        GeminiInteraction.fromJson({'status': 'cancelled'}),
      );
      expect(cancelled.finishReason, FinishReason.aborted);
      expect(cancelled.message!.text, 'Operation cancelled.');
    });

    test('returns blocked for a content-policy failure', () {
      final response = fromInteractionSync(
        GeminiInteraction.fromJson({
          'status': 'failed',
          'errors': [
            {'code': 'recitation', 'message': 'Recitation blocked.'},
          ],
          'usage': {'total_input_tokens': 7},
        }),
      );
      expect(response.finishReason, FinishReason.blocked);
      expect(response.finishMessage, 'Recitation blocked.');
      expect(response.usage!.inputTokens, 7);
    });

    test('throws with a mapped status for other failures', () {
      expect(
        () => fromInteractionSync(
          GeminiInteraction.fromJson({
            'status': 'failed',
            'errors': [
              {'code': 'malformed_function_call', 'message': 'bad call'},
            ],
          }),
        ),
        throwsA(
          isA<GenkitException>()
              .having((e) => e.status, 'status', StatusCode.aborted)
              .having(
                (e) => e.message,
                'message',
                'Interaction failed: [malformed_function_call] bad call',
              ),
        ),
      );
    });
  });

  group('request side', () {
    test('selectInteractionInput', () {
      final history = [
        _message(Role.user, [
          {'text': 'hi'},
        ]),
        Message(
          role: Role.model,
          content: [TextPart(text: 'hello')],
          metadata: {'interactionId': 'v1_prev'},
        ),
        _message(Role.user, [
          {'text': 'more'},
        ]),
      ];
      // Stateless: everything is sent.
      final stateless = selectInteractionInput(history, false);
      expect(stateless.messages, hasLength(3));
      expect(stateless.previousInteractionId, isNull);
      // Stored: only the new messages, continuing the last interaction.
      final stored = selectInteractionInput(history, true);
      expect(stored.messages, hasLength(1));
      expect(stored.previousInteractionId, 'v1_prev');
      // An explicit id needs store.
      expect(
        () => selectInteractionInput(history, false, 'v1_x'),
        throwsA(isA<GenkitException>()),
      );
      expect(
        selectInteractionInput(history, true, 'v1_x').previousInteractionId,
        'v1_x',
      );
    });

    group('toInteractionSafetySettings', () {
      GeminiSafetySettings setting(Map<String, dynamic> json) =>
          GeminiSafetySettings.fromJson(json);

      test('converts to lower-case types and thresholds', () {
        // The server rejects upper-case values with a 400 listing the
        // lower-case ones (seen live by the JS plugin on vertexAI).
        expect(
          toInteractionSafetySettings([
            setting({
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_LOW_AND_ABOVE',
            }),
            setting({
              'category': 'HARM_CATEGORY_HARASSMENT',
              'threshold': 'BLOCK_NONE',
            }),
          ])!.map((s) => s.json),
          [
            {'type': 'hate_speech', 'threshold': 'block_low_and_above'},
            {'type': 'harassment', 'threshold': 'block_none'},
          ],
        );
      });

      test('lower-cases method and passes other fields in snake_case', () {
        // The server rejects 'SEVERITY' with a 400 (JS review).
        expect(
          toInteractionSafetySettings([
            setting({
              'category': 'HARM_CATEGORY_HATE_SPEECH',
              'threshold': 'BLOCK_ONLY_HIGH',
              'method': 'SEVERITY',
              'someField': 1,
            }),
          ])!.single.json,
          {
            'some_field': 1,
            'type': 'hate_speech',
            'threshold': 'block_only_high',
            'method': 'severity',
          },
        );
      });

      test('leaves out HARM_CATEGORY_UNSPECIFIED', () {
        expect(
          toInteractionSafetySettings([
            setting({
              'category': 'HARM_CATEGORY_UNSPECIFIED',
              'threshold': 'BLOCK_ONLY_HIGH',
            }),
          ]),
          isNull,
        );
      });

      test('returns null when not set', () {
        expect(toInteractionSafetySettings(null), isNull);
      });
    });

    group('toInteractionConfigTool', () {
      test('throws if the tool is not a map', () {
        for (final tool in [
          'not-an-object',
          ['not-an-object'],
          null,
        ]) {
          expect(
            () => toInteractionConfigTool(tool),
            throwsA(
              isA<ArgumentError>().having(
                (e) => e.message,
                'message',
                contains('Invalid tool configuration'),
              ),
            ),
            reason: '$tool',
          );
        }
      });

      test('built-in tool settings in snake_case', () {
        expect(
          toInteractionConfigTool({
            'codeExecution': {'someProp': 123},
          }).json,
          {'type': 'code_execution', 'some_prop': 123},
        );
      });

      test('built-in tool with true', () {
        expect(toInteractionConfigTool({'codeExecution': true}).json, {
          'type': 'code_execution',
        });
      });

      test('throws for built-in tool settings of the wrong type', () {
        expect(
          () => toInteractionConfigTool({'codeExecution': 'invalid'}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Invalid configuration for codeExecution tool'),
            ),
          ),
        );
      });

      test('fileSearch store names must be a list of strings', () {
        expect(
          toInteractionConfigTool({
            'fileSearch': {
              'fileSearchStoreNames': ['store1'],
            },
          }).json,
          {
            'type': 'file_search',
            'file_search_store_names': ['store1'],
          },
        );
        expect(
          () => toInteractionConfigTool({
            'fileSearch': {'fileSearchStoreNames': 'store1'},
          }),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('fileSearchStoreNames must be an array of strings'),
            ),
          ),
        );
      });

      test('passes through other tools that name their type', () {
        expect(
          toInteractionConfigTool({
            'type': 'function',
            'name': 'myFunction',
            'parameters': {'type': 'object'},
          }).json,
          {
            'type': 'function',
            'name': 'myFunction',
            'parameters': {'type': 'object'},
          },
        );
      });

      test('throws for a tool with no known key and no type', () {
        expect(
          () => toInteractionConfigTool({'somethingElse': <String, Object?>{}}),
          throwsA(
            isA<ArgumentError>().having(
              (e) => e.message,
              'message',
              contains('Unsupported tool configuration'),
            ),
          ),
        );
      });

      test('passes through unknown settings of a built-in tool', () {
        expect(
          toInteractionConfigTool({
            'urlContext': {'myUrlParam': 1},
          }).json,
          {'type': 'url_context', 'my_url_param': 1},
        );
      });

      test('googleMaps, computerUse and retrieval keys', () {
        expect(
          toInteractionConfigTool({
            'googleMaps': {'enableWidget': true},
          }).json,
          {'type': 'google_maps', 'enable_widget': true},
        );
        expect(toInteractionConfigTool({'computerUse': true}).json, {
          'type': 'computer_use',
        });
        expect(
          toInteractionConfigTool({'retrieval': <String, Object?>{}}).json,
          {'type': 'retrieval'},
        );
      });

      test('mcpServer: a list of tool names becomes allowed_tools '
          'objects', () {
        expect(
          toInteractionConfigTool({
            'mcpServer': {
              'name': 'my-server',
              'url': 'https://mcp.example.com',
              'allowedTools': ['search', 'read_doc'],
            },
          }).json,
          {
            'type': 'mcp_server',
            'name': 'my-server',
            'url': 'https://mcp.example.com',
            'allowed_tools': [
              {
                'tools': ['search', 'read_doc'],
              },
            ],
          },
        );
      });
    });

    test('applyLatLngToGoogleMapsTools', () {
      final latLng = GeminiLatLng(latitude: 43.0896, longitude: -79.0849);
      final tools = [
        toInteractionConfigTool({'codeExecution': true}),
        toInteractionConfigTool({
          'googleMaps': {'enableWidget': true},
        }),
        // A location already on the tool is kept.
        toInteractionConfigTool({
          'googleMaps': {'latitude': 1, 'longitude': 2},
        }),
      ];
      expect(applyLatLngToGoogleMapsTools(tools, latLng), isTrue);
      expect(tools.map((t) => t.json), [
        {'type': 'code_execution'},
        {
          'type': 'google_maps',
          'enable_widget': true,
          'latitude': 43.0896,
          'longitude': -79.0849,
        },
        {'type': 'google_maps', 'latitude': 1, 'longitude': 2},
      ]);

      final noMaps = [
        toInteractionConfigTool({'codeExecution': true}),
      ];
      expect(applyLatLngToGoogleMapsTools(noMaps, latLng), isFalse);
      expect(noMaps.single.json, {'type': 'code_execution'});
    });

    test('toInteractionGenerationConfig maps thinking and speech config', () {
      final dropped = <String>[];
      final config = toInteractionGenerationConfig({
        'temperature': 0.5,
        'maxOutputTokens': 100,
        'thinkingConfig': {
          'thinkingLevel': 'HIGH',
          'includeThoughts': true,
          'thinkingBudget': 1024,
        },
        'speechConfig': {
          'voiceConfig': {
            'prebuiltVoiceConfig': {'voiceName': 'Puck'},
          },
        },
      }, dropped.add);
      expect(config.json, {
        'temperature': 0.5,
        'max_output_tokens': 100,
        'speech_config': [
          {'voice': 'Puck'},
        ],
        'thinking_level': 'high',
        'thinking_summaries': 'auto',
      });
      expect(dropped, ['thinkingConfig.thinkingBudget']);
    });

    test('toInteractionGenerationConfig keeps imageConfig out (sent as a '
        'response_format entry)', () {
      final config = toInteractionGenerationConfig({
        'imageConfig': {'aspectRatio': '16:9'},
        'temperature': 0.5,
      });
      expect(config.json, {'temperature': 0.5});
    });

    group('toInteractionResponseFormat', () {
      // Ported from the JS tests.
      test('returns null when nothing is set (server defaults apply)', () {
        expect(toInteractionResponseFormat(), isNull);
      });

      test('returns a single entry when there is one', () {
        expect(toInteractionResponseFormat(modalities: ['AUDIO']), {
          'type': 'audio',
        });
      });

      test('makes one entry per modality, in order', () {
        expect(toInteractionResponseFormat(modalities: ['TEXT', 'IMAGE']), [
          {'type': 'text'},
          {'type': 'image'},
        ]);
      });

      test('puts imageConfig on the image entry', () {
        expect(
          toInteractionResponseFormat(
            modalities: ['TEXT', 'IMAGE'],
            imageConfig: {'aspectRatio': '9:16', 'imageSize': '2K'},
          ),
          [
            {'type': 'text'},
            {'type': 'image', 'aspect_ratio': '9:16', 'image_size': '2K'},
          ],
        );
      });

      test('adds an image entry for imageConfig when no modalities are '
          'given', () {
        expect(
          toInteractionResponseFormat(imageConfig: {'aspectRatio': '1:1'}),
          {'type': 'image', 'aspect_ratio': '1:1'},
        );
      });

      test('puts audioFormat and videoFormat on their entries', () {
        expect(
          toInteractionResponseFormat(
            modalities: ['AUDIO'],
            audioFormat: {'mimeType': 'audio/l16', 'sampleRate': 24000},
          ),
          {'type': 'audio', 'mime_type': 'audio/l16', 'sample_rate': 24000},
        );
        expect(
          toInteractionResponseFormat(
            videoFormat: {'aspectRatio': '9:16', 'resolution': '1080p'},
          ),
          {'type': 'video', 'aspect_ratio': '9:16', 'resolution': '1080p'},
        );
      });

      test('puts JSON output on the text entry, alongside other entries', () {
        final schema = {
          'type': 'object',
          'properties': {
            'a': {'type': 'string'},
          },
        };
        expect(
          toInteractionResponseFormat(
            modalities: ['TEXT', 'IMAGE'],
            json: (schema: schema),
          ),
          [
            {'type': 'text', 'mime_type': 'application/json', 'schema': schema},
            {'type': 'image'},
          ],
        );
        // JSON output alone (no modalities): one text entry.
        expect(toInteractionResponseFormat(json: (schema: null)), {
          'type': 'text',
          'mime_type': 'application/json',
        });
      });

      test('keeps JSON output when audioFormat is set too', () {
        expect(
          toInteractionResponseFormat(
            audioFormat: {'mimeType': 'audio/wav'},
            json: (schema: null),
          ),
          [
            {'type': 'audio', 'mime_type': 'audio/wav'},
            {'type': 'text', 'mime_type': 'application/json'},
          ],
        );
      });
    });

    test('toInteractionSpeechConfig maps several speakers', () {
      expect(
        toInteractionSpeechConfig({
          'multiSpeakerVoiceConfig': {
            'speakerVoiceConfigs': [
              {
                'speaker': 'A',
                'voiceConfig': {
                  'prebuiltVoiceConfig': {'voiceName': 'Puck'},
                },
              },
            ],
          },
        }),
        {
          'speakers': [
            {'voice': 'Puck', 'speaker': 'A'},
          ],
        },
      );
    });

    test('toInteractionToolChoice', () {
      expect(
        toInteractionToolChoice(
          GeminiFunctionCallingConfig(
            mode: 'ANY',
            allowedFunctionNames: ['getWeather'],
          ),
        )!.json,
        {
          'allowed_tools': {
            'mode': 'any',
            'tools': ['getWeather'],
          },
        },
      );
      expect(toInteractionToolChoice(null, 'required')!.json, {
        'allowed_tools': {'mode': 'any'},
      });
      expect(
        toInteractionToolChoice(
          GeminiFunctionCallingConfig(mode: 'MODE_UNSPECIFIED'),
        ),
        isNull,
      );
    });

    test('toInteractionTool cleans the schema', () {
      final tool = toInteractionTool(
        ToolDefinition(
          name: 'getWeather',
          description: 'Weather',
          inputSchema: {
            r'$schema': 'x',
            'type': 'object',
            'additionalProperties': false,
            'properties': {
              'city': {
                'type': ['string', 'null'],
              },
            },
          },
        ),
      );
      expect(tool.json, {
        'type': 'function',
        'name': 'getWeather',
        'description': 'Weather',
        'parameters': {
          'type': 'object',
          'properties': {
            'city': {'type': 'string'},
          },
        },
      });
    });

    test('ensureToolIds fills in missing refs, in order', () {
      final messages = ensureToolIds([
        _message(Role.model, [
          {
            'toolRequest': {'name': 'a'},
          },
        ]),
        _message(Role.tool, [
          {
            'toolResponse': {'name': 'a', 'output': 1},
          },
          {
            'toolResponse': {'name': 'b', 'output': 2},
          },
        ]),
      ]);
      expect(messages[0].content.single.toolRequest!.ref, 'genkit-auto-id-0');
      expect(messages[1].content.map((p) => p.toolResponse!.ref).toList(), [
        'genkit-auto-id-0',
        'genkit-orphan-id-1',
      ]);
    });
  });

  group('interactionErrorCodeToGenkitStatus', () {
    test('maps known codes, HTTP codes, and nothing else', () {
      expect(
        interactionErrorCodeToGenkitStatus('rate_limit_exceeded'),
        StatusCode.resourceExhausted,
      );
      expect(
        interactionErrorCodeToGenkitStatus(' SAFETY '),
        StatusCode.failedPrecondition,
      );
      expect(interactionErrorCodeToGenkitStatus(503), StatusCode.unavailable);
      expect(interactionErrorCodeToGenkitStatus('404'), StatusCode.notFound);
      expect(interactionErrorCodeToGenkitStatus('something_new'), isNull);
      expect(interactionErrorCodeToGenkitStatus(418), isNull);
    });
  });
}
