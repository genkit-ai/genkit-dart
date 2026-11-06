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

// Audio helpers for Interactions TTS responses. Ported from the JS tests
// (tests/common/interaction-converters_test.ts and tests/googleai/
// utils_test.ts).

import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/src/interaction_converters.dart';
import 'package:test/test.dart';

/// An ID3v2.3 tag shaped like the one seen live: header
/// `49 44 33 03 00 00 00 00 2f 63` (size 6,115, so 6,125 bytes in total),
/// then a GEOB frame. The frame body is filler here.
Uint8List _id3Tag() {
  final tag = Uint8List(6125)..fillRange(0, 6125, 0x55);
  tag.setAll(0, [0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x2f, 0x63]);
  tag.setAll(10, ascii.encode('GEOB'));
  return tag;
}

/// A WAV file shaped like the ones the TTS models return: a canonical
/// 44-byte header, the `data` chunk, then another chunk after the audio.
Uint8List _wav(List<int> audio, [List<int> trailing = const [9, 9, 9, 9]]) {
  final header = ByteData(44);
  void ascii4(int offset, String s) {
    for (var i = 0; i < 4; i++) {
      header.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii4(0, 'RIFF');
  ascii4(8, 'WAVE');
  ascii4(12, 'fmt ');
  header
    ..setUint32(16, 16, Endian.little)
    ..setUint16(20, 1, Endian.little) // PCM
    ..setUint16(22, 1, Endian.little) // mono
    ..setUint32(24, 24000, Endian.little)
    ..setUint32(28, 48000, Endian.little)
    ..setUint16(32, 2, Endian.little)
    ..setUint16(34, 16, Endian.little);
  ascii4(36, 'data');
  header.setUint32(40, audio.length, Endian.little);
  final extraHeader = ByteData(8);
  for (var i = 0; i < 4; i++) {
    extraHeader.setUint8(i, 'LIST'.codeUnitAt(i));
  }
  extraHeader.setUint32(4, trailing.length, Endian.little);
  final wav = Uint8List.fromList([
    ...header.buffer.asUint8List(),
    ...audio,
    ...extraHeader.buffer.asUint8List(),
    ...trailing,
  ]);
  ByteData.sublistView(wav).setUint32(4, wav.length - 8, Endian.little);
  return wav;
}

Part _audioPart(List<int> bytes, [String contentType = 'audio/l16']) =>
    MediaPart(
      media: Media(
        url: 'data:$contentType;base64,${base64Encode(bytes)}',
        contentType: contentType,
      ),
    );

Uint8List _decode(Part part) {
  final url = part.media!.url;
  return base64Decode(url.substring(url.indexOf(',') + 1));
}

int _u32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);

void main() {
  group('stripLeadingId3Tags', () {
    test('removes a leading ID3 tag and keeps the audio after it', () {
      final pcm = Uint8List(5760)..fillRange(0, 5760, 0x07);
      final result = stripLeadingId3Tags(
        Uint8List.fromList([..._id3Tag(), ...pcm]),
      );
      expect(result, pcm);
    });

    test('removes several tags in a row', () {
      final result = stripLeadingId3Tags(
        Uint8List.fromList([..._id3Tag(), ..._id3Tag(), 1, 2]),
      );
      expect(result, [1, 2]);
    });

    test('returns audio without a tag unchanged', () {
      final pcm = Uint8List.fromList([0xf8, 0xff, 0xf9, 0xff]);
      expect(stripLeadingId3Tags(pcm), same(pcm));
    });

    test('keeps audio that only starts with the letters "ID3"', () {
      // A size byte of 0x80 or more can't be a real tag header.
      final notATag = Uint8List.fromList([
        0x49, 0x44, 0x33, 0x03, 0x00, 0x00, 0x00, 0x00, 0x80, 0x00, 1, 2, //
      ]);
      expect(stripLeadingId3Tags(notATag), same(notATag));
    });

    test('keeps the bytes if the tag would run past the end', () {
      final truncated = Uint8List.sublistView(_id3Tag(), 0, 100);
      expect(stripLeadingId3Tags(truncated), same(truncated));
    });
  });

  group('appendToWavData', () {
    test('inserts the audio at the end of the data chunk and fixes the '
        'sizes', () {
      final result = appendToWavData(
        _wav([1, 2]),
        Uint8List.fromList([3, 4, 5, 6]),
      )!;
      expect(_u32(result, 4), result.length - 8);
      expect(_u32(result, 40), 6);
      expect(result.sublist(44, 50), [1, 2, 3, 4, 5, 6]);
      // The chunk after `data` is kept, after the audio.
      expect(ascii.decode(result.sublist(50, 54)), 'LIST');
      expect(result.sublist(58), [9, 9, 9, 9]);
    });

    test('returns null for data that is not a WAV file', () {
      expect(
        appendToWavData(
          Uint8List.fromList(ascii.encode('not a wav file')),
          Uint8List.fromList([1]),
        ),
        isNull,
      );
    });

    test('returns null for a WAV without a data chunk', () {
      final noData = Uint8List.fromList(_wav([1, 2]).sublist(0, 36));
      ByteData.sublistView(
        noData,
      ).setUint32(4, noData.length - 8, Endian.little);
      expect(appendToWavData(noData, Uint8List.fromList([1])), isNull);
    });
  });

  _audioPartTests();
}

void _audioPartTests() {
  group('removeId3FromAudio', () {
    test('removes the tag and keeps the audio after it', () {
      final pcm = List.filled(5760, 0x07);
      final result = removeId3FromAudio(_audioPart([..._id3Tag(), ...pcm]));
      expect(result.media?.contentType, 'audio/l16');
      expect(_decode(result), pcm);
    });

    test('leaves chunks without a tag, and other parts, unchanged', () {
      final pcm = _audioPart([1, 2, 3, 4]);
      expect(removeId3FromAudio(pcm), same(pcm));
      final text = TextPart(text: 'hi');
      expect(removeId3FromAudio(text), same(text));
    });

    test('only changes headerless audio types', () {
      final wav = _audioPart([..._id3Tag(), 1, 2], 'audio/wav');
      expect(removeId3FromAudio(wav), same(wav));
    });
  });

  group('mergeStreamedAudio', () {
    test('joins audio/l16 chunks into one audio/l16 part', () {
      final result = mergeStreamedAudio([
        _audioPart([1, 2]),
        _audioPart([3, 4]),
        _audioPart([5, 6]),
      ]);
      expect(result, hasLength(1));
      expect(result[0].media?.contentType, 'audio/l16');
      expect(_decode(result[0]), [1, 2, 3, 4, 5, 6]);
    });

    test('keeps the requested headerless format', () {
      for (final type in ['audio/mulaw', 'audio/alaw']) {
        final result = mergeStreamedAudio([
          _audioPart([1], type),
          _audioPart([2], type),
        ]);
        expect(result, hasLength(1));
        expect(result[0].media?.contentType, type);
        expect(_decode(result[0]), [1, 2]);
      }
    });

    test('keeps content type parameters such as rate', () {
      const type = 'audio/L16;rate=16000';
      final result = mergeStreamedAudio([
        _audioPart([1], type),
        _audioPart([2], type),
      ]);
      expect(result[0].media?.contentType, type);
    });

    test('does not join chunks of different types', () {
      final result = mergeStreamedAudio([
        _audioPart([1], 'audio/l16'),
        _audioPart([2], 'audio/mulaw'),
      ]);
      expect(result, hasLength(2));
    });

    test('puts the audio/l16 chunks of a streamed WAV into one WAV', () {
      final result = mergeStreamedAudio([
        _audioPart(_wav([1, 2]), 'audio/wav'),
        _audioPart([3, 4]),
        _audioPart([5, 6]),
      ]);
      expect(result, hasLength(1));
      expect(result[0].media?.contentType, 'audio/wav');
      final wav = _decode(result[0]);
      expect(_u32(wav, 4), wav.length - 8);
      expect(_u32(wav, 40), 6);
      expect(wav.sublist(44, 50), [1, 2, 3, 4, 5, 6]);
      expect(ascii.decode(wav.sublist(50, 54)), 'LIST');
    });

    test('leaves a WAV without following chunks unchanged', () {
      final wav = _audioPart(_wav([1, 2]), 'audio/wav');
      expect(mergeStreamedAudio([wav]), [same(wav)]);
    });

    test('leaves media typed audio/wav that is not a WAV file unchanged', () {
      final notWav = _audioPart([1, 2], 'audio/wav');
      final pcm = _audioPart([3, 4]);
      expect(mergeStreamedAudio([notWav, pcm]), [same(notWav), same(pcm)]);
    });

    test('leaves other parts alone and joins each run separately', () {
      final text = TextPart(text: 'hello');
      final result = mergeStreamedAudio([
        _audioPart([1, 2]),
        _audioPart([3, 4]),
        text,
        _audioPart([5, 6]),
      ]);
      expect(result, hasLength(3));
      expect(_decode(result[0]), [1, 2, 3, 4]);
      expect(result[1], same(text));
      expect(_decode(result[2]), [5, 6]);
    });

    test('returns parts without audio unchanged', () {
      final parts = [TextPart(text: 'a'), TextPart(text: 'b')];
      expect(mergeStreamedAudio(parts), [same(parts[0]), same(parts[1])]);
    });
  });
}
