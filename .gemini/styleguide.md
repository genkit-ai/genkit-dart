# genkit-dart review guide

## Dart version

Every package requires Dart 3.12 or later (`sdk: ^3.12.0`). Review the code
against that version, not an older one.

## Dot shorthands are valid

Dot shorthands (Dart 3.10+) are valid and used throughout the repo. Don't
suggest replacing them with the fully qualified form. For example, all of
these compile:

```dart
const KnownModel(this.id, {this.backend = .any});

bool servedOn({required bool agentPlatform}) => switch (backend) {
  .any => true,
  .developerApi => !agentPlatform,
  .agentPlatform => agentPlatform,
};

if (model.backend == .agentPlatform) {}

firebaseAI().resolve(.model, 'gemini-3.8-flash');

return .response('ok');
```

The same goes for other language features up to Dart 3.12, such as
null-aware elements (`[?value]`) and digit separators.
