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
import 'package:genkit/client.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';

import 'types.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          body: const TabBarView(
            children: [
              ClientSideTab(),
              RemoteModelTab(),
              ServerFlowTab(),
            ],
          ),
        ),
      ),
    );
  }
}

enum AiProvider { google, openai }

class ClientSideTab extends StatefulWidget {
  const ClientSideTab({super.key});

  @override
  State<ClientSideTab> createState() => _ClientSideTabState();
}

class _ClientSideTabState extends State<ClientSideTab> {
  final _apiKeyController = TextEditingController();
  final _promptController = TextEditingController(text: 'Say hello');
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
      final ai = Genkit(
        plugins: [
          _selectedProvider == AiProvider.google
              ? googleAI(apiKey: apiKey)
              : openAI(apiKey: apiKey)
        ],
      );

      final model = _selectedProvider == AiProvider.google
          ? googleAI.gemini('gemini-2.5-flash')
          : openAI.model('gpt-4o');

      final response = await ai.generate(
        model: model,
        prompt: _promptController.text,
      );

      setState(() => _output = response.text);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _promptController.dispose();
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
                  value: AiProvider.google, child: Text('Google Gemini')),
              DropdownMenuItem(value: AiProvider.openai, child: Text('OpenAI')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: InputDecoration(
              labelText: _selectedProvider == AiProvider.google
                  ? 'Gemini API Key'
                  : 'OpenAI API Key',
              border: const OutlineInputBorder(),
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
                labelText: 'Prompt', border: OutlineInputBorder()),
            maxLines: 3,
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
  const RemoteModelTab({super.key});

  @override
  State<RemoteModelTab> createState() => _RemoteModelTabState();
}

class _RemoteModelTabState extends State<RemoteModelTab> {
  final _promptController = TextEditingController(text: 'Say hello');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final ai = Genkit();

      final url = _selectedProvider == AiProvider.google
          ? 'http://localhost:8080/googleai/gemini-2.5-flash'
          : 'http://localhost:8080/openai/gpt-4o';

      final remoteModel = ai.defineRemoteModel(
        name: 'remoteModel',
        url: url,
      );

      final response = await ai.generate(
        model: remoteModel,
        prompt: _promptController.text,
      );

      setState(() => _output = response.text);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
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
                  child: Text('Google Gemini (via Server)')),
              DropdownMenuItem(
                  value: AiProvider.openai, child: Text('OpenAI (via Server)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
                labelText: 'Prompt', border: OutlineInputBorder()),
            maxLines: 3,
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
  final _promptController = TextEditingController(text: 'Say hello');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    setState(() {
      _isLoading = true;
      _output = '';
    });

    try {
      final remoteFlow = defineRemoteAction<ServerFlowInput, String, void, void>(
        url: 'http://localhost:8080/serverFlow',
        inputSchema: ServerFlowInput.$schema,
        outputSchema: .string(),
      );

      final response = await remoteFlow(
        input: ServerFlowInput(
          provider: _selectedProvider == AiProvider.google ? 'google' : 'openai',
          prompt: _promptController.text,
        ),
      );
      setState(() => _output = response);
    } catch (e) {
      setState(() => _output = 'Error: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _promptController.dispose();
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
                  child: Text('Google Gemini (via ServerFlow)')),
              DropdownMenuItem(
                  value: AiProvider.openai, child: Text('OpenAI (via ServerFlow)')),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _selectedProvider = val);
            },
          ),
          const SizedBox(height: 16),
          const Text('Executes a remote action named `serverFlow`',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _promptController,
            decoration: const InputDecoration(
                labelText: 'Prompt', border: OutlineInputBorder()),
            maxLines: 3,
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
