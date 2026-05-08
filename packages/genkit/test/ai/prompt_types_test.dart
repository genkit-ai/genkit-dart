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

import 'package:dotprompt/dotprompt.dart' as dp;
import 'package:genkit/genkit.dart';
import 'package:genkit/src/ai/prompt_types.dart';
import 'package:test/test.dart';

void main() {
  group('prompt_types', () {
    group('dpRoleToGenkitRole', () {
      test('converts user role', () {
        expect(dpRoleToGenkitRole(dp.Role.user), equals(Role.user));
      });

      test('converts model role', () {
        expect(dpRoleToGenkitRole(dp.Role.model), equals(Role.model));
      });

      test('converts system role', () {
        expect(dpRoleToGenkitRole(dp.Role.system), equals(Role.system));
      });

      test('converts tool role', () {
        expect(dpRoleToGenkitRole(dp.Role.tool), equals(Role.tool));
      });
    });

    group('genkitRoleToDpRole', () {
      test('converts user role', () {
        expect(genkitRoleToDpRole(Role.user), equals(dp.Role.user));
      });

      test('converts model role', () {
        expect(genkitRoleToDpRole(Role.model), equals(dp.Role.model));
      });

      test('converts system role', () {
        expect(genkitRoleToDpRole(Role.system), equals(dp.Role.system));
      });

      test('converts tool role', () {
        expect(genkitRoleToDpRole(Role.tool), equals(dp.Role.tool));
      });
    });

    group('dpPartToGenkitPart', () {
      test('converts TextPart', () {
        final dpPart = dp.TextPart(text: 'Hello world');
        final genkitPart = dpPartToGenkitPart(dpPart);

        expect(genkitPart, isA<TextPart>());
        expect(genkitPart.toJson()['text'], equals('Hello world'));
      });

      test('converts MediaPart with url', () {
        final dpPart = dp.MediaPart(
          media: dp.MediaContent(
            contentType: 'image/png',
            url: 'https://example.com/image.png',
          ),
        );
        final genkitPart = dpPartToGenkitPart(dpPart);

        expect(genkitPart, isA<MediaPart>());
        final mediaPart = genkitPart as MediaPart;
        expect(mediaPart.media.contentType, equals('image/png'));
        expect(mediaPart.media.url, equals('https://example.com/image.png'));
      });

      test('converts ToolRequestPart', () {
        final dpPart = dp.ToolRequestPart(
          toolRequest: dp.ToolRequest(
            name: 'myTool',
            ref: 'ref123',
            input: {'key': 'value'},
          ),
        );
        final genkitPart = dpPartToGenkitPart(dpPart);

        expect(genkitPart, isA<ToolRequestPart>());
        final trPart = genkitPart as ToolRequestPart;
        expect(trPart.toolRequest.name, equals('myTool'));
        expect(trPart.toolRequest.ref, equals('ref123'));
        expect(trPart.toolRequest.input, equals({'key': 'value'}));
      });

      test('converts ToolResponsePart', () {
        final dpPart = dp.ToolResponsePart(
          toolResponse: dp.ToolResponse(
            name: 'myTool',
            ref: 'ref123',
            output: {'result': 42},
          ),
        );
        final genkitPart = dpPartToGenkitPart(dpPart);

        expect(genkitPart, isA<ToolResponsePart>());
        final trPart = genkitPart as ToolResponsePart;
        expect(trPart.toolResponse.name, equals('myTool'));
        expect(trPart.toolResponse.ref, equals('ref123'));
        expect(trPart.toolResponse.output, equals({'result': 42}));
      });

      test('converts DataPart', () {
        final dpPart = dp.DataPart(data: {'custom': 'data'});
        final genkitPart = dpPartToGenkitPart(dpPart);

        expect(genkitPart, isA<DataPart>());
        expect(
          (genkitPart as DataPart).data,
          equals({'custom': 'data'}),
        );
      });
    });

    group('dpMessageToGenkitMessage', () {
      test('converts a simple user message', () {
        final dpMsg = dp.Message(
          role: dp.Role.user,
          content: [dp.TextPart(text: 'Hello')],
        );
        final genkitMsg = dpMessageToGenkitMessage(dpMsg);

        expect(genkitMsg.role, equals(Role.user));
        expect(genkitMsg.content.length, equals(1));
        expect(genkitMsg.content[0].toJson()['text'], equals('Hello'));
      });

      test('converts a model message with multiple parts', () {
        final dpMsg = dp.Message(
          role: dp.Role.model,
          content: [
            dp.TextPart(text: 'Part 1'),
            dp.TextPart(text: 'Part 2'),
          ],
        );
        final genkitMsg = dpMessageToGenkitMessage(dpMsg);

        expect(genkitMsg.role, equals(Role.model));
        expect(genkitMsg.content.length, equals(2));
        expect(genkitMsg.content[0].toJson()['text'], equals('Part 1'));
        expect(genkitMsg.content[1].toJson()['text'], equals('Part 2'));
      });

      test('preserves metadata', () {
        final dpMsg = dp.Message(
          role: dp.Role.user,
          content: [dp.TextPart(text: 'Hello')],
          metadata: {'key': 'value'},
        );
        final genkitMsg = dpMessageToGenkitMessage(dpMsg);

        expect(genkitMsg.metadata, equals({'key': 'value'}));
      });
    });

    group('genkitMessageToDpMessage', () {
      test('converts a simple user message', () {
        final genkitMsg = Message(
          role: Role.user,
          content: [TextPart(text: 'Hello')],
        );
        final dpMsg = genkitMessageToDpMessage(genkitMsg);

        expect(dpMsg.role, equals(dp.Role.user));
        expect(dpMsg.content.length, equals(1));
        expect((dpMsg.content[0] as dp.TextPart).text, equals('Hello'));
      });

      test('converts a system message', () {
        final genkitMsg = Message(
          role: Role.system,
          content: [TextPart(text: 'System instruction')],
        );
        final dpMsg = genkitMessageToDpMessage(genkitMsg);

        expect(dpMsg.role, equals(dp.Role.system));
      });
    });

    group('genkitPartToDpPart', () {
      test('converts TextPart', () {
        final genkitPart = TextPart(text: 'Hello');
        final dpPart = genkitPartToDpPart(genkitPart);

        expect(dpPart, isA<dp.TextPart>());
        expect((dpPart as dp.TextPart).text, equals('Hello'));
      });

      test('converts MediaPart', () {
        final genkitPart = MediaPart(
          media: Media(
            contentType: 'image/jpeg',
            url: 'https://example.com/img.jpg',
          ),
        );
        final dpPart = genkitPartToDpPart(genkitPart);

        expect(dpPart, isA<dp.MediaPart>());
        final mp = dpPart as dp.MediaPart;
        expect(mp.media.contentType, equals('image/jpeg'));
        expect(mp.media.url, equals('https://example.com/img.jpg'));
      });

      test('converts ToolRequestPart', () {
        final genkitPart = ToolRequestPart(
          toolRequest: ToolRequest(
            name: 'search',
            ref: 'ref1',
            input: {'query': 'dart'},
          ),
        );
        final dpPart = genkitPartToDpPart(genkitPart);

        expect(dpPart, isA<dp.ToolRequestPart>());
        final trp = dpPart as dp.ToolRequestPart;
        expect(trp.toolRequest.name, equals('search'));
      });

      test('converts ToolResponsePart', () {
        final genkitPart = ToolResponsePart(
          toolResponse: ToolResponse(
            name: 'search',
            ref: 'ref1',
            output: 'results here',
          ),
        );
        final dpPart = genkitPartToDpPart(genkitPart);

        expect(dpPart, isA<dp.ToolResponsePart>());
      });
    });

    group('roundtrip conversions', () {
      test('message roundtrip preserves data', () {
        final original = Message(
          role: Role.user,
          content: [
            TextPart(text: 'Hello world'),
          ],
        );

        final dpMsg = genkitMessageToDpMessage(original);
        final roundtripped = dpMessageToGenkitMessage(dpMsg);

        expect(roundtripped.role, equals(original.role));
        expect(roundtripped.content.length, equals(original.content.length));
        expect(
          roundtripped.content[0].toJson()['text'],
          equals(original.content[0].toJson()['text']),
        );
      });

      test('role roundtrip for all roles', () {
        for (final role in [Role.user, Role.model, Role.system, Role.tool]) {
          final dpRole = genkitRoleToDpRole(role);
          final roundtripped = dpRoleToGenkitRole(dpRole);
          expect(roundtripped, equals(role));
        }
      });
    });
  });
}
