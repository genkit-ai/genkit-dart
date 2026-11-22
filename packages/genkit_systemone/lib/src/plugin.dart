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

import 'dart:async';
import 'dart:convert';

import 'package:genkit/plugin.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import 'options.dart';
import 'protocol/client.dart';
import 'protocol/model.dart';
import 'protocol/state.dart';

final _logger = Logger('genkit_systemone');

/// A listing bounds its wait, since it serves the Dev UI and must not hold it
/// up when the server is slow.
const _listingTimeout = Duration(seconds: 5);

/// Whether models read one kind of media.
///
/// Preview: this API may change in any minor release.
@experimental
enum MediaSupport {
  /// Keeps the setting it overrides: for a model, the plugin's; for the
  /// plugin, refusing the media.
  unset,

  /// Sends the media.
  supported,

  /// Refuses a request with the media before it is sent.
  unsupported,
}

/// Describes one decision model.
///
/// Preview: this API may change in any minor release.
@experimental
final class ModelSpec {
  const ModelSpec({
    this.label = '',
    this.images = MediaSupport.unset,
    this.audio = MediaSupport.unset,
    this.video = MediaSupport.unset,
  });

  /// Names the model in the Dev UI. Empty means one built from the ID.
  final String label;

  /// Override the plugin's setting for this model. [MediaSupport.unset]
  /// keeps the plugin's. An entry given for a model a constructor already
  /// describes replaces that model's whole spec, as in Go, so an entry that
  /// only sets a [label] for Clef-omni also drops its audio and video.
  final MediaSupport images;
  final MediaSupport audio;
  final MediaSupport video;
}

/// Builds the request a server takes when its wire is not the native one.
///
/// Gets the model ID and the native body, which it may change, and returns
/// the path to append to the plugin's path, joined with a slash when it does
/// not start with one, and the body to send. A state parsed with `stateJSON`
/// is in the body as an opaque value that is sent as the JSON text it was
/// given; move it as it is rather than reading it.
typedef SystemOneRoute =
    ({String path, Object? body}) Function(
      String model,
      Map<String, Object?> body,
    );

/// Returns the native response from the body a server sent, such as by
/// taking it out of an envelope.
typedef SystemOneUnwrap = String Function(String body);

/// What a constructor sets for its server beyond the public settings: where
/// its key and base URL come from.
final class _Preset {
  const _Preset({
    this.label = '',
    this.apiKeyEnv = '',
    this.baseUrl = '',
    this.baseUrlEnv = '',
    this.account = '',
    this.accountEnv = '',
  });

  /// Names the server in model labels; empty means the provider.
  final String label;

  /// The variable the key is read from. A server that names one requires a
  /// key.
  final String apiKeyEnv;

  /// The default base URL, and the variable that overrides it.
  final String baseUrl;
  final String baseUrlEnv;

  /// Fills the `{account}` segment of the base URL, from [accountEnv] when
  /// empty. A server that names [accountEnv] requires an account while its
  /// base URL has that segment.
  final String account;
  final String accountEnv;
}

/// A plugin for any server that speaks System One, the protocol decision
/// models speak.
///
/// It serves the server's decision models under its provider name, by the IDs the
/// server uses: a model the server calls `d1` is `<provider>/d1`, and one a
/// gateway calls `liquid/d1` is `<provider>/liquid/d1`. Any ID resolves, so a
/// model the server adds later works without a change here.
///
/// For a server with no constructor of its own, give the settings:
///
/// ```dart
/// SystemOne(
///   provider: 'liquid',
///   baseUrl: 'https://api.liquid.ai/decisions',
///   modelsPath: '/v1/models',
///   apiKey: liquidApiKey,
///   images: MediaSupport.supported,
/// )
/// ```
///
/// [SystemOne.typeSafe], [SystemOne.openRouter], [SystemOne.ollama], and
/// [SystemOne.workersAI] set it up for the known servers. The settings are
/// read when the plugin is built, which fails when one that a request needs
/// is missing, such as a key, since every request would fail.
///
/// Preview: this API may change in any minor release.
@experimental
final class SystemOne extends GenkitPlugin {
  /// A plugin for the server at [baseUrl].
  ///
  /// [baseUrl] must be an http or https URL with a host, checked when the
  /// plugin is built (Go finds out at the first request).
  /// [provider] names the plugin and prefixes its model names, and must
  /// differ from every other plugin's name. [path] is the request path under
  /// [baseUrl]: `/v1/systemone` when null or empty, and `/` for a [baseUrl] that is the
  /// whole endpoint. [modelsPath] is the path of the server's model listing;
  /// when empty, the Dev UI lists the models in [models] only. [apiKey] is
  /// sent as a bearer token, and no authorization header is sent without
  /// one.
  ///
  /// [models] describes the models known ahead, keyed by the server's ID or
  /// by the full model name, `<provider>/<id>`. They are listed in the Dev UI
  /// whether or not the server has a listing; any other ID resolves too.
  ///
  /// [images], [audio], and [video] say whether the models read each kind of
  /// media. [MediaSupport.unset] refuses a request with media of that kind
  /// before it is sent, since media is an extension to the protocol, and a
  /// server that does not know a field can drop it and answer without the
  /// media. [MediaSupport.supported] sends it, and leaves a model that cannot
  /// read it to the server to refuse. A model's [ModelSpec] overrides each.
  ///
  /// [httpClient] sends the requests, and is the escape hatch to transport
  /// settings, timeouts included; the plugin never closes it. Without one,
  /// the plugin's own client bounds each attempt to 30 seconds. [headers] are
  /// sent on every request; the key's `Authorization` header replaces one
  /// given here.
  ///
  /// [route] and [unwrap] serve a server whose wire is not the native one:
  /// [route] builds the request it takes from the native body, and [unwrap]
  /// takes the native response out of what it sends back. An error [unwrap]
  /// throws is reported under [provider], as UNKNOWN unless it is a
  /// [GenkitException].
  SystemOne({
    required String provider,
    String? baseUrl,
    String? path,
    String modelsPath = '',
    String? apiKey,
    Map<String, ModelSpec> models = const {},
    MediaSupport images = MediaSupport.unset,
    MediaSupport audio = MediaSupport.unset,
    MediaSupport video = MediaSupport.unset,
    http.Client? httpClient,
    Map<String, String>? headers,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
  }) : this._(
         provider: provider,
         baseUrl: baseUrl,
         path: path,
         modelsPath: modelsPath,
         apiKey: apiKey,
         models: models,
         images: images,
         audio: audio,
         video: video,
         httpClient: httpClient,
         headers: headers,
         route: route,
         unwrap: unwrap,
         preset: const _Preset(),
         configVar: getConfigVar,
       );

  /// TypeSafe AI's own API, which serves jev, the first System One model.
  ///
  /// Its models are `typesafe/<id>`, such as `typesafe/jev-1.13.0`, and read
  /// text and JSON only. The key comes from [apiKey] or `TYPESAFE_API_KEY`,
  /// and the base URL from [baseUrl] or `TYPESAFE_BASE_URL`, the variables
  /// TypeSafe's SDKs read. Pin a version in production: confidence
  /// thresholds tuned against one release do not carry over to the next.
  ///
  /// [models] adds to the known models, and an entry with a known model's
  /// bare ID replaces that model's spec; a full name for a known model is a
  /// configuration error, as Go panics on it. Every constructor takes the
  /// settings of [SystemOne.new] that its server does not fix, [provider]
  /// included, each replacing the constructor's default when given, as a
  /// field set on Go's struct does. [configVar] reads the environment; tests
  /// pass their own.
  factory SystemOne.typeSafe({
    String? provider,
    String? apiKey,
    String? baseUrl,
    Map<String, ModelSpec> models = const {},
    http.Client? httpClient,
    Map<String, String>? headers,
    String? path,
    String? modelsPath,
    MediaSupport? images,
    MediaSupport? audio,
    MediaSupport? video,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
    String? Function(String name) configVar = getConfigVar,
  }) => SystemOne._(
    provider: provider ?? 'typesafe',
    baseUrl: baseUrl,
    path: path,
    modelsPath: modelsPath ?? '/v1/models',
    images: images ?? MediaSupport.unset,
    audio: audio ?? MediaSupport.unset,
    video: video ?? MediaSupport.unset,
    route: route,
    unwrap: unwrap,
    apiKey: apiKey,
    presetModels: {
      'jev-latest': const ModelSpec(),
      'jev-1.13.0': const ModelSpec(),
    },
    models: models,
    httpClient: httpClient,
    headers: headers,
    preset: const _Preset(
      label: 'TypeSafe',
      apiKeyEnv: 'TYPESAFE_API_KEY',
      baseUrl: 'https://api.typesafe.ai',
      baseUrlEnv: 'TYPESAFE_BASE_URL',
    ),
    configVar: configVar,
  );

  /// OpenRouter's Decisions API, which serves several vendors' decision
  /// models under one key.
  ///
  /// Its models are `openrouter-decisions/<id>` by OpenRouter's ID, such as
  /// `openrouter-decisions/liquid/d1` and
  /// `openrouter-decisions/typesafe/jev-1.13`. An alias that follows the
  /// latest release starts with a tilde, as `~typesafe/jev-latest` does. The
  /// name is not `openrouter`, which the plugin for OpenRouter's chat models
  /// has, so both serve one app. The key comes from [apiKey] or
  /// `OPENROUTER_API_KEY`. The Dev UI lists the models OpenRouter lists as
  /// decision models, and the best known of them when the listing fails, and
  /// a request's cost is in the response usage's `custom['cost']`.
  ///
  /// Its models are text only here. OpenRouter's Decisions API takes images
  /// in the state, not in the images field, and it can route a request to a
  /// model or a provider that drops them and answers without them, so a
  /// request with media is refused before it is sent.
  factory SystemOne.openRouter({
    String? provider,
    String? apiKey,
    String? baseUrl,
    Map<String, ModelSpec> models = const {},
    http.Client? httpClient,
    Map<String, String>? headers,
    String? path,
    String? modelsPath,
    MediaSupport? images,
    MediaSupport? audio,
    MediaSupport? video,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
    String? Function(String name) configVar = getConfigVar,
  }) => SystemOne._(
    provider: provider ?? 'openrouter-decisions',
    baseUrl: baseUrl,
    path: path ?? '/api/alpha/decisions',
    modelsPath: modelsPath ?? '/api/v1/models?output_modalities=decisions',
    images: images ?? MediaSupport.unset,
    audio: audio ?? MediaSupport.unset,
    video: video ?? MediaSupport.unset,
    route: route,
    unwrap: unwrap,
    apiKey: apiKey,
    presetModels: {
      'cloudflare/clef': const ModelSpec(),
      'cloudflare/clef-flash': const ModelSpec(),
      'liquid/d1': const ModelSpec(),
      'typesafe/jev-1.13': const ModelSpec(),
      '~typesafe/jev-latest': const ModelSpec(),
    },
    models: models,
    httpClient: httpClient,
    headers: headers,
    preset: const _Preset(
      label: 'OpenRouter',
      apiKeyEnv: 'OPENROUTER_API_KEY',
      baseUrl: 'https://openrouter.ai',
    ),
    configVar: configVar,
  );

  /// A local Ollama server, which serves the decision models it has pulled,
  /// such as Clef, and takes no key.
  ///
  /// Its models are `ollama-decisions/<name>` by Ollama's name, such as
  /// `ollama-decisions/clef`. The name is not `ollama`, which the plugin for
  /// Ollama's chat models has, so both serve one app. The server is
  /// `http://localhost:11434` unless [baseUrl] says otherwise. The Dev UI
  /// lists Clef, and [models] adds the other models pulled.
  ///
  /// Ollama takes images as raw base64 rather than data URLs, which this
  /// plugin converts, and requires text in the state, so a request with no
  /// text, such as one of images alone, is refused before it is sent.
  factory SystemOne.ollama({
    String? provider,
    String? apiKey,
    String? baseUrl,
    Map<String, ModelSpec> models = const {},
    http.Client? httpClient,
    Map<String, String>? headers,
    String? path,
    String? modelsPath,
    MediaSupport? images,
    MediaSupport? audio,
    MediaSupport? video,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
  }) => SystemOne._(
    provider: provider ?? 'ollama-decisions',
    baseUrl: baseUrl,
    apiKey: apiKey,
    path: path,
    modelsPath: modelsPath ?? '',
    route: route ?? ollamaRoute,
    unwrap: unwrap,
    images: images ?? MediaSupport.supported,
    audio: audio ?? MediaSupport.unset,
    video: video ?? MediaSupport.unset,
    presetModels: {'clef': const ModelSpec()},
    models: models,
    httpClient: httpClient,
    headers: headers,
    preset: const _Preset(label: 'Ollama', baseUrl: 'http://localhost:11434'),
    configVar: getConfigVar,
  );

  /// Cloudflare Workers AI for one account.
  ///
  /// It serves Cloudflare's own decision models, Clef and Clef-flash, which
  /// read images, and Clef-omni, which reads images, audio, and video, and
  /// partners' models such as jev, which reads text only. Its models are
  /// `cloudflare-decisions/<id>` by the Workers AI ID:
  /// `cloudflare-decisions/@cf/cloudflare/clef`,
  /// `cloudflare-decisions/@cf/cloudflare/clef-flash`,
  /// `cloudflare-decisions/@cf/cloudflare/clef-omni`, and
  /// `cloudflare-decisions/typesafe/jev`. The API token comes from [apiToken]
  /// or `CLOUDFLARE_API_TOKEN`, and the account ID from [accountId] or
  /// `CLOUDFLARE_ACCOUNT_ID`. A [baseUrl] with no `{account}` segment, such
  /// as a proxy's, needs no account ID.
  ///
  /// Workers AI names one model per release, with no versions, so a
  /// threshold tuned against a model can move when Cloudflare updates it.
  factory SystemOne.workersAI({
    String? provider,
    String? accountId,
    String? apiToken,
    String? baseUrl,
    Map<String, ModelSpec> models = const {},
    http.Client? httpClient,
    Map<String, String>? headers,
    String? path,
    String? modelsPath,
    MediaSupport? images,
    MediaSupport? audio,
    MediaSupport? video,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
    String? Function(String name) configVar = getConfigVar,
  }) => SystemOne._(
    provider: provider ?? 'cloudflare-decisions',
    baseUrl: baseUrl,
    path: path ?? '/ai/run',
    modelsPath: modelsPath ?? '',
    apiKey: apiToken,
    route: route ?? workersAIRoute,
    unwrap: unwrap ?? unwrapWorkersAI,
    images: images ?? MediaSupport.supported,
    audio: audio ?? MediaSupport.unset,
    video: video ?? MediaSupport.unset,
    presetModels: {
      '@cf/cloudflare/clef': const ModelSpec(),
      '@cf/cloudflare/clef-flash': const ModelSpec(),
      '@cf/cloudflare/clef-omni': const ModelSpec(
        audio: MediaSupport.supported,
        video: MediaSupport.supported,
      ),
      'typesafe/jev': const ModelSpec(images: MediaSupport.unsupported),
    },
    models: models,
    httpClient: httpClient,
    headers: headers,
    preset: _Preset(
      label: 'Workers AI',
      apiKeyEnv: 'CLOUDFLARE_API_TOKEN',
      baseUrl: 'https://api.cloudflare.com/client/v4/accounts/{account}',
      account: accountId ?? '',
      accountEnv: 'CLOUDFLARE_ACCOUNT_ID',
    ),
    configVar: configVar,
  );

  SystemOne._({
    required String provider,
    required String? baseUrl,
    String? path,
    String modelsPath = '',
    required String? apiKey,
    Map<String, ModelSpec> presetModels = const {},
    required Map<String, ModelSpec> models,
    MediaSupport images = MediaSupport.unset,
    MediaSupport audio = MediaSupport.unset,
    MediaSupport video = MediaSupport.unset,
    required http.Client? httpClient,
    required Map<String, String>? headers,
    SystemOneRoute? route,
    SystemOneUnwrap? unwrap,
    required _Preset preset,
    required String? Function(String name) configVar,
  }) : _provider = provider,
       _preset = preset,
       _ownsClient = httpClient == null,
       _media = (images: images, audio: audio, video: video) {
    if (provider.isEmpty || provider.contains('/')) {
      throw GenkitException(
        'systemone: set provider, the plugin\'s name and the prefix of its '
        'models, with no "/"; got "$provider"',
        status: StatusCode.failedPrecondition,
      );
    }
    String setting(String? given, String env) {
      if (given != null && given.isNotEmpty) return given;
      if (env.isEmpty) return '';
      return configVar(env)?.trim() ?? '';
    }

    final key = preset.apiKeyEnv.isEmpty
        ? (apiKey ?? '')
        : setting(apiKey, preset.apiKeyEnv);
    if (preset.apiKeyEnv.isNotEmpty && key.isEmpty) {
      throw GenkitException(
        '$provider: pass an API key or set the ${preset.apiKeyEnv} '
        'environment variable',
        status: StatusCode.failedPrecondition,
      );
    }
    var base = setting(baseUrl, preset.baseUrlEnv);
    if (base.isEmpty) base = preset.baseUrl;
    if (base.isEmpty) {
      throw GenkitException(
        '$provider: set baseUrl, the root of the server\'s System One API',
        status: StatusCode.failedPrecondition,
      );
    }
    final parsed = Uri.tryParse(base.replaceAll('{account}', 'account'));
    if (parsed == null ||
        !(parsed.isScheme('http') || parsed.isScheme('https')) ||
        parsed.host.isEmpty) {
      throw GenkitException(
        '$provider: baseUrl must be an http or https URL with a host; got '
        '"$base"',
        status: StatusCode.failedPrecondition,
      );
    }
    if (preset.accountEnv.isNotEmpty && base.contains('{account}')) {
      final account = setting(preset.account, preset.accountEnv);
      if (account.isEmpty) {
        throw GenkitException(
          '$provider: pass an account ID or set the ${preset.accountEnv} '
          'environment variable',
          status: StatusCode.failedPrecondition,
        );
      }
      base = base.replaceAll('{account}', pathEscape(account));
    }
    var requestPath = _rooted(
      path == null || path.isEmpty ? '/v1/systemone' : path,
    );
    if (requestPath == '/') requestPath = '';

    // As in Go: the caller's models are added to the constructor's, and an
    // entry with a known model's ID replaces that model's whole spec. A full
    // name for a model the constructor defines is refused, as Go panics on a
    // model named twice.
    _models.addAll(presetModels);
    final named = <String>{};
    for (final MapEntry(:key, :value) in models.entries) {
      final id = _trimProvider(key);
      if (!named.add(id)) {
        throw GenkitException(
          '$provider: models names $id twice, by its ID and by its full name',
          status: StatusCode.failedPrecondition,
        );
      }
      if (key != id && presetModels.containsKey(id)) {
        throw GenkitException(
          '$provider: models names $key, which is already defined by the '
          'preset as $id; use the bare ID',
          status: StatusCode.failedPrecondition,
        );
      }
      _models[id] = value;
    }

    _client = DecideClient(
      httpClient: httpClient ?? http.Client(),
      // As in Go, the 30-second bound is the plugin's own client's; a client
      // passed in keeps whatever timeout it was given.
      timeout: httpClient == null ? requestTimeout : null,
      baseUrl: base.endsWith('/') ? base.substring(0, base.length - 1) : base,
      apiKey: key,
      headers: {...?headers},
      endpoint: Endpoint(
        name: provider,
        path: requestPath,
        modelsPath: _rooted(modelsPath),
        route: route,
        unwrap: unwrap,
      ),
    );
  }

  final String _provider;
  final _Preset _preset;
  final bool _ownsClient;
  final ({MediaSupport images, MediaSupport audio, MediaSupport video}) _media;

  /// The models known ahead, keyed by the server's ID.
  final Map<String, ModelSpec> _models = {};

  late final DecideClient _client;

  @override
  String get name => _provider;

  /// Closes the HTTP client the plugin made for itself. A client passed as
  /// `httpClient` is the caller's, and stays open.
  void close() {
    if (_ownsClient) _client.httpClient.close();
  }

  /// No actions are registered up front: models resolve by name.
  @override
  Future<List<Action>> init() async => [];

  /// Lists the models in the known models together with the ones the
  /// server's listing names.
  ///
  /// A listing that fails or takes too long leaves the known models, so the
  /// Dev UI still shows them while offline. Genkit's registry keeps the first
  /// listing for the life of the process, so the server is asked once.
  @override
  Future<List<ActionMetadata>> list() async {
    final ids = {..._models.keys};
    if (_client.endpoint.modelsPath.isNotEmpty) {
      try {
        final models = await _client.listModels(timeout: _listingTimeout);
        ids.addAll(models.map((m) => m.model).where((id) => id.isNotEmpty));
      } catch (e) {
        // Genkit's registry keeps this listing for the life of the process,
        // so the failure is worth a warning, not a debug line.
        _logger.warning(
          '$_provider: model listing failed, so the Dev UI lists the '
          'configured models only until the app restarts: $e',
        );
      }
    }
    return [
      for (final id in ids.toList()..sort())
        modelMetadata(
          '$_provider/$id',
          customOptions: SystemOneOptions.$schema,
          info: ModelInfo(
            label: _label(id),
            supports: decisionSupports(media: _reads(id).any),
          ),
        ),
    ];
  }

  /// Models are the only action type served. The ID is forwarded as given;
  /// whether it exists is for the server to say when the first request is
  /// made.
  @override
  Action? resolve(ActionType actionType, String name) {
    if (actionType != ActionType.model) return null;
    return newDecisionModel(
      _client,
      '$_provider/$name',
      name,
      label: _label(name),
      reads: _reads(name),
    );
  }

  /// A reference to one of the plugin's models, with a [config], for the
  /// places that take a reference, such as a generate call's `model`.
  ///
  /// The ID is the server's or the full model name, as a key of the known
  /// models is: `modelRef('jev-1.13.0')` and `modelRef('typesafe/jev-1.13.0')`
  /// on [SystemOne.typeSafe] are both `typesafe/jev-1.13.0`.
  ModelRef<SystemOneOptions> modelRef(String id, {SystemOneOptions? config}) =>
      _modelRef('$_provider/${_trimProvider(id)}', config);

  String _trimProvider(String id) =>
      id.startsWith('$_provider/') ? id.substring(_provider.length + 1) : id;

  String _label(String id) {
    final label = _models[id]?.label ?? '';
    if (label.isNotEmpty) return label;
    final server = _preset.label.isEmpty ? _provider : _preset.label;
    return '$server - $id';
  }

  Reads _reads(String id) {
    final spec = _models[id] ?? const ModelSpec();
    bool reads(MediaSupport plugin, MediaSupport model) =>
        (model == MediaSupport.unset ? plugin : model) ==
        MediaSupport.supported;
    return Reads(
      images: reads(_media.images, spec.images),
      audio: reads(_media.audio, spec.audio),
      video: reads(_media.video, spec.video),
    );
  }
}

ModelRef<SystemOneOptions> _modelRef(String name, SystemOneOptions? config) =>
    modelRef(name, customOptions: SystemOneOptions.$schema, config: config);

/// Gives a non-empty path the leading slash that joins it to the base URL.
String _rooted(String path) =>
    path.isEmpty || path.startsWith('/') ? path : '/$path';

/// Builds a request the way Workers AI runs the model.
///
/// Its own models, under `@cf/`, run at `/ai/run/<ID>` with the native body,
/// which names the model by its last segment, as `clef`. A partner's model
/// runs at `/ai/run` with the native body under `input` and the model beside
/// it. A model ID goes into the path one escaped segment at a time, and one
/// with an empty or dot segment is refused, so no ID can change the query or
/// reach another path of the account's API with its token.
({String path, Object? body}) workersAIRoute(
  String model,
  Map<String, Object?> body,
) {
  if (!model.startsWith('@cf/')) {
    body.remove('model');
    return (path: '', body: {'model': model, 'input': body});
  }
  final segments = model.split('/');
  for (final segment in segments) {
    if (segment.isEmpty || segment == '.' || segment == '..') {
      throw GenkitException(
        'systemone: "$model" is not a Workers AI model ID',
        status: StatusCode.invalidArgument,
      );
    }
  }
  body['model'] = segments.last;
  return (path: '/${segments.map(pathEscape).join('/')}', body: body);
}

/// Escapes one path segment as Go's `url.PathEscape` does: unreserved
/// characters and `$&+:=@` stay, everything else is percent-encoded, `/`,
/// `;`, `,`, and `?` included.
String pathEscape(String segment) {
  const kept =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_.~\$&+:=@';
  final out = StringBuffer();
  for (final byte in utf8.encode(segment)) {
    final c = String.fromCharCode(byte);
    if (byte < 0x80 && kept.contains(c)) {
      out.write(c);
    } else {
      out.write('%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}');
    }
  }
  return out.toString();
}

/// Handles both response shapes the Workers AI REST API is documented with:
/// the bare model output, and the `{result, success, errors}` envelope the
/// rest of the API uses. A failed envelope's messages are read the way an
/// error response's are.
String unwrapWorkersAI(String body) {
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return body;
  }
  if (decoded is! Map || decoded['success'] is! bool) return body;
  if (decoded['success'] != true) {
    throw GenkitException(errorMessage(body), status: StatusCode.unknown);
  }
  return jsonEncode(decoded['result']);
}

/// Sends the native body with the images as raw base64, as Ollama takes
/// them, and refuses a request with no text in the state, which Ollama
/// requires.
({String path, Object? body}) ollamaRoute(
  String model,
  Map<String, Object?> body,
) {
  final urls = body['images'];
  final hasImages = urls is List && urls.isNotEmpty;
  if (!hasText(body['state'])) {
    throw GenkitException(
      'systemone: Ollama requires text in the state'
      '${hasImages ? ', so a request with images needs text too' : ''}',
      status: StatusCode.invalidArgument,
    );
  }
  if (hasImages) {
    body['images'] = [
      for (final image in urls.cast<String>())
        image.contains(';base64,')
            ? image.substring(image.indexOf(';base64,') + ';base64,'.length)
            : image,
    ];
  }
  return (path: '', body: body);
}

/// Whether a state carries any text: a nonempty string, a turn or document
/// with text, or any other value, such as the object of a data part or the
/// values of a message's several parts. The turns are told apart by their
/// type, as Go tells `[]map[string]any` from `[]any`.
bool hasText(Object? state) => switch (state) {
  null => false,
  String() => state.isNotEmpty,
  List<Map<String, Object?>>() => state.any((turn) => hasText(turn['content'])),
  Map() when state['messages'] is List<Map<String, Object?>> =>
    hasText(state['messages']) ||
        (state['context'] is List && (state['context'] as List).any(hasText)),
  Map() => state.isNotEmpty,
  _ => true,
};
