## 1.0.0-rc.2

### Breaking Changes

 - add ai.defineGenerateMiddleware; rename top-level defineMiddleware to generateMiddleware (#571)

### Fixes

 - prevent filesystem sandbox escape through symlinks (#566)


## 1.0.0-rc.1

### Breaking Changes

 - type usage counts and indexes as int (#546)
 - rename GenerateResponseHelper to GenerateResult and drop redundant members (#534)
 - rename StatusCodes to StatusCode with lowerCamelCase values (#542)
 - rename Tool(toolOutputSchema:) to outputSchema (#530)
 - generate plain JSON schema maps instead of json_schema_builder calls (#522)
 - middleware tool hook returns ToolResult; remove ToolInterruptException (#503)
 - export every type that appears in a public signature (#490)
 - replace the GenerateMiddlewareContext record typedef with a final class (#486)
 - replace the GenerateTurnState record typedef with a final class (#485)
 - stop re-exporting the experimental agents library (#482)
 - move agent/session schema types out of the stable libraries (#480)

### Fixes

 - honor ToolApprovalPlugin(approvedTools:) when toolApproval() has no list (#538)

### Other Changes

 - add Genkit Dart agent skill install instructions to READMEs (#521)
 - fix stale package descriptions in the READMEs and pubspec (#504)


## 0.7.0

### Breaking Changes

 - move agent APIs behind experimental imports (#450)
 - add cancellation support for action calls and generate API (#397)

### Features

 - async sub-agents and task continuation for agents middleware (#417)


## 0.6.1

 - updated internal dependencies.

## 0.6.0

### Breaking Changes

 - redesign tool API around ToolResult + multipart, type actionType with ActionType (#350)


## 0.5.1

 - updated internal dependencies.

## 0.5.0

### Breaking Changes

 - pass middleware context with GenkitAI to factories (#319)

### Features

 - type-safe agent State with schemantic parsing + agent API polish (#330)
 - add agents sub-agent delegation middleware (#324)

### Other Changes

 - cross-SDK conformance suite (7/8) (#316)


## 0.4.4

 - updated internal dependencies.

## 0.4.3

### Other Changes

 - split schemantic into runtime and schemantic_builder packages (#292)


## 0.4.2

 - updated internal dependencies.

## 0.4.1

 - updated internal dependencies.

## 0.4.0

### Breaking Changes

 - introduce GenerateTurnState to middleware generate hook and improve chunk indexing (#269)

### Features

 - enforce strict schema properties on the skills middleware (#252)


## 0.3.1

### Other Changes

 - update mime dependency to ^2.0.0 (#235)


## 0.3.0

### Breaking Changes

 - changed middleware tool hook return type to Part for greater flexibility (#218)


## 0.2.1

 - updated internal dependencies.

## 0.2.0

### Breaking Changes

 - changed tool hook signature on middleware, pass toolRequest to tool (#211)


## 0.1.0+1

 - Update a dependency to the latest release.

## 0.1.0

 - Graduate package to a stable release. See pre-releases prior to this version for changelog entries.

## 0.1.0-dev.1

 - Update a dependency to the latest release.

## 0.0.1-dev.7

> Note: This release has breaking changes.

 - **REFACTOR**: Tweak RegExps and avoid non-linear complexity (#175).
 - **REFACTOR**: make all classes `final` or `base` (#179).
 - **BREAKING** **REFACTOR**: renamed @Schematic() to @Schema() (#192).

## 0.0.1-dev.6

> Note: This release has breaking changes.

 - **REFACTOR**: hide package:json_schema_builder (#167).
 - **FIX**: enforce formatting check in CI (#166).
 - **BREAKING** **FEAT**: move basic type functions to static creation method on SchemanticType (#154).

## 0.0.1-dev.5

 - **REFACTOR**: Introduce a dedicated plugin.dart entry point for plugin-related exports (#149).

## 0.0.1-dev.4

 - Update a dependency to the latest release.

## 0.0.1-dev.3

 - Update a dependency to the latest release.

## 0.0.1-dev.2

 - **FEAT**: add initial CHANGELOG.md for genkit_middleware.
 - **FEAT**: created a genkit_middleware package with skills, filesystem and toolApproval middleware (#126).

## 0.0.1-dev.1

 - Initial release.
