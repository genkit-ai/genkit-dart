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

import 'dart:io';
import 'package:genkit/plugin.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:schemantic/schemantic.dart';

part 'skills_middleware.g.dart';

@Schematic()
abstract class $UseSkillInput {
  @Field(description: 'The name of the skill to use.')
  String get skillName;
}

@Schematic()
abstract class $SkillsPluginOptions {
  @Field(
    description:
        'The directories containing skill files. Defaults to ["skills"].',
  )
  List<String>? get skillPaths;
}

class SkillsPlugin extends GenkitPlugin {
  @override
  String get name => 'skills';

  @override
  List<GenerateMiddlewareDef> middleware() => [
    defineMiddleware<SkillsPluginOptions>(
      name: 'skills',
      configSchema: SkillsPluginOptions.$schema,
      create: ([SkillsPluginOptions? config]) =>
          SkillsMiddleware(config?.skillPaths ?? const ['skills']),
    ),
  ];
}

GenerateMiddlewareRef<SkillsPluginOptions> skills({List<String>? skillPaths}) {
  return middlewareRef(
    name: 'skills',
    config: SkillsPluginOptions(skillPaths: skillPaths),
  );
}

class _SkillInfo {
  final String path;
  final String description;

  _SkillInfo(this.path, this.description);
}

final _logger = Logger('genkit_middleware.skills');

class SkillsMiddleware extends GenerateMiddleware {
  final List<String> skillPaths;
  final Map<String, _SkillInfo> _skillCache = {};

  SkillsMiddleware([this.skillPaths = const ['skills']]);

  Map<String, String>? _parseFrontmatter(String content) {
    // Matches YAML frontmatter between --- lines at the start of the file
    final match = RegExp(r'^---\n([^]*?)\n---').firstMatch(content);
    if (match == null) return null;

    final yaml = match[1]!;
    final nameMatch = RegExp(r'name:\s*(.+)').firstMatch(yaml);
    final descriptionMatch = RegExp(r'description:\s*(.+)').firstMatch(yaml);

    return {
      if (nameMatch != null) 'name': nameMatch[1]!.trimRight(),
      if (descriptionMatch != null)
        'description': descriptionMatch[1]!.trimRight(),
    };
  }

  bool _scanned = false;

  Future<void> _ensureSkillsScanned() async {
    if (_scanned) return;
    _scanned = true;
    _skillCache.clear();

    for (final path in skillPaths) {
      final dir = Directory(path);
      if (!await dir.exists()) {
        _logger.warning('Skills directory not found: $path');
        continue;
      }

      try {
        await for (final entity in dir.list()) {
          if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
            final skillMd = File(p.join(entity.path, 'SKILL.md'));
            if (await skillMd.exists()) {
              final skillName = p.basename(entity.path);
              String? description;

              try {
                final content = await skillMd.readAsString();
                final fm = _parseFrontmatter(content);
                if (fm != null) {
                  description = fm['description'];
                }
              } catch (e) {
                _logger.warning(
                  'Failed to read skill metadata for $skillName',
                  e,
                );
              }

              _skillCache[skillName] = _SkillInfo(
                skillMd.path,
                description ?? 'No description provided.',
              );
            }
          }
        }
      } catch (e) {
        _logger.warning('Error scanning skills directory: $path', e);
      }
    }
  }

  @override
  List<Tool> get tools {
    return [
      Tool<UseSkillInput, String>(
        name: 'use_skill',
        description: 'Use a skill by its name.',
        inputSchema: UseSkillInput.$schema,
        outputSchema: .string(),
        fn: (input, _) async {
          await _ensureSkillsScanned();
          final skillName = input.skillName;
          final info = _skillCache[skillName];
          if (info == null) {
            throw Exception(
              'Access denied: Path is outside of skills directory or skill not found.',
            );
          }

          try {
            final content = await File(info.path).readAsString();
            return content;
          } catch (e) {
            _logger.severe('Failed to read skill content "$skillName"', e);
            throw Exception('Failed to read skill "$skillName": $e');
          }
        },
      ),
    ];
  }

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
    await _ensureSkillsScanned();
    // TS impl: if (skillsList.length > 0)
    // Here we check _skillCache which corresponds to skillsList

    if (_skillCache.isNotEmpty) {
      final skillsList = _skillCache.entries
          .map((e) {
            final desc = e.value.description;
            if (desc != 'No description provided.') {
              return ' - ${e.key} - $desc';
            }
            return ' - ${e.key}';
          })
          .join('\n');

      final skillsTag = '<skills>';
      final systemPromptText =
          '$skillsTag\n'
          'You have access to a library of skills that serve as specialized instructions/personas.\n'
          'Strongly prefer to use them when working on anything related to them.\n'
          'Only use them once to load the context.\n'
          'Here are the available skills:\n'
          '$skillsList\n'
          '</skills>';

      final messages = List<Message>.from(options.messages);
      final metadataKey = 'skills-instructions';

      // TS Logic:
      // 1. Look for injected part in messages
      // 2. If found, update it if different
      // 3. If not found, find system message and append
      // 4. If no system message, prepend new system message

      Part? injectedPart;
      Message? injectedMessage;
      var injectedMsgIndex = -1;
      var injectedPartIndex = -1;

      for (var i = 0; i < messages.length; i++) {
        final msg = messages[i];
        for (var j = 0; j < msg.content.length; j++) {
          final part = msg.content[j];
          if (part.isText) {
            if (part.metadata?[metadataKey] == true) {
              injectedPart = part;
              injectedMessage = msg;
              injectedMsgIndex = i;
              injectedPartIndex = j;
              break;
            }
          }
        }
        if (injectedPart != null) break;
      }

      if (injectedPart != null) {
        // Found existing part
        if (injectedPart.text != systemPromptText) {
          final newContent = List<Part>.from(injectedMessage!.content);
          newContent[injectedPartIndex] = TextPart(
            text: systemPromptText,
            metadata: {metadataKey: true},
          );

          final newMsg = Message(
            role: injectedMessage.role,
            content: newContent,
            metadata: injectedMessage.metadata,
          );
          messages[injectedMsgIndex] = newMsg;
        }
      } else {
        // Not found, find system message
        final systemMessageIndex = messages.indexWhere(
          (m) => m.role == Role.system,
        );

        if (systemMessageIndex != -1) {
          final systemMsg = messages[systemMessageIndex];
          final newContent = [
            ...systemMsg.content,
            TextPart(text: systemPromptText, metadata: {metadataKey: true}),
          ];
          messages[systemMessageIndex] = Message(
            role: Role.system,
            content: newContent,
          );
        } else {
          // Create new system message at start
          messages.insert(
            0,
            Message(
              role: Role.system,
              content: [
                TextPart(text: systemPromptText, metadata: {metadataKey: true}),
              ],
            ),
          );
        }
      }

      // Manual copy since copyWith is not available on generated GenerateActionOptions
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
}
