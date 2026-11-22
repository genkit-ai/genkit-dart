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

import 'package:genkit/genkit.dart' hide Score;
import 'package:genkit_systemone/src/protocol/json.dart';
import 'package:genkit_systemone/src/protocol/state.dart';
import 'package:test/test.dart';

Message user(List<Part> parts) => Message(role: Role.user, content: parts);
Message model(List<Part> parts) => Message(role: Role.model, content: parts);
Message system(String text) => Message(
  role: Role.system,
  content: [TextPart(text: text)],
);
Part text(String t) => TextPart(text: t);
Part media(String url, [String? contentType]) => MediaPart(
  media: Media(url: url, contentType: contentType),
);

BuiltState build(
  List<Message> messages, {
  List<DocumentData>? docs,
  bool stateJson = false,
  Reads reads = const Reads(),
}) => buildState(
  ModelRequest(messages: messages, docs: docs),
  stateJson: stateJson,
  reads: reads,
);

Matcher throwsInvalid(Object message) => throwsA(
  isA<GenkitException>()
      .having((e) => e.status, 'status', StatusCode.invalidArgument)
      .having((e) => e.message, 'message', message),
);

void main() {
  group('system preamble', () {
    test('joins the system messages and leaves output instructions out', () {
      expect(
        systemPreamble([
          system(' The state is a ticket. '),
          user([text('hi')]),
          Message(
            role: Role.system,
            content: [
              TextPart(text: 'Plan names are fields.'),
              TextPart(
                text: 'Output should be JSON',
                metadata: {'purpose': 'output'},
              ),
            ],
          ),
        ]),
        'The state is a ticket.\n\nPlan names are fields.',
      );
    });

    test('refuses a part that is not text', () {
      expect(
        () => systemPreamble([
          Message(
            role: Role.system,
            content: [
              DataPart(data: {'a': 1}),
            ],
          ),
        ]),
        throwsInvalid(contains('a data part cannot be instructions')),
      );
    });
  });

  group('state', () {
    test('one message is its value, and a system message is not state', () {
      expect(
        build([
          system('Rules'),
          user([text('ticket')]),
        ]).state,
        'ticket',
      );
      expect(
        build([
          user([
            DataPart(data: {'ticket': 'x', 'tier': 'pro'}),
          ]),
        ]).state,
        {'ticket': 'x', 'tier': 'pro'},
      );
      expect(
        build([
          user([text('a'), text('b')]),
        ]).state,
        ['a', 'b'],
      );
    });

    test('a data part with a null value is dropped, as in Go', () {
      expect(
        build([
          user([
            text('a'),
            Part.fromJson({'data': null}),
          ]),
        ]).state,
        'a',
      );
      // A turn with nothing left is skipped.
      expect(
        build([
          user([text('a')]),
          model([
            Part.fromJson({'data': null}),
          ]),
        ]).state,
        'a',
      );
      expect(
        () => build([
          user([
            Part.fromJson({'data': null}),
          ]),
        ]),
        throwsInvalid(contains('the request carries no state')),
      );
    });

    test('several messages are role and content records', () {
      expect(
        build([
          user([text('hi')]),
          model([text('hello')]),
        ]).state,
        [
          {'role': 'user', 'content': 'hi'},
          {'role': 'model', 'content': 'hello'},
        ],
      );
    });

    test('documents make an object of messages and context', () {
      final state = build(
        [
          user([text('How long do refunds take?')]),
        ],
        docs: [
          DocumentData(content: [text('Refunds take five days.')]),
          DocumentData(
            content: [text('Shipping is free.')],
            metadata: {'title': 'Shipping'},
          ),
        ],
      ).state;
      expect(state, {
        'messages': [
          {'role': 'user', 'content': 'How long do refunds take?'},
        ],
        'context': [
          'Refunds take five days.',
          {
            'content': 'Shipping is free.',
            'metadata': {'title': 'Shipping'},
          },
        ],
      });
    });

    test('stateJSON keeps the JSON verbatim, big integers included', () {
      final state = build([
        user([text(' {"id": 12345678901234567890123} ')]),
      ], stateJson: true).state;
      expect(state, isA<RawJson>());
      expect(
        encodeJson({'state': state}),
        '{"state":{"id": 12345678901234567890123}}',
      );
      expect(
        () => build([
          user([text('not json')]),
        ], stateJson: true),
        throwsInvalid(contains('stateJSON is set but the text is not JSON')),
      );
    });

    test('output instructions in a history are skipped', () {
      expect(
        build([
          user([
            text('ticket'),
            TextPart(text: 'Output JSON', metadata: {'purpose': 'output'}),
          ]),
        ]).state,
        'ticket',
      );
    });

    test('tool and reasoning parts are refused', () {
      expect(
        () => build([
          model([ToolRequestPart(toolRequest: ToolRequest(name: 'lookup'))]),
        ]),
        throwsInvalid(contains('a tool request part cannot be state')),
      );
      expect(
        () => build([
          model([ReasoningPart(reasoning: 'hmm')]),
        ]),
        throwsInvalid(contains('a reasoning part cannot be state')),
      );
    });

    test('a request with no state is refused', () {
      expect(
        () => build([system('Rules only')]),
        throwsInvalid(contains('the request carries no state')),
      );
    });
  });

  group('media', () {
    const reads = Reads(images: true, audio: true, video: true);

    test('goes in its field by kind, messages first, documents after', () {
      final built = build(
        [
          user([
            text('Look'),
            media('data:image/png;base64,AAA'),
            media('data:audio/wav;base64,BBB'),
          ]),
        ],
        docs: [
          DocumentData(content: [media('data:video/mp4;base64,CCC')]),
          DocumentData(content: [media('data:image/jpeg;base64,DDD')]),
        ],
        reads: reads,
      );
      // A document of media alone contributes nothing beside its media.
      expect(built.state, 'Look');
      expect(built.media.images, [
        'data:image/png;base64,AAA',
        'data:image/jpeg;base64,DDD',
      ]);
      expect(built.media.audio, ['data:audio/wav;base64,BBB']);
      expect(built.media.videos, ['data:video/mp4;base64,CCC']);
    });

    test('a message of media alone is a turn with empty text', () {
      final built = build([
        user([media('data:image/png;base64,AAA')]),
        model([text('A photo')]),
      ], reads: reads);
      expect(built.state, [
        {'role': 'user', 'content': ''},
        {'role': 'model', 'content': 'A photo'},
      ]);
      expect(
        build([
          user([media('data:image/png;base64,AAA')]),
        ], reads: reads).state,
        '',
      );
    });

    test('percent-encoded data is encoded as base64 under the part type', () {
      final built = build([
        user([media('DATA:text/plain,a%20b', 'IMAGE/SVG+XML')]),
      ], reads: reads);
      expect(built.media.images, ['data:image/svg+xml;base64,YSBi']);
    });

    test('an escape that is not two hex digits is refused', () {
      for (final url in [
        'data:image/png,%-1',
        'data:image/png,%+F',
        'data:image/png,%g0',
      ]) {
        expect(
          () => build([
            user([media(url)]),
          ], reads: reads),
          throwsInvalid(contains('invalid URL escape')),
          reason: url,
        );
      }
    });

    test('a kind the model does not read is refused', () {
      expect(
        () => build([
          user([text('x'), media('data:audio/wav;base64,AAA')]),
        ], reads: const Reads(images: true)),
        throwsInvalid(contains('the model reads no audio/wav media')),
      );
      expect(
        () => build([
          user([media('data:application/pdf;base64,AAA')]),
        ], reads: reads),
        throwsInvalid(contains('is not an image, audio, or video')),
      );
    });

    test('a URL is refused rather than fetched, and never echoed', () {
      for (final url in [
        'https://example.com/a.png?token=secret',
        'HTTPS://example.com/a.png?token=secret',
        'gs://example.com/a.png',
      ]) {
        expect(
          () => build([
            user([media(url, 'image/png')]),
          ], reads: reads),
          throwsInvalid(
            allOf(
              contains('take inline media only'),
              isNot(contains('example.com')),
              isNot(contains('secret')),
            ),
          ),
          reason: url,
        );
      }
    });

    test('the scheme and the base64 token are read without case', () {
      final built = build([
        user([media('DATA:image/PNG;BASE64,AAA')]),
      ], reads: reads);
      expect(built.media.images, ['data:image/png;base64,AAA']);
    });
  });
}
