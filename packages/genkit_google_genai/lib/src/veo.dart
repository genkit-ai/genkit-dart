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

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:meta/meta.dart';

import 'api_client.dart';
import 'generated/generativelanguage.dart' as gcl;
import 'model.dart';

typedef GoogleGenAiClientFactory =
    Future<GenerativeLanguageBaseClient> Function([String? requestApiKey]);

final veoModelInfo = ModelInfo(
  supports: {
    'multiturn': false,
    'media': true,
    'tools': false,
    'toolChoice': false,
    'systemRole': false,
    'constrained': false,
  },
);

Model createVeoModel({
  required String pluginName,
  required String modelName,
  required GoogleGenAiClientFactory getApiClient,
  required GenkitException Function(Object e, StackTrace stack) handleException,
  http.Client? downloadClient,
}) {
  return Model(
    name: '$pluginName/$modelName',
    customOptions: VeoOptions.$schema,
    metadata: {'model': veoModelInfo.toJson()},
    fn: (req, ctx) async {
      final options = req!.config == null
          ? VeoOptions()
          : VeoOptions.$schema.parse(req.config!);

      if (req.tools?.isNotEmpty ?? false) {
        throw GenkitException(
          'Veo models do not support tool calling.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }

      final prompt = toVeoPrompt(req.messages);
      if (prompt.isEmpty) {
        throw GenkitException(
          'Veo requests require a text prompt.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }

      final mediaInputs = toVeoMediaInputs(req.messages);
      if (mediaInputs.length > 1) {
        throw GenkitException(
          'Veo currently supports at most one inline image or video input per request.',
          status: StatusCodes.INVALID_ARGUMENT,
        );
      }

      final parameters = toVeoParameters(options);
      final instance = <String, dynamic>{'prompt': prompt};
      if (mediaInputs.isNotEmpty) {
        final mediaField = toVeoMediaField(mediaInputs.single.media);
        instance[mediaField.key] = mediaField.value;
      }

      final service = await getApiClient();

      try {
        final operation = await service.predictLongRunning({
          'instances': [instance],
          if (parameters.isNotEmpty) 'parameters': parameters,
        }, model: 'models/$modelName');
        final completed = await waitForVeoOperation(
          service,
          operation,
          options,
        );
        final mediaPart = await toEmbeddableVeoMediaPart(
          service,
          completed,
          options,
          downloadClient: downloadClient,
        );

        if (ctx.streamingRequested) {
          ctx.sendChunk(ModelResponseChunk(index: 0, content: [mediaPart]));
        }

        return ModelResponse(
          finishReason: FinishReason.stop,
          message: Message(role: Role.model, content: [mediaPart]),
          raw: completed.toJson(),
          // The Dart runtime does not expose background-model check actions for
          // Veo. By the time we return here the long-running operation has
          // already completed, so attaching it would cause tooling to try an
          // unsupported background check flow.
        );
      } catch (e, stack) {
        throw handleException(e, stack);
      } finally {
        service.client.close();
      }
    },
  );
}

List<Map<String, dynamic>> _extractVeoGeneratedSamples(
  Map<String, dynamic>? response,
) {
  if (response == null) return const [];

  final generateVideoResponse = response['generateVideoResponse'];
  if (generateVideoResponse is Map<String, dynamic>) {
    final generatedSamples = generateVideoResponse['generatedSamples'];
    if (generatedSamples is List) {
      return generatedSamples
          .map(_toDynamicMap)
          .whereType<Map<String, dynamic>>()
          .toList();
    }
  }

  final generatedVideos = response['generatedVideos'];
  if (generatedVideos is List) {
    return generatedVideos
        .map((video) => {'video': _toDynamicMap(video)})
        .where((sample) => sample['video'] != null)
        .cast<Map<String, dynamic>>()
        .toList();
  }

  return const [];
}

Map<String, dynamic>? _toDynamicMap(Object? value) {
  if (value == null) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) (entry.key as String): entry.value,
    };
  }

  try {
    final json = (value as dynamic).toJson();
    return _toDynamicMap(json);
  } catch (_) {
    return null;
  }
}

StatusCodes _statusFromRpcCode(int? code) {
  return switch (code) {
    1 => StatusCodes.CANCELLED,
    3 => StatusCodes.INVALID_ARGUMENT,
    4 => StatusCodes.DEADLINE_EXCEEDED,
    5 => StatusCodes.NOT_FOUND,
    6 => StatusCodes.ALREADY_EXISTS,
    7 => StatusCodes.PERMISSION_DENIED,
    8 => StatusCodes.RESOURCE_EXHAUSTED,
    9 => StatusCodes.FAILED_PRECONDITION,
    10 => StatusCodes.ABORTED,
    11 => StatusCodes.OUT_OF_RANGE,
    12 => StatusCodes.UNIMPLEMENTED,
    13 => StatusCodes.INTERNAL,
    14 => StatusCodes.UNAVAILABLE,
    15 => StatusCodes.DATA_LOSS,
    16 => StatusCodes.UNAUTHENTICATED,
    _ => StatusCodes.INTERNAL,
  };
}

const _defaultVeoPollingIntervalMs = 5000;
const _defaultVeoTimeoutMs = 600000;
const _defaultVeoDownloadTimeoutMs = 30000;
const _localVeoOptionKeys = {
  'pollingIntervalMs',
  'timeoutMs',
  'embedMedia',
  'downloadTimeoutMs',
};

@visibleForTesting
Map<String, dynamic> toVeoParameters(VeoOptions options) {
  final parameters = Map<String, dynamic>.from(options.toJson());
  for (final key in _localVeoOptionKeys) {
    parameters.remove(key);
  }
  parameters.removeWhere((_, value) => value == null);
  return parameters;
}

@visibleForTesting
String toVeoPrompt(List<Message> messages) {
  return messages
      .where(
        (message) => message.role != Role.model && message.role != Role.tool,
      )
      .map(
        (message) => message.content
            .where((part) => part.isText)
            .map((part) => part.text)
            .whereType<String>()
            .join('\n'),
      )
      .where((text) => text.trim().isNotEmpty)
      .join('\n\n')
      .trim();
}

@visibleForTesting
List<MediaPart> toVeoMediaInputs(List<Message> messages) {
  return messages
      .where(
        (message) => message.role != Role.model && message.role != Role.tool,
      )
      .expand(
        (message) => message.content
            .where((part) => part.isMedia)
            .map((part) => part.mediaPart!),
      )
      .toList();
}

@visibleForTesting
MapEntry<String, Map<String, dynamic>> toVeoMediaField(Media media) {
  if (!media.url.startsWith('data:')) {
    throw GenkitException(
      'Veo media inputs currently must be provided as inline data URIs.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final uri = Uri.parse(media.url);
  final data = uri.data;
  final mimeType = media.contentType ?? data?.mimeType;
  if (data == null || mimeType == null || mimeType.isEmpty) {
    throw GenkitException(
      'Veo media inputs require a valid data URI with a MIME type.',
      status: StatusCodes.INVALID_ARGUMENT,
    );
  }

  final fieldName = switch (mimeType) {
    final value when value.startsWith('image/') => 'image',
    final value when value.startsWith('video/') => 'video',
    _ => throw GenkitException(
      'Unsupported Veo media MIME type: $mimeType',
      status: StatusCodes.INVALID_ARGUMENT,
    ),
  };

  return MapEntry(fieldName, {
    'inlineData': {
      'mimeType': mimeType,
      'data': base64Encode(data.contentAsBytes()),
    },
  });
}

Future<gcl.Operation> waitForVeoOperation(
  GenerativeLanguageBaseClient service,
  gcl.Operation operation,
  VeoOptions options,
) async {
  final operationName = operation.name;
  if (operationName == null || operationName.isEmpty) {
    throw GenkitException(
      'Veo did not return an operation name.',
      status: StatusCodes.INTERNAL,
    );
  }

  final pollInterval = Duration(
    milliseconds: options.pollingIntervalMs ?? _defaultVeoPollingIntervalMs,
  );
  final timeout = Duration(
    milliseconds: options.timeoutMs ?? _defaultVeoTimeoutMs,
  );
  final deadline = DateTime.now().add(timeout);

  var current = operation;
  while (current.done != true) {
    if (DateTime.now().isAfter(deadline)) {
      throw GenkitException(
        'Timed out waiting for Veo operation $operationName.',
        status: StatusCodes.DEADLINE_EXCEEDED,
      );
    }
    await Future.delayed(pollInterval);
    current = await service.getOperation(operationName);
  }

  final error = _toDynamicMap(current.toJson()['error']);
  if (error != null) {
    throw GenkitException(
      error['message'] as String? ?? 'Veo operation failed.',
      status: _statusFromRpcCode(error['code'] as int?),
      details: jsonEncode(error),
    );
  }

  return current;
}

Operation toGenkitOperation(gcl.Operation operation, String actionName) {
  final json = operation.toJson();
  return Operation(
    action: actionName,
    id: operation.name ?? actionName,
    done: operation.done,
    output: _toDynamicMap(json['response']),
    error: _toDynamicMap(json['error']),
    metadata: _toDynamicMap(json['metadata']),
  );
}

@visibleForTesting
MediaPart veoOperationToMediaPart(gcl.Operation operation) {
  final response = _toDynamicMap(operation.toJson()['response']);
  final generatedSamples = _extractVeoGeneratedSamples(response);
  if (generatedSamples.isEmpty) {
    throw GenkitException(
      'Veo operation completed without a generated video.',
      status: StatusCodes.INTERNAL,
    );
  }

  final video = generatedSamples.first['video'];
  final videoMap = _toDynamicMap(video);
  final uri = videoMap?['uri'] as String?;
  final mimeType = videoMap?['mimeType'] as String? ?? 'video/mp4';
  if (uri == null || uri.isEmpty) {
    throw GenkitException(
      'Veo operation completed without a video URI.',
      status: StatusCodes.INTERNAL,
    );
  }

  return MediaPart(
    media: Media(url: uri, contentType: mimeType),
    metadata: {if (operation.name != null) 'operationName': operation.name},
  );
}

@visibleForTesting
Future<MediaPart> toEmbeddableVeoMediaPart(
  GenerativeLanguageBaseClient service,
  gcl.Operation operation,
  VeoOptions options, {
  http.Client? downloadClient,
}) async {
  final mediaPart = veoOperationToMediaPart(operation);
  if (options.embedMedia != true) {
    return mediaPart;
  }

  final mediaUrl = mediaPart.media.url;
  final uri = Uri.tryParse(mediaUrl);
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return mediaPart;
  }

  final useAuthenticatedClient = _isTrustedGenAiDownloadUri(uri, service);
  final client = useAuthenticatedClient
      ? service.client
      : downloadClient ?? http.Client();
  try {
    final downloadTimeout = Duration(
      milliseconds: options.downloadTimeoutMs ?? _defaultVeoDownloadTimeoutMs,
    );
    final response = await client.get(uri).timeout(downloadTimeout);
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        response.bodyBytes.isEmpty) {
      return mediaPart;
    }

    final responseContentType = response.headers['content-type']
        ?.split(';')
        .first
        .trim();
    final contentType =
        mediaPart.media.contentType ?? responseContentType ?? 'video/mp4';

    return MediaPart(
      media: Media(
        url: 'data:$contentType;base64,${base64Encode(response.bodyBytes)}',
        contentType: contentType,
      ),
      metadata: {...?mediaPart.metadata, 'sourceUrl': mediaUrl},
    );
  } catch (_) {
    return mediaPart;
  } finally {
    if (!useAuthenticatedClient && downloadClient == null) {
      client.close();
    }
  }
}

bool _isTrustedGenAiDownloadUri(Uri uri, GenerativeLanguageBaseClient service) {
  final baseUri = Uri.tryParse(service.baseUrl);
  if (baseUri == null || uri.host != baseUri.host) return false;

  return uri.pathSegments.any((segment) => segment.endsWith(':download'));
}
