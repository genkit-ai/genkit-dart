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

import 'dart:convert';
import 'dart:typed_data';

import 'package:genkit/genkit.dart';

/// Wraps the raw PCM audio returned by the Gemini TTS models in a WAV
/// container so that it becomes a playable audio file.
///
/// The Gemini TTS API returns audio as raw, headerless PCM (signed 16-bit,
/// little-endian) with an inline-data MIME type such as
/// `audio/L16;codec=pcm;rate=24000`. Without a container header this data
/// cannot be played by most audio players, so we prepend a standard 44-byte
/// WAV/RIFF header. This mirrors the `toWav` helper used in the Genkit JS
/// samples.
Media pcmMediaToWav(Media media) {
  final url = media.url;
  // Extract the base64 payload from the data URL.
  final commaIndex = url.indexOf(',');
  final base64Data = commaIndex >= 0 ? url.substring(commaIndex + 1) : url;
  final pcmBytes = base64Decode(base64Data);

  // Derive the sample rate from the MIME type (e.g. `...;rate=24000`),
  // defaulting to 24000 Hz which is what the Gemini TTS models use.
  var sampleRate = 24000;
  final contentType = media.contentType ?? '';
  final rateMatch = RegExp(r'rate=(\d+)').firstMatch(contentType);
  if (rateMatch != null) {
    sampleRate = int.parse(rateMatch.group(1)!);
  }

  final wavBytes = _pcmToWav(
    pcmBytes,
    channels: 1,
    sampleRate: sampleRate,
    bitsPerSample: 16,
  );

  return Media(
    url: 'data:audio/wav;base64,${base64Encode(wavBytes)}',
    contentType: 'audio/wav',
  );
}

/// Builds a WAV (RIFF) byte buffer from raw little-endian PCM samples.
Uint8List _pcmToWav(
  Uint8List pcmData, {
  required int channels,
  required int sampleRate,
  required int bitsPerSample,
}) {
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  final blockAlign = channels * (bitsPerSample ~/ 8);
  final dataSize = pcmData.length;
  final fileSize = 36 + dataSize;

  final builder = BytesBuilder();

  void writeString(String value) {
    builder.add(ascii.encode(value));
  }

  void writeUint32(int value) {
    final b = ByteData(4)..setUint32(0, value, Endian.little);
    builder.add(b.buffer.asUint8List());
  }

  void writeUint16(int value) {
    final b = ByteData(2)..setUint16(0, value, Endian.little);
    builder.add(b.buffer.asUint8List());
  }

  // RIFF header.
  writeString('RIFF');
  writeUint32(fileSize);
  writeString('WAVE');

  // fmt subchunk.
  writeString('fmt ');
  writeUint32(16); // Subchunk1Size for PCM.
  writeUint16(1); // AudioFormat = PCM.
  writeUint16(channels);
  writeUint32(sampleRate);
  writeUint32(byteRate);
  writeUint16(blockAlign);
  writeUint16(bitsPerSample);

  // data subchunk.
  writeString('data');
  writeUint32(dataSize);
  builder.add(pcmData);

  return builder.toBytes();
}
