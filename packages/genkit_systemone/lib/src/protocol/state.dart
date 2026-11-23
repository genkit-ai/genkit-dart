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

/// The state a decision model evaluates, built from a request's messages and
/// documents, and the media that goes beside it.
library;

import 'dart:convert';

import 'package:genkit/plugin.dart';

import 'json.dart';

GenkitException _invalidArgument(String message) =>
    GenkitException('systemone: $message', status: StatusCode.invalidArgument);

/// Gathers the system messages into the text that goes in front of every
/// question's instructions.
///
/// The model has no system role: the state is what it evaluates and the
/// questions are what it is told, so a system message belongs with the
/// questions, never in the state. Only text can be instructions; loop
/// plumbing left in a history is skipped.
String systemPreamble(List<Message> messages) {
  final texts = <String>[];
  for (final msg in messages) {
    if (msg.role != Role.system) continue;
    final sb = StringBuffer();
    for (final part in msg.content) {
      if (_isFormatInstructions(part)) continue;
      if (!part.isText) {
        throw _invalidArgument(
          'a ${_partKindName(part)} part cannot be instructions; a system '
          'message is text only',
        );
      }
      sb.write(part.text);
    }
    final text = sb.toString().trim();
    if (text.isNotEmpty) texts.add(text);
  }
  return texts.join('\n\n');
}

/// Which kinds of media a model reads besides text and JSON.
final class Reads {
  const Reads({this.images = false, this.audio = false, this.video = false});

  final bool images;
  final bool audio;
  final bool video;

  bool get any => images || audio || video;
}

/// The media a request carries, as base64 data URLs by kind, each in the
/// order its parts appear, messages first and documents after.
///
/// Media is an extension some servers make to the protocol, in the images,
/// audio, and videos fields.
final class RequestMedia {
  final List<String> images = [];
  final List<String> audio = [];
  final List<String> videos = [];

  int get length => images.length + audio.length + videos.length;
}

/// The state and the media of a request.
typedef BuiltState = ({Object? state, RequestMedia media});

/// Turns the request into the state and the media: one message as its value,
/// several as `{role, content}` records, and with documents attached an
/// object of both, so a question can name the context it is about. System
/// messages are instructions, not state, and are left out.
///
/// Media parts of a kind the model reads become the request's media and
/// contribute nothing to the state; a media part of any other kind is
/// refused. A message of media alone is still a turn, with the empty string
/// as its content, so the turns around it keep their roles and a request of
/// that one message sends the empty string as its state.
BuiltState buildState(
  ModelRequest req, {
  required bool stateJson,
  required Reads reads,
}) {
  final b = _StateBuilder(reads);
  final records = <Map<String, Object?>>[];
  for (final msg in req.messages) {
    if (msg.role == Role.system) continue;
    final collected = b.media.length;
    var value = b.messageValue(msg.content, stateJson: stateJson);
    if (identical(value, nothing)) {
      if (b.media.length == collected) continue;
      value = '';
    }
    records.add({'role': msg.role.value, 'content': value});
  }
  if (records.isEmpty) {
    throw _invalidArgument(
      'the request carries no state; a system message is instructions, so '
      'pass a prompt or messages too',
    );
  }
  final docs = <Object?>[];
  for (final doc in req.docs ?? const <DocumentData>[]) {
    final value = b.documentValue(doc);
    if (!identical(value, nothing)) docs.add(value);
  }
  if (docs.isNotEmpty) {
    return (state: {'messages': records, 'context': docs}, media: b.media);
  }
  if (records.length == 1) {
    return (state: records.single['content'], media: b.media);
  }
  return (state: records, media: b.media);
}

/// What a part, message, or document that contributes nothing to the state
/// yields, told apart from a value.
const Object nothing = _Nothing();

final class _Nothing {
  const _Nothing();
}

/// Reads the state out of messages and documents, and collects the media it
/// meets on the way.
final class _StateBuilder {
  _StateBuilder(this.reads);

  final Reads reads;
  final RequestMedia media = RequestMedia();

  /// A message's contribution to the state: the value of its one part, or
  /// the values of all of them. A message with nothing to contribute yields
  /// [nothing].
  Object? messageValue(List<Part> content, {required bool stateJson}) {
    final values = <Object?>[];
    for (final part in content) {
      final value = _partValue(part, stateJson: stateJson);
      if (!identical(value, nothing)) values.add(value);
    }
    return switch (values.length) {
      0 => nothing,
      1 => values.single,
      _ => values,
    };
  }

  /// A part's contribution to the state. Text is sent as is, or as the JSON
  /// it holds when the config asks, kept verbatim so a number too large for a
  /// double reaches the model unchanged; a data part is sent as its value;
  /// media is collected and contributes nothing. Loop plumbing left in a
  /// history is skipped rather than sent as state, and any other kind of part
  /// is refused rather than stringified.
  Object? _partValue(Part part, {required bool stateJson}) {
    if (_isFormatInstructions(part)) return nothing;
    if (part.isText) {
      final text = part.text!;
      if (!stateJson) return text;
      try {
        return RawJson(text);
      } on FormatException catch (e) {
        throw _invalidArgument(
          'stateJSON is set but the text is not JSON: ${e.message}',
        );
      }
    }
    if (part.isMedia) {
      _collect(part.media!);
      return nothing;
    }
    // A data part is sent as its value; one whose value is null contributes
    // nothing, as in Go.
    if (part.isData) return part.data ?? nothing;
    throw _invalidArgument(
      'a ${_partKindName(part)} part cannot be state; the model takes text, '
      'JSON, and media only',
    );
  }

  /// Adds a media part to the request's media, or refuses it when the model
  /// does not read its kind.
  void _collect(Media media) {
    final (:dataUrl, :contentType) = mediaUrl(media);
    final bool readsKind;
    final List<String> into;
    if (contentType.startsWith('image/')) {
      (readsKind, into) = (reads.images, this.media.images);
    } else if (contentType.startsWith('audio/')) {
      (readsKind, into) = (reads.audio, this.media.audio);
    } else if (contentType.startsWith('video/')) {
      (readsKind, into) = (reads.video, this.media.videos);
    } else {
      throw _invalidArgument(
        'a ${contentType.isEmpty ? 'media' : contentType} part is not an '
        'image, audio, or video; the models take no other media',
      );
    }
    if (!readsKind) {
      throw _invalidArgument('the model reads no $contentType media');
    }
    into.add(dataUrl);
  }

  /// A document's contribution to the context: its content, read as a
  /// message's is, or its content with its metadata when it has any, so a
  /// passage keeps its title and source for a question to refer to. Text
  /// stays text whatever the config says, since a retrieved passage is prose,
  /// not a rendered template. A document of media alone with no metadata
  /// contributes nothing beside its media.
  Object? documentValue(DocumentData doc) {
    final content = messageValue(doc.content, stateJson: false);
    final metadata = doc.metadata;
    if (metadata == null || metadata.isEmpty) return content;
    return {
      'content': identical(content, nothing) ? null : content,
      'metadata': metadata,
    };
  }
}

/// A media part as the media fields take it: a base64 data URL, and its
/// media type.
///
/// A base64 payload goes out as it is, under the part's media type, since the
/// server decodes it anyway; any other payload is percent-decoded (RFC 2397)
/// and encoded. The scheme, the base64 token, and the media type are read
/// without regard to case. A remote URL is refused: the servers take inline
/// media only, and fetching it here would hide a network call, so the caller
/// downloads it first.
({String dataUrl, String contentType}) mediaUrl(Media media) {
  final url = media.url;
  final colon = url.indexOf(':');
  final scheme = colon < 0 ? '' : url.substring(0, colon).toLowerCase();
  switch (scheme) {
    case 'http' || 'https' || 'gs':
      throw _invalidArgument(
        'a media part is a URL, and the models take inline media only; '
        'download it first and pass it as a data URL',
      );
    case 'data':
      break;
    default:
      throw _invalidArgument(
        'a media part must carry its content as a data URL',
      );
  }
  final rest = url.substring(colon + 1);
  final comma = rest.indexOf(',');
  if (comma < 0) {
    throw _invalidArgument('reading the media: the data URL has no comma');
  }
  final header = rest.substring(0, comma);
  final payload = rest.substring(comma + 1);
  final semicolon = header.indexOf(';');
  final mediaType = semicolon < 0 ? header : header.substring(0, semicolon);
  final given = media.contentType;
  final contentType = (given != null && given.isNotEmpty ? given : mediaType)
      .toLowerCase();
  final prefix = 'data:$contentType;base64,';
  if (header.toLowerCase().endsWith(';base64')) {
    return (dataUrl: '$prefix$payload', contentType: contentType);
  }
  return (
    dataUrl: '$prefix${base64.encode(_percentDecode(payload))}',
    contentType: contentType,
  );
}

/// Percent-decodes [s] into bytes, as RFC 2397 data reads: an escape is one
/// byte, whatever encoding the bytes form.
List<int> _percentDecode(String s) {
  final bytes = <int>[];
  final units = utf8.encode(s);
  for (var i = 0; i < units.length; i++) {
    final unit = units[i];
    if (unit != 0x25) {
      bytes.add(unit);
      continue;
    }
    final complete = i + 2 < units.length;
    final high = complete ? _hexDigit(units[i + 1]) : -1;
    final low = complete ? _hexDigit(units[i + 2]) : -1;
    if (high < 0 || low < 0) {
      throw _invalidArgument('reading the media: invalid URL escape');
    }
    bytes.add(high << 4 | low);
    i += 2;
  }
  return bytes;
}

/// The value of the hex digit [byte], or -1 when it is not one.
int _hexDigit(int byte) {
  if (byte >= 0x30 && byte <= 0x39) return byte - 0x30; // 0-9
  if (byte >= 0x41 && byte <= 0x46) return byte - 0x37; // A-F
  if (byte >= 0x61 && byte <= 0x66) return byte - 0x57; // a-f
  return -1;
}

/// Whether the part is the output instructions the generate loop injects
/// when instructions are asked for. The model takes the schema natively and
/// asks for none, but a history recorded from another model's turn keeps
/// them in that turn's messages, and when such a history is the state the
/// part is plumbing, not something anyone said.
bool _isFormatInstructions(Part part) {
  // Any kind of part, as Go reads the purpose off a part's metadata.
  final metadata = part.toJson()['metadata'];
  return metadata is Map && metadata['purpose'] == 'output';
}

/// Names a part's kind for an error message.
String _partKindName(Part part) {
  if (part.isMedia) return 'media';
  if (part.isToolRequest) return 'tool request';
  if (part.isToolResponse) return 'tool response';
  if (part.isReasoning) return 'reasoning';
  if (part.isResource) return 'resource';
  if (part.isData) return 'data';
  return 'custom';
}
