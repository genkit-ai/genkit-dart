import 'package:agentic_patterns/agentic_rag.dart';
import 'package:agentic_patterns/autonomous_operation.dart';
import 'package:agentic_patterns/conditional_routing.dart';
import 'package:agentic_patterns/iterative_refinement.dart';
import 'package:agentic_patterns/parallel_execution.dart';
import 'package:agentic_patterns/sequential_processing.dart';
import 'package:agentic_patterns/tool_calling.dart';

void main(List<String> arguments) async {
  if (arguments.isEmpty) {
    print('Usage: dart run bin/main.dart <command> [args]');
    print('Available commands:');
    print('  iterativeRefinement "<topic>"');
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
      final result =
          await iterativeRefinementFlow(IterativeRefinementInput(topic: topic));
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
          '\nFinal Result:\nName: ${result.name}\nTagline: ${result.tagline}');
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
    default:
      print('Unknown command: $command');
  }
}
