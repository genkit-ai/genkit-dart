# Genkit Migration Report: `opentelemetry` to `dartastic_opentelemetry_api`

This report documents the migration of `packages/genkit` and its dependent
`testapps` from `package:opentelemetry` to `package:dartastic_opentelemetry_api`
(v1.0.0-alpha) and `package:dartastic_opentelemetry` (v0.9.3).

## Summary of Changes

The migration involved replacing the standard `package:opentelemetry` with
`package:dartastic_opentelemetry_api` and its corresponding SDK across the
entire workspace.

**Key areas modified:**
1.  **`packages/genkit/pubspec.yaml`**: Swapped dependencies and added a
    `dependency_override` for the `1.0.0-alpha` API to ensure compatibility
    with the SDK.
2.  **`lib/src/o11y/instrumentation.dart`**: Refactored `runInNewSpan` to use
    `OTelAPI` for tracer and attribute creation, and
    `Context.current.withSpan(span).run()` for zone-based propagation.
3.  **`lib/src/o11y/telemetry/telemetry_io.dart` & `telemetry_web.dart`**: Updated
    to support the new exporter initialization.
4.  **`lib/src/o11y/telemetry/exporter_impl.dart`**: Migrated the custom
    `CollectorHttpExporter` and `RealtimeSpanProcessor`. This involved
    significant updates to the OTLP JSON translation logic to match the new
    `Span`, `Resource`, and `Attributes` models.
5.  **`testapps` Migration**: Several test applications (`firebase_ai`,
    `flutter_genai`) required `dependency_overrides` for
    `dartastic_opentelemetry_api: 1.0.0-alpha` to resolve version conflicts with
    the SDK used by `genkit`.
6.  **Tests**: Updated `action_test.dart`, `instrumentation_test.dart`,
    `otlp_http_exporter_test.dart`, and `test_util.dart` to align with the new
    SDK's lifecycle management and object models.

---

## API Thoughts & Observations

### 1. Context and Zone Propagation
The `dartastic` API's `Context` management is centered around `Context.current`,
which by default leverages `Zone.current`. While this is powerful, it requires
careful use of `Context.run()` to ensure that asynchronous operations correctly
propagate the active span. In Genkit, wrapping the action execution in a
`Context.run` block proved to be an effective pattern.

### 2. Robust Attribute Management
The new `Attributes` collection is a highlight. It provides typed getters
(`getString`, `getBool`, etc.) and clear factory methods. The
`OTelAPI.attributeString` and `OTelAPI.attributesFromMap` helpers are more
ergonomic than the previous `api.Attribute.fromString` pattern.

### 3. Root Span Parent IDs
A notable implementation detail in `dartastic` is that root spans are
initialized with an *invalid* `SpanId` (all zeros) rather than a `null` value.
This necessitated updating test expectations from `isNull` to checking
`isValid == false`.

### 4. SDK Visibility for Exporters
Properties like `Span.attributes` are marked `@visibleForTesting` in the SDK.
While the OTel specification generally discourages direct attribute access,
custom exporters (like Genkit's `CollectorHttpExporter`) require this data. The
migration uses `// ignore: invalid_use_of_visible_for_testing_member` to access
these properties, consistent with internal SDK transformers.

### 5. Asynchronous Lifecycle
Most SDK-level methods (`export`, `onEnd`, `shutdown`, `forceFlush`) are
`Future`-based. This improves the responsiveness of the application by
preventing telemetry export from blocking the main execution thread, though it
does require test setups to be asynchronous.

## Conclusion

The migration was completed successfully across the workspace. All 244 tests in
`packages/genkit` pass, and `dart analyze testapps` returns no issues. The
`dartastic_opentelemetry_api` offers a modern, type-safe approach to
OpenTelemetry in Dart, providing a solid foundation for future observability
features.
