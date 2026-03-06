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
import 'package:genkit_google_genai/genkit_google_genai.dart';
import 'package:genkit_openai/genkit_openai.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

enum AiProvider { google, openai }

class _MyAppState extends State<MyApp> {
  final _apiKeyController = TextEditingController();
  final _controller = TextEditingController(text: 'Say hello');
  String _output = '';
  bool _isLoading = false;
  AiProvider _selectedProvider = AiProvider.google;

  Future<void> _generate() async {
    final apiKey = _apiKeyController.text;
    if (apiKey.isEmpty) {
      setState(() {
        _output = 'Error: API Key is required.';
      });
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
        prompt: _controller.text,
      );
      setState(() {
        _output = response.text;
      });
    } catch (e) {
      setState(() {
        _output = 'Error: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Flutter GenAI')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              DropdownButton<AiProvider>(
                value: _selectedProvider,
                isExpanded: true,
                items: const [
                  DropdownMenuItem(
                    value: AiProvider.google,
                    child: Text('Google Gemini'),
                  ),
                  DropdownMenuItem(
                    value: AiProvider.openai,
                    child: Text('OpenAI'),
                  ),
                ],
                onChanged: (value) {
                  setState(() {
                    if (value != null) _selectedProvider = value;
                  });
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
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: 'Prompt',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _isLoading ? null : _generate,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Generate'),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              Expanded(child: SingleChildScrollView(child: Text(_output))),
            ],
          ),
        ),
      ),
    );
  }
}
