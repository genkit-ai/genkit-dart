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
