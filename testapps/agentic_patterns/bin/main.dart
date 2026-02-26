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

import 'dart:convert';
import 'dart:io';

import 'package:agentic_patterns/agentic_rag.dart';
import 'package:agentic_patterns/autonomous_operation.dart';
import 'package:agentic_patterns/conditional_routing.dart';
import 'package:agentic_patterns/iterative_refinement.dart';
import 'package:agentic_patterns/parallel_execution.dart';
import 'package:agentic_patterns/sequential_processing.dart';
import 'package:agentic_patterns/stateful_interactions.dart';
import 'package:agentic_patterns/tool_calling.dart';
import 'package:genkit/genkit.dart';
import 'package:genkit_google_genai/genkit_google_genai.dart';

void main(List<String> arguments) async {
  // Initialize Genkit and Model
  final ai = Genkit(plugins: [googleAI()]);
  final geminiFlash = googleAI.gemini('gemini-2.5-flash');

  // Initialize Flows
  final iterativeRefinementFlow = defineIterativeRefinementFlow(
    ai,
    geminiFlash,
  );
  final storyWriterFlow = defineStoryWriterFlow(ai, geminiFlash);
  final marketingCopyFlow = defineMarketingCopyFlow(ai, geminiFlash);
  final routerFlow = defineRouterFlow(ai, geminiFlash);
  final toolCallingFlow = defineToolCallingFlow(ai, geminiFlash);
  final researchAgent = defineResearchAgent(ai, geminiFlash);
  final agenticRagFlow = defineAgenticRagFlow(ai, geminiFlash);
  final statefulChatFlow = defineStatefulChatFlow(ai, geminiFlash);
  final imageGeneratorFlow = defineImageGeneratorFlow(ai, geminiFlash);

  if (arguments.isEmpty) {
    print('Usage: dart run bin/main.dart <command> [args]');
    print('Available commands:');
    print('  iterativeRefinement "<topic>"');
    print('  sequentialProcessing "<topic>"');
    print('  parallelExecution "<product>"');
    print('  conditionalRouting "<query>"');
    print('  toolCalling "<prompt>"');
    print('  autonomousOperation "<task>"');
    print('  agenticRag "<question>"');
    print('  statefulInteractions "<sessionId>" "<message>"');
    print('  imageGenerator "<concept>"');
    return;
  }

  final command = arguments[0];
  final args = arguments.sublist(1);

  switch (command) {
    case 'iterativeRefinement':
      if (args.isEmpty) {
        print('Usage: iterativeRefinement "<topic>"');
        return;
      }
      final topic = args[0];
      print('Running Iterative Refinement for topic: "$topic"...\n');
      final result = await iterativeRefinementFlow(
        IterativeRefinementInput(topic: topic),
      );
      print('\nFinal Result:\n$result');
      break;
    case 'sequentialProcessing':
      if (args.isEmpty) {
        print('Usage: sequentialProcessing "<topic>"');
        return;
      }
      final topic = args[0];
      print('Running Sequential Processing for topic: "$topic"...\n');
      final result = await storyWriterFlow(StoryInput(topic: topic));
      print('\nFinal Result:\n$result');
      break;
    case 'parallelExecution':
      if (args.isEmpty) {
        print('Usage: parallelExecution "<product>"');
        return;
      }
      final product = args[0];
      print('Running Parallel Execution for product: "$product"...\n');
      final result = await marketingCopyFlow(ProductInput(product: product));
      print(
        '\nFinal Result:\nName: ${result.name}\nTagline: ${result.tagline}',
      );
      break;
    case 'conditionalRouting':
      if (args.isEmpty) {
        print('Usage: conditionalRouting "<query>"');
        return;
      }
      final query = args[0];
      print('Running Conditional Routing for query: "$query"...\n');
      final result = await routerFlow(RouterInput(query: query));
      print('\nFinal Result:\n$result');
      break;
    case 'toolCalling':
      if (args.isEmpty) {
        print('Usage: toolCalling "<prompt>"');
        return;
      }
      final prompt = args[0];
      print('Running Tool Calling for prompt: "$prompt"...\n');
      final result = await toolCallingFlow(ToolCallingInput(prompt: prompt));
      print('\nFinal Result:\n$result');
      break;
    case 'autonomousOperation':
      if (args.isEmpty) {
        print('Usage: autonomousOperation "<task>"');
        return;
      }
      final task = args[0];
      print('Running Autonomous Operation for task: "$task"...\n');
      final result = await researchAgent(ResearchAgentInput(task: task));
      print('\nFinal Result:\n$result');
      break;
    case 'agenticRag':
      if (args.isEmpty) {
        print('Usage: agenticRag "<question>"');
        return;
      }
      final question = args[0];
      print('Running Agentic RAG for question: "$question"...\n');
      final result = await agenticRagFlow(AgenticRagInput(question: question));
      print('\nFinal Result:\n$result');
      break;
    case 'statefulInteractions':
      if (args.length < 2) {
        print('Usage: statefulInteractions "<sessionId>" "<message>"');
        return;
      }
      final sessionId = args[0];
      final message = args[1];
      print('Running Stateful Interactions for session: "$sessionId"...\n');
      final result = await statefulChatFlow(
        StatefulChatInput(sessionId: sessionId, message: message),
      );
      print('\nFinal Result:\n$result');
      break;
    case 'imageGenerator':
      if (args.isEmpty) {
        print('Usage: imageGenerator "<concept>"');
        return;
      }
      final concept = args[0];
      print('Running Image Generator for concept: "$concept"...\n');
      final result = await imageGeneratorFlow(
        ImageGeneratorInput(concept: concept),
      );

      if (result.startsWith('data:')) {
        try {
          final base64idx = result.indexOf('base64,');
          if (base64idx != -1) {
            final base64Str = result.substring(base64idx + 7);
            final bytes = base64Decode(base64Str);
            final sanitizedConcept = concept.replaceAll(
              RegExp(r'[^a-zA-Z0-9]'),
              '_',
            );
            final fileName = 'generated_image_$sanitizedConcept.png';
            final file = File(fileName);
            await file.writeAsBytes(bytes);
            print('\nFinal Result (Saved to file):\n${file.absolute.path}');
          } else {
            print('\nFinal Result (Image URL):\n$result');
          }
        } catch (e) {
          print('Error saving image: $e');
          print('\nFinal Result (Image URL):\n$result');
        }
      } else {
        print('\nFinal Result (Image URL):\n$result');
      }
      break;
    default:
      print('Unknown command: $command');
  }
}
