import re

with open('lib/main.dart', 'r') as f:
    content = f.read()

# Replace _promptController with _dietFriendlyController and _mainIngredientController declarations
content = content.replace("final _promptController = TextEditingController(text: 'Say hello');",
                          "final _dietFriendlyController = TextEditingController(text: 'Vegan');\n  final _mainIngredientController = TextEditingController(text: 'Tofu');")

# In ClientSideTab:
client_tab_gen = """
      ai.defineTool(
        name: 'checkPantry',
        description: 'Checks if we have specific spices in the kitchen pantry',
        inputSchema: .string(description: 'The spice to check'),
        fn: (spice, _) async => spice.toLowerCase() == 'cumin' ? 'Out of stock' : 'In stock',
      );

      final model = switch (_selectedProvider) {
        AiProvider.google => googleAI.gemini('gemini-2.5-flash'),
        AiProvider.openai => openAI.model('gpt-4o'),
        AiProvider.anthropic => anthropic.model('claude-sonnet-4-5'),
      };

      final stream = await ai.generateStream(
        model: model,
        prompt: 'Create a ${_dietFriendlyController.text} recipe using ${_mainIngredientController.text}. '
                'Before suggesting spices, check the pantry to see if we have them.',
        toolNames: ['checkPantry'],
      );

      await for (final chunk in stream) {
        setState(() => _output += chunk.text);
      }
"""

content = re.sub(r"      final model = switch \(_selectedProvider\) \{.*?setState\(\(\) => _output = response\.text\);", client_tab_gen.strip(), content, flags=re.DOTALL, count=1)


# In RemoteModelTab:
remote_tab_gen = """
      final url = switch (_selectedProvider) {
        AiProvider.google => 'http://localhost:8080/googleai/gemini-2.5-flash',
        AiProvider.openai => 'http://localhost:8080/openai/gpt-4o',
        AiProvider.anthropic =>
          'http://localhost:8080/anthropic/claude-sonnet-4-5',
      };

      final remoteModel = ai.defineRemoteModel(name: 'remoteModel', url: url);

      ai.defineTool(
        name: 'checkPantry',
        description: 'Checks if we have specific spices in the kitchen pantry',
        inputSchema: .string(description: 'The spice to check'),
        fn: (spice, _) async => spice.toLowerCase() == 'cumin' ? 'Out of stock' : 'In stock',
      );

      final stream = await ai.generateStream(
        model: remoteModel,
        prompt: 'Create a ${_dietFriendlyController.text} recipe using ${_mainIngredientController.text}. '
                'Before suggesting spices, check the pantry to see if we have them.',
        toolNames: ['checkPantry'],
      );

      await for (final chunk in stream) {
        setState(() => _output += chunk.text);
      }
"""
content = re.sub(r"      final url = switch \(_selectedProvider\) \{.*?setState\(\(\) => _output = response\.text\);", remote_tab_gen.strip(), content, flags=re.DOTALL, count=1)


# In ServerFlowTab:
server_tab_gen = """
      final remoteFlow =
          defineRemoteAction<RecipeRequest, String, void, String>(
            url: 'http://localhost:8080/serverFlow',
            inputSchema: RecipeRequest.$schema,
            outputSchema: .string(),
            streamSchema: .string(),
          );

      final stream = remoteFlow.stream(
        input: RecipeRequest(
          provider: _selectedProvider.name,
          dietFriendly: _dietFriendlyController.text,
          mainIngredient: _mainIngredientController.text,
        ),
      );

      await for (final chunk in stream) {
        setState(() => _output += chunk);
      }
"""
content = re.sub(r"      final remoteFlow =.*?setState\(\(\) => _output = response\);", server_tab_gen.strip(), content, flags=re.DOTALL, count=1)


# Fix dispose methods
content = content.replace("_promptController.dispose();", "_dietFriendlyController.dispose();\n    _mainIngredientController.dispose();")

# Fix UI fields
ui_fields = """
          TextField(
            controller: _dietFriendlyController,
            decoration: const InputDecoration(
              labelText: 'Diet Friendly',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _mainIngredientController,
            decoration: const InputDecoration(
              labelText: 'Main Ingredient',
              border: OutlineInputBorder(),
            ),
          ),
"""

content = re.sub(r"          TextField\(\s+controller: _promptController,\s+decoration: const InputDecoration\(\s+labelText: 'Prompt',\s+border: OutlineInputBorder\(\),\s+\),\s+maxLines: 3,\s+\),", ui_fields.strip(), content)

with open('lib/main.dart', 'w') as f:
    f.write(content)
