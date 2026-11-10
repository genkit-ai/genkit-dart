## 0.5.0

### Breaking Changes

 - switch the model output format to A2UI Express (#472)
 - align the catalog with the A2UI spec's catalog.json (#468)
 - drop client helpers and align the a2ui part with the spec (#710)

### Features

 - tell the model not to render surfaces for conversation (#715)
 - check blocks against the surfaces the client holds, so a block can update one (#714)
 - repair a block that failed to compile (#474)


## 0.4.1

 - updated internal dependencies.

## 0.4.0

### Breaking Changes

 - add ai.defineGenerateMiddleware; rename top-level defineMiddleware to generateMiddleware (#571)
 - make GenerateResult and GenerateResponseChunk read-only views (#547)
 - generate plain JSON schema maps instead of json_schema_builder calls (#522)
 - export every type that appears in a public signature (#490)
 - replace the ActionFnArg record typedef with a final class (#484)

### Other Changes

 - add Genkit Dart agent skill install instructions to READMEs (#521)


## 0.3.0

### Breaking Changes

 - graceful `failed` responses (model + tool errors) + rerunnable failed snapshots (#413)
 - add cancellation support for action calls and generate API (#397)


## 0.2.2

 - updated internal dependencies.

## 0.2.1

### Features

 - add A2UI streaming UI protocol package and sample application (#342)

### Fixes

 - stitch a2ui blocks split across multiple text parts (#404)
 - reconstruct prior surfaces as a2ui blocks in history (#403)

### Other Changes

 - accept Genkit instance in loadCatalog instead of Registry (#401)


## 0.0.1

- Initial release: A2UI (Agent-to-UI) streaming UI protocol support for Genkit
  Dart, provided as the `a2ui()` model middleware plus a bundled basic catalog,
  a streaming block parser, and browser/Flutter-safe client helpers.
