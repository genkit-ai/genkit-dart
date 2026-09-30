# Anthropic sample

Structured output with the `genkit_anthropic` plugin.

```bash
export ANTHROPIC_API_KEY=...
dart run build_runner build   # after changing a @Schema class
genkit start -- dart run lib/structured_output.dart
```

Flows in `lib/structured_output.dart`:

| Flow | Shows |
| --- | --- |
| `recipe` | Native structured output (`output_config.format`) |
| `recipeUncuratedModel` | A model name the plugin doesn't curate still goes native |
| `recipeStreamed` | Partial output streamed as the JSON arrives |
| `recipeWithTools` | A structured reply combined with your own tool and extended thinking |
| `scorecardPromptFallback` | A `Map` field, which Anthropic can't constrain, so the schema goes in the prompt |
| `taxonomyPromptFallback` | A recursive type, which also goes in the prompt |
