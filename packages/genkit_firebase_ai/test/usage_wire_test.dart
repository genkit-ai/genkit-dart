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

import 'package:flutter_test/flutter_test.dart';

import 'wire_harness.dart';

const _usageMetadata = {
  'promptTokenCount': 11,
  'candidatesTokenCount': 22,
  'totalTokenCount': 90,
  'thoughtsTokenCount': 33,
  'cachedContentTokenCount': 7,
  'toolUsePromptTokenCount': 17,
};

void main() {
  setUpAll(setUpFirebaseApp);

  test('generate maps every usage token count', () async {
    final client = WireClient(
      response: {...textResponse('hi'), 'usageMetadata': _usageMetadata},
    );

    final response = await wireModel(client)(userRequest('hello'));

    final usage = response.usage!;
    expect(usage.inputTokens, 11);
    expect(usage.outputTokens, 22);
    expect(usage.totalTokens, 90);
    expect(usage.thoughtsTokens, 33);
    expect(usage.cachedContentTokens, 7);
    expect(usage.custom, {'toolUsePromptTokenCount': 17});
  });

  test('streaming generate keeps usage sent only on the final '
      'chunk', () async {
    final client = WireClient(
      streamChunks: [
        textResponse('Hello, ', finishReason: null),
        {...textResponse('world'), 'usageMetadata': _usageMetadata},
      ],
    );

    final response = await wireModel(client)(
      userRequest('hello'),
      onChunk: (_) {},
    );

    final usage = response.usage!;
    expect(usage.inputTokens, 11);
    expect(usage.outputTokens, 22);
    expect(usage.totalTokens, 90);
    expect(usage.thoughtsTokens, 33);
    expect(usage.cachedContentTokens, 7);
    expect(usage.custom, {'toolUsePromptTokenCount': 17});
  });

  test('generate without usageMetadata has no usage', () async {
    final client = WireClient(response: textResponse('hi'));

    final response = await wireModel(client)(userRequest('hello'));

    expect(response.usage, isNull);
  });

  test('usage without optional counts leaves them unset', () async {
    final client = WireClient(
      response: {
        ...textResponse('hi'),
        'usageMetadata': {'promptTokenCount': 3, 'totalTokenCount': 3},
      },
    );

    final response = await wireModel(client)(userRequest('hello'));

    final usage = response.usage!;
    expect(usage.inputTokens, 3);
    expect(usage.thoughtsTokens, isNull);
    expect(usage.cachedContentTokens, isNull);
    expect(usage.custom, isNull);
  });
}
