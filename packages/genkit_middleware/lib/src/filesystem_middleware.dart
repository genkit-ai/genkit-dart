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

@Schema()
abstract class $FilesystemOptions {
  @Field(
    description:
        'The root directory to which all filesystem operations are restricted.',
  )
  String get rootDirectory;
}

@Schema()
abstract class $ListFilesInput {
  @Field(description: 'Directory path relative to root.', defaultValue: '')
  String? get dirPath;
  @Field(description: 'Whether to list files recursively.', defaultValue: false)
  bool? get recursive;
}

@Schema()
abstract class $ReadFileInput {
  @Field(description: 'File path relative to root.')
  String get filePath;
}

@Schema()
abstract class $WriteFileInput {
  @Field(description: 'File path relative to root.')
  String get filePath;
  @Field(description: 'Content to write to the file.')
  String get content;
}

@Schema()
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

@Schema()
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
      create: (config, ctx) {
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

  late final String _lexicalRoot = p.canonicalize(rootDirectory);

  // Resolved lazily (and once) so a root that doesn't exist yet still works,
  // and so a root that is itself a symlink (e.g. macOS /tmp) compares equal to
  // the real paths of its children.
  late final String _realRoot = _realPath(_lexicalRoot) ?? _throwAccessDenied();

  /// Resolves [relativePath] against [rootDirectory] and returns the real
  /// (symlink-free) path, or throws if it points outside the root.
  ///
  /// There is an unavoidable gap between this check and the I/O that follows
  /// (TOCTOU). None of the tools can create links, so the model can't exploit
  /// it on its own; something else would have to swap a path for a link in
  /// between.
  String _resolvePath(String relativePath) =>
      _resolvePathOrNull(relativePath) ?? _throwAccessDenied();

  /// Like [_resolvePath], but returns null instead of throwing.
  String? _resolvePathOrNull(String relativePath) {
    // Lexical check first: cheap, and rejects `..` and absolute paths early.
    final lexical = p.canonicalize(p.join(_lexicalRoot, relativePath));
    if (!_isWithinOrEqual(_lexicalRoot, lexical)) return null;

    // Then follow symlinks, so a link inside the root can't point outside it.
    final real = _realPath(lexical);
    if (real == null || !_isWithinOrEqual(_realRoot, real)) return null;
    return real;
  }

  static bool _isWithinOrEqual(String root, String path) =>
      p.equals(root, path) || p.isWithin(root, path);

  static Never _throwAccessDenied() => throw GenkitException(
    'Access denied: Path is outside of root directory.',
    status: StatusCode.permissionDenied,
  );

  /// Returns the real path of the absolute [path], following every symlink
  /// along the way, or null if there are too many links (most likely a cycle).
  ///
  /// Walks one component at a time, like the OS does. Link targets are spliced
  /// into the remaining components instead of being normalized, because a
  /// `..` in a target applies to wherever the links before it lead, not to the
  /// lexical parent. Components that don't exist yet (e.g. for `write_file`)
  /// are kept as is. Dangling links are followed too, since writing through
  /// one would create its (possibly outside) target.
  static String? _realPath(String path) {
    final pending = p.split(path);
    // Symlink-free at every step, so `..` can be applied lexically.
    var resolved = pending.removeAt(0);
    var hops = 0;
    while (pending.isNotEmpty) {
      final part = pending.removeAt(0);
      if (part == '.') continue;
      if (part == '..') {
        resolved = p.dirname(resolved);
        continue;
      }
      final next = p.join(resolved, part);
      // Check every component, even below a missing one: `missing/../link`
      // climbs back into existing territory, and `link` must still be followed.
      if (FileSystemEntity.typeSync(next, followLinks: false) ==
          FileSystemEntityType.link) {
        // Same limit as Linux's MAXSYMLINKS; also stops link cycles.
        if (++hops > 40) return null;
        final String target;
        try {
          target = Link(next).targetSync();
        } on FileSystemException {
          // Swapped or unreadable mid-walk. Failing closed also keeps the real
          // path out of the error the model would see.
          return null;
        }
        final targetParts = p.split(target);
        if (p.isAbsolute(target)) resolved = targetParts.removeAt(0);
        pending.insertAll(0, targetParts);
        continue;
      }
      resolved = next;
    }
    return resolved;
  }

  /// Runs [body], reporting I/O errors against [path] (as the model gave it)
  /// rather than the resolved path, which would reveal where an aliased root
  /// really lives.
  ///
  /// Rethrown as a plain [FileSystemException]; subtypes such as
  /// [PathNotFoundException] are not preserved.
  static Future<T> _withModelPath<T>(
    String path,
    Future<T> Function() body,
  ) async {
    try {
      return await body();
    } on FileSystemException catch (e) {
      throw FileSystemException(e.message, path, e.osError);
    }
  }

  @override
  List<Tool> get tools => [
    Tool<ListFilesInput, List<ListFileOutputItem>>(
      name: 'list_files',
      description:
          'Lists files and directories in a given path. Returns a list of objects with path and type.',
      inputSchema: ListFilesInput.$schema,
      outputSchema: .list(ListFileOutputItem.$schema),
      fn: (input, _) async {
        final dirPath = _resolvePath(input.dirPath ?? '');
        final recursive = input.recursive ?? false;

        // [dir] is a real path, [base] is the same directory relative to the
        // root (as the model sees it).
        Future<List<ListFileOutputItem>> list(String dir, String base) async {
          final results = <ListFileOutputItem>[];
          final d = Directory(dir);
          if (!await d.exists()) return results;

          final entities = await _withModelPath(
            base.isEmpty ? '.' : base,
            () => d.list(followLinks: false).toList(),
          );
          for (final entity in entities) {
            final relativePath = p.join(base, p.basename(entity.path));
            var isDirectory = entity is Directory;
            if (entity is Link) {
              // Reported as a directory if it resolves to one inside the root,
              // so the model can list it explicitly. Anything else (outside the
              // root, dangling, a cycle) is a plain entry, so its target isn't
              // revealed. Links are never recursed into: that rules out cycles
              // and fan-out (links to siblings) without any bookkeeping.
              final resolved = _resolvePathOrNull(relativePath);
              isDirectory =
                  resolved != null &&
                  FileSystemEntity.isDirectorySync(resolved);
            }

            results.add(
              ListFileOutputItem(path: relativePath, isDirectory: isDirectory),
            );

            if (entity is Directory && recursive) {
              results.addAll(await list(entity.path, relativePath));
            }
          }
          return results;
        }

        return .response(await list(dirPath, input.dirPath ?? ''));
      },
    ),
    Tool<ReadFileInput, String>(
      name: 'read_file',
      description: 'Reads the contents of a file',
      inputSchema: ReadFileInput.$schema,
      outputSchema: .string(),

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
          final bytes = await _withModelPath(input.filePath, file.readAsBytes);
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
          final content = await _withModelPath(
            input.filePath,
            file.readAsString,
          );
          parts.add(
            TextPart(
              text:
                  '<read_file path="${input.filePath}">\n$content\n</read_file>',
              metadata: {
                'filePath': input.filePath,
                'filesystemMiddlewareTool': 'read_file',
              },
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
          _messageQueue.add(
            Message(
              role: Role.user,
              content: newContent,
              metadata: {'filesystemMiddlewareTool': 'read_file'},
            ),
          );
        } else {
          _messageQueue.add(
            Message(
              role: Role.user,
              content: parts,
              metadata: {'filesystemMiddlewareTool': 'read_file'},
            ),
          );
        }

        return .response(
          'File ${input.filePath} read successfully, see contents below',
        );
      },
    ),
    Tool<WriteFileInput, String>(
      name: 'write_file',
      description: 'Writes content to a file, overwriting it if it exists.',
      inputSchema: WriteFileInput.$schema,
      outputSchema: .string(),
      fn: (input, _) async {
        final filePath = _resolvePath(input.filePath);
        final file = File(filePath);
        await _withModelPath(input.filePath, () async {
          await file.parent.create(recursive: true);
          await file.writeAsString(input.content);
        });
        return .response('File ${input.filePath} written successfully.');
      },
    ),
    Tool<SearchAndReplaceInput, String>(
      name: 'search_and_replace',
      description: 'Replaces text in a file using search and replace blocks. ',
      inputSchema: SearchAndReplaceInput.$schema,
      outputSchema: .string(),

      fn: (input, _) async {
        final filePath = _resolvePath(input.filePath);
        final file = File(filePath);
        if (!await file.exists()) {
          throw Exception('File does not exist: ${input.filePath}');
        }

        var content = await _withModelPath(input.filePath, file.readAsString);

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

        await _withModelPath(input.filePath, () => file.writeAsString(content));
        return .response(
          'Successfully applied ${input.edits.length} edit(s) to ${input.filePath}.',
        );
      },
    ),
  ];

  @override
  Future<GenerateResult> generate(
    GenerateTurnState envelope,
    ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    Future<GenerateResult> Function(
      GenerateTurnState envelope,
      ActionFnArg<ModelResponseChunk, GenerateActionOptions, void> ctx,
    )
    next,
  ) async {
    final options = envelope.request;
    var messageIndex = envelope.messageIndex;

    if (_messageQueue.isNotEmpty) {
      final messages = List<Message>.from(options.messages);

      if (ctx.streamingRequested) {
        for (final msg in _messageQueue) {
          ctx.sendChunk(
            ModelResponseChunk(
              index: messageIndex++,
              content: msg.content,
              role: msg.role,
            ),
          );
        }
      }

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
      return next(
        envelope.copyWith(request: newOptions, messageIndex: messageIndex),
        ctx,
      );
    }
    return next(envelope, ctx);
  }

  @override
  Future<ToolResult> tool(
    ToolRequestPart request,
    ActionFnArg<void, dynamic, void> ctx,
    Future<ToolResult> Function(
      ToolRequestPart request,
      ActionFnArg<void, dynamic, void> ctx,
    )
    next,
  ) async {
    try {
      return await next(request, ctx);
    } on CancelledException {
      // A cooperative cancellation must propagate so the generation loop can
      // abort. Converting it into an error tool response (below) would let the
      // loop continue and record a fabricated "cancelled" tool result in the
      // resumable history.
      rethrow;
    } catch (e) {
      // Check if this tool is one of ours
      if ([
        'list_files',
        'read_file',
        'write_file',
        'search_and_replace',
      ].contains(request.toolRequest.name)) {
        final errorText = "Tool '${request.toolRequest.name}' failed: $e";

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

        // Answer the tool call too (the loop fills in the request's `ref` and
        // `name`), but the model will primarily see the user message above.
        return .response('Tool failed. See context for details.');
      }
      rethrow;
    }
  }
}
