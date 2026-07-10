---
name: dart
description: Conventions and best practices for writing Dart code in this workspace.
---

# Dart coding conventions

- Prefer `final` over `var` where the value never changes.
- Use lowerCamelCase for variables and functions, UpperCamelCase for types.
- Keep functions small and focused; prefer pure functions where practical.
- Always handle errors explicitly; avoid swallowing exceptions silently.
- Add a doc comment (`///`) to every public declaration.
- Use `dart format` defaults (80-column width) for all files.
- Prefer collection literals and spread operators over imperative building.
