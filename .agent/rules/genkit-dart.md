---
trigger: always_on
---

This is Genkit Dart repo.

basic structure:

lib/src/core: core framework -- actions, flows, observability, registry, reflection api
lib/src/ai: AI framework -- model, embedders, generate API, tools, formats, resources.
lib/src/client: Client for accessing Flows or other deployed actions remotely (over HTTP flow protocol).
lib/genkit.dart: Main Genkit veneer API -- how end-users interact with Genkit, insntiate it, install plugins, call generate api, create flows, tools, etc.
lib/lite.dart: Lite generate API -- super basic way to interact with models. See example/lite_generate_example.dart
lib/plugins: current, probably temporary location for some 1P plugins.
example: examples folder -- good place to get a good ideal about how APIs are intended to work. Keep these samples up to date

# Testing

Always test your changes by running `dart test`.

other best practices tooling:

 * run `dart analyze` to ensure things are clean.
 * good to run `dart format lib/ test/`.
 * `dart run tool/apply_license.dart` when adding new files.

# Schema framework

Genkit often needs users to define schemas. And also we rely on schemas internally. Genkit has its own schema framework (that uses json_schema_builder package under the hood).

You define your schema like this:

```
import 'package:genkit/genkit.dart';
// or
import 'package:genkit/schema.dart';

part 'my_file.schema.g.dart';

@GenkitSchema()
abstract class MySubObjSchema {
  String get foofoo;
}

@GenkitSchema()
abstract class MyObjSchema {
  String get name;

  MySubObjSchema get subObj;
}
```

then run the generator:

```
dart run build_runner build
```

It will generate `MySubObj` and `MyObj` (note absense of *Schema suffix), as well as `MySubObjType` and `MyObjType` (note *Type suffix) which can be passes around, like:

```
ai.defineFlow(
  name: 'my-flow',
  inputType: MyObjType,
  fn: ...
)
```

*Type can be used to infer the suffix-less type. If necessary, see how lib/src/core/action.dart does it.


We export `Schema` from json_schema_builder as well, which can be used to define JSON Schemas directly, Zod style:


```dart
  final bananaSchema = Schema.object(
    title: 'banana',
    description: 'yeah banana',
    properties: {'name': Schema.string()},
  );

  bananaSchema.validate(data);
```

`Schema` is an extension type on top of Map, which represents JSON of JSONSchema 2020-12. So, if you have a Map representing JSON Schema you can just cast it to `Schema` and use to validate. Unlike Zod or pydantic these schemas cannot be used as static types in Dart, so prefer to define schemas using `@GenkitSchema()`.
