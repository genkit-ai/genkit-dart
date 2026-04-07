// Copyright 2025 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:flutter/material.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit/lite.dart' as lite;
import 'package:genkit/client.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';
import 'package:genkit_anthropic/genkit_anthropic.dart';

import 'types.dart';

void main() {
  final ai = Genkit();

  ai.defineTool(
    name: 'checkPantry',
    description: 'Checks if we have specific spices in the kitchen pantry',
    inputSchema: CheckPantryInput.$schema,
    fn: (CheckPantryInput input, _) async =>
        input.spice.toLowerCase() == 'cumin' ? 'Out of stock' : 'In stock',
  );

  ai.defineRemoteModel(
    name: 'googleai/gemini-2.5-flash',
    url: 'http://localhost:8080/googleai/gemini-2.5-flash',
  );
  ai.defineRemoteModel(
    name: 'openai/gpt-4o',
    url: 'http://localhost:8080/openai/gpt-4o',
  );
  ai.defineRemoteModel(
    name: 'anthropic/claude-sonnet-4-5',
    url: 'http://localhost:8080/anthropic/claude-sonnet-4-5',
  );

  runApp(MyApp(ai: ai));
}

class MyApp extends StatelessWidget {
  final Genkit ai;
  const MyApp({super.key, required this.ai});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Flutter GenAI'),
            bottom: const TabBar(
              tabs: [
                Tab(text: 'Client-side'),
                Tab(text: 'Remote Model'),
                Tab(text: 'Server Flow'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              ClientSideTab(),
              RemoteModelTab(ai: ai),
              ServerFlowTab(),
            ],
          ),
        ),
      ),
    );
  }
}

enum AiProvider { google, openai, anthropic }

class ClientSideTab extends StatefulWidget {
  const ClientSideTab({super.key});

  @override
  State<ClientSideTab> createState() => _ClientSideTabState();
}

class _ClientSideTabState extends State<ClientSideTab> {
  final _apiKeyController = TextEditingController();
  final _dietFriendlyController = TextEditingController(text: 'Vegan');
  final _mainIngredientController = TextEditingController(text: 'Tofu');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    final apiKey = _apiKeyController.text;
    if (apiKey.isEmpty) {
      setState(() => _output = 'Error: API Key is required for client side.');
      return;
    }

    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final tool = Tool(
        name: 'checkPantry',
        description: 'Checks if we have specific spices in the kitchen pantry',
        inputSchema: CheckPantryInput.$schema,
        fn: (CheckPantryInput input, _) async =>
            input.spice.toLowerCase() == 'cumin' ? 'Out of stock' : 'In stock',
      );

      final model = switch (_selectedProvider) {
        AiProvider.google => googleAI(apiKey: apiKey).model('gemini-2.5-flash'),
        AiProvider.openai => openAI(apiKey: apiKey).model('gpt-4o'),
        AiProvider.anthropic => anthropic(
          apiKey: apiKey,
          headers: {
            // Required for direct browser access.
            // DO NOT use this in production.
            'anthropic-dangerous-direct-browser-access': 'true',
          },
        ).model('claude-sonnet-4-5'),
      };

      final stream = lite.generateStream(
        model: model,
        prompt:
            'Create a ${_dietFriendlyController.text} recipe using ${_mainIngredientController.text}. '
            'Before suggesting spices, check the pantry to see if we have them.',
        tools: [tool],
      );

      await for (final chunk in stream) {
        setState(() => _output += chunk.text);
      }
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _dietFriendlyController.dispose();
    _mainIngredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<AiProvider>(
            value: _selectedProvider,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: AiProvider.google,
                child: Text('Google Gemini'),
              ),
              DropdownMenuItem(value: AiProvider.openai, child: Text('OpenAI')),
              DropdownMenuItem(
                value: AiProvider.anthropic,
                child: Text('Anthropic'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              labelText: switch (_selectedProvider) {
                AiProvider.google => 'Gemini API Key',
                AiProvider.openai => 'OpenAI API Key',
                AiProvider.anthropic => 'Anthropic API Key',
              },
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _generate,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Generate Locally'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Text(_output))),
        ],
      ),
    );
  }
}

class RemoteModelTab extends StatefulWidget {
  final Genkit ai;
  const RemoteModelTab({super.key, required this.ai});

  @override
  State<RemoteModelTab> createState() => _RemoteModelTabState();
}

class _RemoteModelTabState extends State<RemoteModelTab> {
  final _dietFriendlyController = TextEditingController(text: 'Vegan');
  final _mainIngredientController = TextEditingController(text: 'Tofu');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final modelName = switch (_selectedProvider) {
        AiProvider.google => 'googleai/gemini-2.5-flash',
        AiProvider.openai => 'openai/gpt-4o',
        AiProvider.anthropic => 'anthropic/claude-sonnet-4-5',
      };

      final stream = widget.ai.generateStream(
        model: modelRef(modelName),
        prompt:
            'Create a ${_dietFriendlyController.text} recipe using ${_mainIngredientController.text}. '
            'Before suggesting spices, check the pantry to see if we have them.',
        toolNames: ['checkPantry'],
      );

      await for (final chunk in stream) {
        setState(() => _output += chunk.text);
      }
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _dietFriendlyController.dispose();
    _mainIngredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<AiProvider>(
            value: _selectedProvider,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: AiProvider.google,
                child: Text('Google Gemini (via Server)'),
              ),
              DropdownMenuItem(
                value: AiProvider.openai,
                child: Text('OpenAI (via Server)'),
              ),
              DropdownMenuItem(
                value: AiProvider.anthropic,
                child: Text('Anthropic (via Server)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _generate,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Call Remote Model'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Text(_output))),
        ],
      ),
    );
  }
}

class ServerFlowTab extends StatefulWidget {
  const ServerFlowTab({super.key});

  @override
  State<ServerFlowTab> createState() => _ServerFlowTabState();
}

class _ServerFlowTabState extends State<ServerFlowTab> {
  final _dietFriendlyController = TextEditingController(text: 'Vegan');
  final _mainIngredientController = TextEditingController(text: 'Tofu');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final remoteFlow = defineRemoteAction(
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
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _dietFriendlyController.dispose();
    _mainIngredientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButton<AiProvider>(
            value: _selectedProvider,
            isExpanded: true,
            items: const [
              DropdownMenuItem(
                value: AiProvider.google,
                child: Text('Google Gemini (via ServerFlow)'),
              ),
              DropdownMenuItem(
                value: AiProvider.openai,
                child: Text('OpenAI (via ServerFlow)'),
              ),
              DropdownMenuItem(
                value: AiProvider.anthropic,
                child: Text('Anthropic (via ServerFlow)'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
          const Text(
            'Executes a remote action named `serverFlow`',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
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
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _generate,
            child: _isLoading
                ? const CircularProgressIndicator()
                : const Text('Call Server Flow'),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Expanded(child: SingleChildScrollView(child: Text(_output))),
        ],
      ),
    );
  }
}
