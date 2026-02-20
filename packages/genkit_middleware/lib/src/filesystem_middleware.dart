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
import 'package:genkit/plugin.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';

part 'filesystem_middleware.g.dart';

@Schematic()
abstract class $FilesystemOptions {
  @Field(
    description:
        'The root directory to which all filesystem operations are restricted.',
  )
  String get rootDirectory;
}

@Schematic()
abstract class $ListFilesInput {
  @Field(description: 'Directory path relative to root.', defaultValue: '')
  String? get dirPath;
  @Field(description: 'Whether to list files recursively.', defaultValue: false)
  bool? get recursive;
}

@Schematic()
abstract class $ReadFileInput {
  @Field(description: 'File path relative to root.')
  String get filePath;
}

@Schematic()
abstract class $WriteFileInput {
  @Field(description: 'File path relative to root.')
  String get filePath;
  @Field(description: 'Content to write to the file.')
  String get content;
}

@Schematic()
abstract class $SearchAndReplaceInput {
  @Field(description: 'File path relative to root.')
  String get filePath;
  @Field(
    description:
        'A search and replace block string in the format:\n'
        '<<<<<<< SEARCH\n[search content]\n=======\n[replace content]\n>>>>>>> REPLACE',
  )
  List<String> get edits;
}

@Schematic()
abstract class $ListFileOutputItem {
  String get path;
  bool get isDirectory;
}

class FilesystemPlugin extends GenkitPlugin {
  @override
  String get name => 'filesystem';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<FilesystemOptions>(
      name: 'filesystem',
      configSchema: FilesystemOptions.$schema,
      create: ([FilesystemOptions? config]) {
        if (config == null) {
          throw ArgumentError(
            'filesystem middleware requires a rootDirectory option',
          );
        }
        return FilesystemMiddleware(config.rootDirectory);
      },
    ),
  ];
}

GenerateMiddlewareRef<FilesystemOptions> filesystem({
  required String rootDirectory,
}) {
  return middlewareRef(
    name: 'filesystem',
    config: FilesystemOptions(rootDirectory: rootDirectory),
  );
}

class FilesystemMiddleware extends GenerateMiddleware {
  final String rootDirectory;
  final List<Message> _messageQueue = [];

  FilesystemMiddleware(this.rootDirectory);

  String _resolvePath(String relativePath) {
    // Normalize and resolve the path
    final resolved = p.canonicalize(p.join(rootDirectory, relativePath));
    // Check if the path is within the root path
    if (!p.isWithin(rootDirectory, resolved) && resolved != rootDirectory) {
      throw Exception('Access denied: Path is outside of root directory.');
    }
    return resolved;
  }

  @override
  List<Tool> get tools => [
    Tool<ListFilesInput, List<ListFileOutputItem>>(
      name: 'list_files',
      description:
          'Lists files and directories in a given path. Returns a list of objects with path and type.',
      inputSchema: ListFilesInput.$schema,
      outputSchema: listSchema(ListFileOutputItem.$schema),
      fn: (input, _) async {
        final dirPath = _resolvePath(input.dirPath ?? '');
        final recursive = input.recursive ?? false;

        Future<List<ListFileOutputItem>> list(String dir, String base) async {
          final results = <ListFileOutputItem>[];
          final d = Directory(dir);
          if (!await d.exists()) return results;

          await for (final entity in d.list()) {
            final name = p.basename(entity.path);
            final relativePath = p.join(base, name);
            final isDirectory = entity is Directory;

            results.add(
              ListFileOutputItem(path: relativePath, isDirectory: isDirectory),
            );

            if (isDirectory && recursive) {
              results.addAll(await list(entity.path, relativePath));
            }
          }
          return results;
        }

        return await list(dirPath, input.dirPath ?? '');
      },
    ),
    Tool<ReadFileInput, String>(
      name: 'read_file',
      description: 'Reads the contents of a file',
      inputSchema: ReadFileInput.$schema,
      outputSchema: stringSchema(),
      fn: (input, _) async {
        final filePath = _resolvePath(input.filePath);
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist: ${input.filePath}');
        }

        final mimeType = lookupMimeType(filePath);
        final isImage = mimeType != null && mimeType.startsWith('image/');

        final parts = <Part>[];

        if (isImage) {
          final bytes = await file.readAsBytes();
          final base64String = base64Encode(bytes);
          final uri = 'data:$mimeType;base64,$base64String';

          parts.add(
            TextPart(text: '\n\nread_file result $mimeType ${input.filePath}'),
          );
          parts.add(
            MediaPart(
              media: Media(url: uri, contentType: mimeType),
            ),
          );
        } else {
          final content = await file.readAsString();
          parts.add(
            TextPart(
              text:
                  '<read_file path="${input.filePath}">\n$content\n</read_file>',
            ),
          );
        }

        if (_messageQueue.isNotEmpty && _messageQueue.last.role == Role.user) {
          final lastMsg = _messageQueue.last;
          _messageQueue
              .removeLast(); // We will modify and re-add or just modify content
          // Modifying content of existing message is tricky with immutable structures
          // But we are managing _messageQueue ourselves
          final newContent = [...lastMsg.content, ...parts];
          _messageQueue.add(Message(role: Role.user, content: newContent));
        } else {
          _messageQueue.add(Message(role: Role.user, content: parts));
        }

        return 'File ${input.filePath} read successfully, see contents below';
      },
    ),
    Tool<WriteFileInput, String>(
      name: 'write_file',
      description: 'Writes content to a file, overwriting it if it exists.',
      inputSchema: WriteFileInput.$schema,
      outputSchema: stringSchema(),
      fn: (input, _) async {
        final filePath = _resolvePath(input.filePath);
        final file = File(filePath);
        await file.parent.create(recursive: true);
        await file.writeAsString(input.content);
        return 'File ${input.filePath} written successfully.';
      },
    ),
    Tool<SearchAndReplaceInput, String>(
      name: 'search_and_replace',
      description: 'Replaces text in a file using search and replace blocks. ',
      inputSchema: SearchAndReplaceInput.$schema,
      outputSchema: stringSchema(),
      fn: (input, _) async {
        final filePath = _resolvePath(input.filePath);
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist: ${input.filePath}');
        }

        var content = await file.readAsString();

        for (final editBlock in input.edits) {
          const startMarker = '<<<<<<< SEARCH\n';
          const endMarker = '\n>>>>>>> REPLACE';
          const separator = '\n=======\n';

          if (!editBlock.startsWith(startMarker) ||
              !editBlock.endsWith(endMarker)) {
            throw Exception(
              'Invalid edit block format. Block must start with "<<<<<<< SEARCH\\n" and end with "\\n>>>>>>> REPLACE"',
            );
          }

          final innerContent = editBlock.substring(
            startMarker.length,
            editBlock.length - endMarker.length,
          );

          // Find all possible separator positions
          final separatorIndices = <int>[];
          var pos = innerContent.indexOf(separator);
          while (pos != -1) {
            separatorIndices.add(pos);
            pos = innerContent.indexOf(separator, pos + 1);
          }

          if (separatorIndices.isEmpty) {
            throw Exception(
              'Invalid edit block format. Missing separator "\\n=======\\n"',
            );
          }

          String? bestSearch;
          String? bestReplace;

          for (final splitIndex in separatorIndices) {
            final search = innerContent.substring(0, splitIndex);
            final replace = innerContent.substring(
              splitIndex + separator.length,
            );

            if (content.contains(search)) {
              if (bestSearch == null || search.length > bestSearch.length) {
                bestSearch = search;
                bestReplace = replace;
              }
            }
          }

          if (bestSearch == null) {
            throw Exception(
              'Search content not found in file ${input.filePath}. '
              'Make sure the search block matches the file content exactly, '
              'including whitespace and indentation.',
            );
          }

          // Apply replacement (first occurrence only)
          content = content.replaceFirst(bestSearch, bestReplace!);
        }

        await file.writeAsString(content);
        return 'Successfully applied ${input.edits.length} edit(s) to ${input.filePath}.';
      },
    ),
  ];

  @override
  Future<GenerateResponseHelper> generate(
    GenerateActionOptions options,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResponseHelper> Function(
      GenerateActionOptions options,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    if (_messageQueue.isNotEmpty) {
      final messages = List<Message>.from(options.messages);
      messages.addAll(_messageQueue);
      _messageQueue.clear();

      final newOptions = GenerateActionOptions(
        model: options.model,
        docs: options.docs,
        messages: messages,
        tools: options.tools,
        toolChoice: options.toolChoice,
        config: options.config,
        output: options.output,
        resume: options.resume,
        returnToolRequests: options.returnToolRequests,
        maxTurns: options.maxTurns,
        stepName: options.stepName,
      );
      return next(newOptions, ctx);
    }
    return next(options, ctx);
  }

  @override
  Future<ToolResponse> tool(
    ToolRequest request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResponse> Function(
      ToolRequest request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    try {
      return await next(request, ctx);
    } catch (e) {
      // Check if this tool is one of ours
      if ([
        'list_files',
        'read_file',
        'write_file',
        'search_and_replace',
      ].contains(request.name)) {
        final errorText = "Tool '${request.name}' failed: $e";

        if (_messageQueue.isNotEmpty && _messageQueue.last.role == Role.user) {
          final lastMsg = _messageQueue.last;
          _messageQueue.removeLast();
          final newContent = [...lastMsg.content, TextPart(text: errorText)];
          _messageQueue.add(Message(role: Role.user, content: newContent));
        } else {
          _messageQueue.add(
            Message(
              role: Role.user,
              content: [TextPart(text: errorText)],
            ),
          );
        }

        // Return a response to satisfy the signature, but the model will primarily see the user message
        return ToolResponse(
          name: request.name,
          output: 'Tool failed. See context for details.',
        );
      }
      rethrow;
    }
  }
}
