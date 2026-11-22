[![Pub](https://img.shields.io/pub/v/genkit_systemone.svg)](https://pub.dev/packages/genkit_systemone)

System One decision models for Genkit Dart: models that speak System One, the
protocol TypeSafe AI introduced with jev and that Liquid AI's d1, Cloudflare's
Clef, and the gateways serving them also speak. A decision model does not
generate text. It evaluates a state against typed questions and returns one
typed answer per question, with calibrated probabilities. That makes it a fit for the decisions inside an application:
routing, classification, scoring, guardrails, and verification.

> Status: in preview. The API may change in any minor release.

This is the Dart port of Genkit Go's
[System One plugin](https://genkit.dev/docs/go/integrations/system-one/) and of
the [Java plugin](https://genkit-ai.github.io/genkit-java/plugins/systemone/):
the same question types, wire format, and servers, in Dart's idioms. Where it
differs from Go, this README says so.

> **Building with a coding agent? Install the Genkit Dart skill first.**
>
> ```bash
> npx skills add genkit-ai/skills --skill developing-genkit-dart
> ```
>
> It teaches your agent the current Genkit Dart APIs and common gotchas.
> Source, manual install and skills for other languages:
> [genkit-ai/skills](https://github.com/genkit-ai/skills).

## Design principle: the output schema is the question set

A decision model is served as a model that speaks only constrained JSON, which
is the subset of the generate API it fits exactly. The questions are the
entries of the output schema, declared with `Choice`, `ScoreOf`, and `Noul`.
Each question's description is its instructions, and each question's JSON is
the wire answer, so a decision is one typed `generate` call and the answer
lands in typed fields.

The question types belong to the protocol, not to a server, so one decision
type serves every model that speaks it.

```dart
import 'package:genkit/genkit.dart';
import 'package:genkit_systemone/genkit_systemone.dart';

// The options of a choice belong to their enum, with their criteria.
enum Dept with Option {
  billing('Payments, invoicing, refunds'),
  technical('Bugs, outages, integrations'),
  other('None of the above');

  const Dept(this.criteria);

  @override
  final String criteria;
}

// The levels of a score belong to their rubric, lowest first.
enum Anger with Rubric {
  calm('Calm'),
  concerned('Concerned but civil'),
  angry('Very angry');

  const Anger(this.description);

  @override
  final String description;
}

// The decision: one question per field.
final class Triage {
  Triage(this.department, this.isUrgent, this.frustration);

  final Choice<Dept> department;
  final Noul isUrgent;
  final ScoreOf<Anger> frustration;

  static final $schema = decisionSchema(
    {
      'department': Choice.schema(Dept.values,
          description: 'Which team should handle this?'),
      'is_urgent': Noul.schema(
          description: 'Does the ticket explicitly communicate time pressure?'),
      'frustration': ScoreOf.schema(Anger.values,
          description: 'How frustrated is the customer?'),
    },
    (a) => Triage(
      a['department'] as Choice<Dept>,
      a['is_urgent'] as Noul,
      a['frustration'] as ScoreOf<Anger>,
    ),
  );
}

final typeSafe = SystemOne.typeSafe(); // TYPESAFE_API_KEY
final ai = Genkit(plugins: [typeSafe]);

final result = await ai.generate(
  model: typeSafe.modelRef('jev-1.13.0'),
  prompt: ticket,
  outputSchema: Triage.$schema,
);
final triage = result.output!;
if (triage.department.confidence < 0.6) { // the caller owns thresholds
  return escalate(ticket);
}
switch (triage.department.choice) { // typed
  case Dept.billing:
    // ...
}
```

That is the whole call: the model, the state, and the schema. The questions
ride on the output schema, which the model reads back, so no output format
needs naming.

Everything else is the generate API as it already is: middleware such as
retries, the trace with the question set on the request and the distributions
on the response, and the token counters.

### Why a builder rather than a class

Genkit Go declares a decision as a struct whose fields are `Choice[Dept]`, and
reads each question's options from the field's type parameter:
`Choice[T Option[T]]` is self-referential so that `T.Criteria()` can return
`map[T]string`. Dart cannot call a method on a type parameter, has no struct
tags, and schemantic's generator has no hook for a field type of its own. So:

- the options of a `Choice` and the levels of a `ScoreOf` are **enums** that
  mix in `Option` and `Rubric`, as Genkit Java's are, and the question takes
  their values: `Choice.schema(Dept.values)`;
- each question's schema is a `SchemanticType`, like `SchemanticType.string()`,
  with its instructions as `description`, where Go has `jsonschema_description`;
- `decisionSchema` puts the questions together under their keys and builds the
  decision from the parsed answers, which is what a Go struct does by itself.

The schema on the wire is the same as Go's, so a decision declared here and one
declared in Go ask a server the same questions.

## Question types

| Question                      | Asks                         | Answer fields                                   |
| ----------------------------- | ---------------------------- | ----------------------------------------------- |
| `Choice<T>`                   | pick one of `T`'s values     | `choice`, `probabilities` per option, `confidence` |
| `ScoreOf<L>`                  | rate on `L`'s levels         | `score` (expected level, fractional), `probabilities`, `confidence`, `legend` |
| `Noul`                        | is this true?                | `probability`; near 0.5 means "could not tell"  |
| `NoulOf<C>`                   | is this true, where `C` says what yes and no mean | as `Noul`, which is `NoulOf` with no criteria |

A `Choice` also answers `ranked`, the options from most to least likely, and
`margin`, the probability gap between the top two, which is how decisive the
choice is. A `ScoreOf` answers `level`, the nearest whole level, and `label`,
that level's text from the rubric, with or without a legend on the answer.

`Noul` is a class of its own that extends `NoulOf`, as in Java; Go's
`NoCriteria` is not exported here, since `NoulOf<NoCriteria>` and `Noul` would
be two types for one question.

Genkit Go and Java call the rubric answer `Score`. Here it is `ScoreOf`, since
`package:genkit` already exports an evaluator `Score` and every app imports
both.

The criteria of every question belong to a type, so a pair of yes and no
criteria is a type too, and it is reused wherever the question is asked:

```dart
final class Urgent extends YesNo {
  const Urgent();

  @override
  String get yes => 'Names a deadline, or says now or today';

  @override
  String get no => 'No time pressure is expressed';
}

'is_urgent': NoulOf.schema(const Urgent(),
    description: 'Does the ticket explicitly communicate time pressure?'),
```

Criteria and levels are strings, and the schema and the answers show those
strings. The wire format also takes a structured description, most often an
object with labeled parts. An option or a level adds one by overriding
`guidance`, and a `YesNo` by overriding `yesGuidance` and `noGuidance`:

```dart
@override
Object? get guidance => switch (this) {
  Dept.billing => {
    'not_for': 'Where an order is, or when it arrives',
    'examples': ['I was charged twice for one order.'],
  },
  _ => null,
};
```

An object with no `what` gets the string as its `what`, so guidance adds to the
description. Any other value goes out as it is. A score's legend keeps the
rubric's strings, and the guidance the API echoes back is on
`SystemOneInfo.of(result.modelResponse).answers`.

The options of a `Choice` go out sorted by name, as Go's and Java's do, so a
decision asks the same question from every SDK. An option's name on the wire
is its enum value's `name`.

The `enum` output format also works, with no decision type: the enum values
are the options of one choice question, the system message is the question,
and `result.text` is the option.

```dart
final result = await ai.generate(
  model: typeSafe.modelRef('jev-1.13.0'),
  system: 'Which team should handle this ticket?',
  outputFormat: 'enum',
  outputSchema: SchemanticType.string(
    enumValues: ['billing', 'technical', 'sales'],
  ),
  prompt: ticket,
);
final team = result.text;
```

What the enum format does not give is criteria per option or a probability per
option; a `Choice` gives both.

## Questions built at run time

A question whose options come from data, such as the tools on hand, a tenant's
categories, or the nodes of a taxonomy, has no type to declare it with.
`questionsSchema` builds the output schema from values instead, and the answers
come back as a map of `Answer`:

```dart
final result = await ai.generate(
  model: typeSafe.modelRef('jev-1.13.0'),
  prompt: request,
  outputSchema: questionsSchema({
    'tool': ChoiceQuestion(
      instructions: 'Which tool serves the request?',
      options: [
        for (final tool in tools) ChoiceOption(tool.name, criteria: tool.description),
      ],
    ),
    'personal': NoulQuestion(
      instructions: "Does the request involve the user's own data?",
      yes: "Names the user's files, mail, or calendar",
      no: 'Asks about the world at large',
    ),
  }),
);
final tool = result.output!['tool']!;
if (tool.confidence >= 0.8) return run(tool.choice);
```

`ChoiceQuestion`, `ScoreQuestion`, and `NoulQuestion` take what the question
types take from their enums and classes: options with criteria and guidance,
levels with guidance by index, and yes and no criteria. A choice's options go
out in the order given. Instructions can be a string or any JSON value, such as
an object that describes the field of the state a question is about; a system
message goes beside structured instructions as the first element of a list.

Go calls this function `Schema` and Java `SystemOne.schema`; here `Schema` is
schemantic's annotation.

## State

The state is built from the user and model messages, with no instruction text
mixed in. A system message is never state: it goes in front of every question's
instructions, and for the enum format it is the question. That is the place for
shared context, such as what the state is and what its fields mean. A
`description` given to `decisionSchema` follows the system message in every
question's instructions. To judge a transcript that has its own system prompt,
leave that prompt out of the messages.

- One message is sent as its value: the string of a text part, or the JSON of a
  data part. `promptParts: [DataPart(data: {...})]` sends any value as an
  object state, so that a question can name a field.
- Several messages are sent as a list of `{role, content}` records, roles
  included, so a question can refer to what the user said and what the model
  said.
- With documents attached, the state is `{messages, context}`, each document as
  its content, read as a message's is, or as `{content, metadata}` when it has
  metadata. This is unreachable through `ai.generate` today: it has no `docs`
  parameter, and Genkit Dart's generate action drops `docs` when it builds the
  model request. It applies to a request that reaches the model action with
  `docs` set.

A prompt template renders text, so a template that renders JSON needs
`SystemOneOptions(stateJSON: true)` in its config to produce an object state.
The JSON goes on the wire as written, so an ID past 2^53 is not rounded.

Tools are rejected: the model never calls anything.

### Media

Media parts become the request's media, by kind: images go in `images`, audio
in `audio`, and video in `videos`, each in the order its parts appear, messages
first and documents after. The servers place them before the state, and the
text of the same messages stays the state; a message of media alone is a turn
with empty text. A request may carry media and no text, except to Ollama. Media
goes out as a base64 data URL, or as raw base64 to Ollama; a part given as a URL
is refused rather than fetched, so download it first. Any other media type is
refused.

Media is an extension to the protocol, and a server that does not know a field
can drop it and answer as if nothing had been sent. A plugin therefore refuses
media before the request is sent, kind by kind, unless its `images`, `audio`,
or `video` is `MediaSupport.supported`. `SystemOne.ollama()` and
`SystemOne.workersAI()` set `images`, and so does a server of your own that
takes images. A model's `ModelSpec` overrides the plugin's setting, kind by
kind, either way: Clef-omni on Workers AI also reads audio and video. Its
default keeps the plugin's, so an entry that only sets a `label` changes
nothing else.

## Servers

Models are named by the server they are reached through: the plugin's provider,
then the ID the server uses, so a model a server adds later works on the day it
ships.

| Constructor              | Models                                  | Key                  | Notes                                         |
| ------------------------ | --------------------------------------- | -------------------- | --------------------------------------------- |
| `SystemOne.typeSafe()`   | `typesafe/jev-1.13.0`                   | `TYPESAFE_API_KEY`   | `TYPESAFE_BASE_URL` is read too; lists models; text only |
| `SystemOne.openRouter()` | `openrouter-decisions/liquid/d1`, `openrouter-decisions/typesafe/jev-1.13`, `openrouter-decisions/~typesafe/jev-latest` | `OPENROUTER_API_KEY` | alpha Decisions API; lists OpenRouter's decision models; cost in `usage.custom['cost']`; text only |
| `SystemOne.ollama()`     | `ollama-decisions/clef`                 | none                 | `http://localhost:11434` unless `baseUrl` is set; images as raw base64; a request needs text |
| `SystemOne.workersAI()`  | `cloudflare-decisions/@cf/cloudflare/clef`, `…/clef-flash`, `…/clef-omni`, `cloudflare-decisions/typesafe/jev` | `CLOUDFLARE_API_TOKEN` | `CLOUDFLARE_ACCOUNT_ID` unless `accountId` is given; Clef models read images, Clef-omni audio and video too; a long state is truncated; no versions to pin |

Each constructor also takes the settings Go lets a caller change on the struct
it returns (`path`, `modelsPath`, `images`, `audio`, `video`, `route`,
`unwrap`), each replacing the constructor's default when given.

Keys and accounts are read from the arguments, then from the environment,
when the plugin is built, which fails when a required one is missing. A
gateway serves several vendors' models under one key, so one plugin reaches all
of them. OpenRouter's is named `openrouter-decisions` because a plugin for its
chat models may already be `openrouter`, and an app often uses both; Ollama's is
`ollama-decisions` for the same reason.

`modelRef(id, config:)` on a plugin returns a reference to one of its models,
by the server's ID or by the full name: `typeSafe.modelRef('jev-1.13.0')` and
`typeSafe.modelRef('typesafe/jev-1.13.0')` are the same model.

### TypeSafe

TypeSafe's own API serves jev, by version and as `jev-latest`, which follows
each release. Pin a version in production.

### OpenRouter

Models go by OpenRouter's IDs, and each response reports what the request cost,
in OpenRouter credits, as `result.usage?.custom?['cost']`. An alias that
follows the latest release starts with a tilde, as `~typesafe/jev-latest` does;
`typesafe/jev-latest` is not an ID.

The API is in alpha, and its models are text only here. It takes images inside
the state, and can route them to a provider that drops them and answers anyway,
so the plugin refuses media before the request is sent.

### Ollama

A local Ollama serves the decision models it has pulled, such as Clef, with no
key, and they read images. The Dev UI lists Clef, and `models` adds the other
models pulled.

```dart
final ollama = SystemOne.ollama(baseUrl: 'http://gpu-box:11434');
```

### Cloudflare Workers AI

Workers AI serves Cloudflare's Clef and Clef-flash, which read images,
Clef-omni, which reads images, audio, and video, and partners' models such as
jev, which reads text only. A model is named by its Workers AI ID, `@cf/`
included.

```dart
final cf = SystemOne.workersAI(); // CLOUDFLARE_API_TOKEN, CLOUDFLARE_ACCOUNT_ID

final result = await ai.generate(
  model: cf.modelRef('@cf/cloudflare/clef-omni'),
  messages: [
    Message(role: Role.user, content: [
      TextPart(text: 'Clip from the server room.'),
      MediaPart(media: Media(url: fanAudioDataUrl, contentType: 'audio/wav')),
      MediaPart(media: Media(url: fanVideoDataUrl, contentType: 'video/mp4')),
    ]),
  ],
  outputSchema: FanCheck.$schema,
);
```

Clef-omni takes up to 4 images, 4 audio clips of up to 5 minutes, and 2 videos
of up to a minute, sampled at 2 frames a second; a video's soundtrack is heard
only when every video in the request has one. Clef-flash takes 24k tokens of
state, media, and questions together, and Clef and Clef-omni 64k.

The base URL has an `{account}` segment, which the account ID fills. A proxy's
`baseUrl` with no such segment needs no account ID. Workers AI names one model
per release, with no versions, so a threshold tuned against a model can move
when Cloudflare updates it.

### Several servers

Each server is its own plugin, so one app can use several. Each model's answers
are calibrated on their own, so check which model answered before applying a
threshold tuned for one:

```dart
final threshold = thresholds[SystemOneInfo.of(result.modelResponse).model];
```

### Any other server

Any other server that speaks the protocol takes a few settings. `provider`
names the plugin and prefixes its models, and must differ from every other
plugin's name; `baseUrl` is the root that `path` (default `/v1/systemone`, or
`/` for `baseUrl` itself) and `modelsPath` hang under; `apiKey` is optional for
a server that takes none.

```dart
// Liquid AI's d1, from Liquid's own API.
final liquid = SystemOne(
  provider: 'liquid',
  baseUrl: 'https://api.liquid.ai/decisions',
  modelsPath: '/v1/models',
  apiKey: liquidApiKey,
  images: MediaSupport.supported, // d1 reads images
);
```

A proxy that forwards the native protocol, such as LiteLLM, is reached the same
way. A server whose wire is not the native one takes two hooks over the native
body, so it needs no release of this package:

```dart
final wrapped = SystemOne(
  provider: 'wrapped',
  baseUrl: 'https://decisions.example.com',
  path: '/run',
  // The request: the native body under input, the model in the path.
  route: (model, body) {
    body.remove('model');
    return (path: '/$model', body: {'input': body});
  },
  // The response: the native body out of the server's envelope.
  unwrap: (body) => jsonEncode((jsonDecode(body) as Map)['result']),
);
```

### Every server

`models` describes the models known ahead, keyed by the server's ID or by the
full model name; they are listed in the Dev UI with whatever the server's
listing adds. Genkit's registry keeps the first listing for the life of the
process, so a listing that fails (logged as a warning) lists the known models
alone until the app restarts; Go retries it after a minute. `httpClient` and
`headers` are
the escape hatches to the transport, and `SystemOneOptions(extra: {...})`
merges fields into the request body that the plugin does not model, such as a
gateway's `session_id` or `trace`; it cannot replace a field the request builds
itself.

Requests that fail to connect, time out, are rate limited, or hit a server
error are retried twice, with `Retry-After` honored. The plugin's own HTTP
client gives an attempt 30 seconds; an `httpClient` you pass keeps its own
timeouts. A cancelled request stops at once, on any client, and resolves
`generate` as aborted. Redirects are not followed, so the key never goes to
another host, and a response over 8 MiB is refused rather than cut.

Error statuses map onto Genkit's: 402 is `RESOURCE_EXHAUSTED`, 408, 504, and
Cloudflare's 524 are `DEADLINE_EXCEEDED`, 501 and 505 are `UNIMPLEMENTED`, 500
is `INTERNAL`, every other 5xx is `UNAVAILABLE`, and a client error the canonical mapping does not name,
such as 422, is `INVALID_ARGUMENT`. As with every Genkit Dart model, a failed
request resolves `generate` with `finishReason: failed` and the error on
`result.error`, rather than throwing.

Genkit Go and JS validate a model's output against its schema in the generate
loop; Genkit Dart's loop only parses it. So the plugin checks each answer
before it reaches the decision type: the answer is there, its kind's field is
present and a number or a string as it should be, a choice is one of the
question's options (in the enum format too), and a noul is between 0 and 1.
A failed check fails the call with `INTERNAL`. A score outside the rubric is
clamped, as Go clamps it. A missing `confidence` reads as 0, as Go decodes it,
and a probability for a name the option enum lacks is left out of
`Choice.probabilities` (it stays on `SystemOneInfo.answers`).

A decision type's build function that casts an answer to the wrong type throws
a `FormatException` naming the decision, and core's `generate` lets a parse
error of the typed output escape as that exception rather than as a failed
response.

A plugin with a missing key, account, or base URL, or a base URL that is not
an http or https URL, fails when it is built, with `FAILED_PRECONDITION`. Go
panics in `Init` instead.

When the plugin makes its own HTTP client, `close()` closes it; a client you
pass is yours to close.

Pin a version in production where the server offers one. Confidence thresholds
tuned against one release do not carry over to the next, nor from one model to
another, and `SystemOneInfo.of(result.modelResponse).model` is the version that
answered, on every call.

## Limits

- No per-item questions. Score a list of passages with one call per passage.
- No nested decision types: a question is a top-level entry of the schema.
- The instructions of a question in a decision are a string. Structured
  instructions need a runtime question.
- Each server sets its own limits on questions and tokens; jev takes up to 64k
  tokens of state and questions together, and up to 32k of state and its
  longest question.
- A server can cut a long state to fit its limit and answer from what is left,
  with no error. Check a long document against the model's limit, or split it.
- No streaming; the answer arrives whole.

## Tests

`dart test` runs against a fake endpoint, with no network and no keys.
