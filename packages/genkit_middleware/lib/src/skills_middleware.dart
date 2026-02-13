import 'dart:io';
import 'package:genkit/genkit.dart';
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

class SkillsMiddleware extends GenerateMiddleware {
  final List<String> skillPaths;
  final Map<String, _SkillInfo> _skillCache = {};

  SkillsMiddleware([this.skillPaths = const ['skills']]);

  Map<String, String>? _parseFrontmatter(String content) {
    // Matches YAML frontmatter between --- lines at the start of the file
    final match = RegExp(
      r'^---\n([\s\S]*?)\n---',
      multiLine: true,
    ).firstMatch(content);
    if (match == null) return null;

    final yaml = match.group(1)!;
    final nameMatch = RegExp(r'name:\s*(.+)').firstMatch(yaml);
    final descriptionMatch = RegExp(r'description:\s*(.+)').firstMatch(yaml);

    return {
      if (nameMatch != null) 'name': nameMatch.group(1)!.trim(),
      if (descriptionMatch != null)
        'description': descriptionMatch.group(1)!.trim(),
    };
  }

  void _scanSkills() {
    _skillCache.clear();
    for (final path in skillPaths) {
      final dir = Directory(path);
      if (!dir.existsSync()) continue;

      try {
        for (final entity in dir.listSync()) {
          if (entity is Directory && !p.basename(entity.path).startsWith('.')) {
            final skillMd = File(p.join(entity.path, 'SKILL.md'));
            if (skillMd.existsSync()) {
              final skillName = p.basename(entity.path);
              String? description;

              try {
                final content = skillMd.readAsStringSync();
                final fm = _parseFrontmatter(content);
                if (fm != null) {
                  description = fm['description'];
                }
              } catch (e) {
                // Ignore errors reading description
              }

              _skillCache[skillName] = _SkillInfo(
                skillMd.path,
                description ?? 'No description provided.',
              );
            }
          }
        }
      } catch (e) {
        // Ignore directory listing errors
      }
    }
  }

  @override
  List<Tool> get tools {
    _scanSkills();
    return [
      Tool<UseSkillInput, String>(
        name: 'use_skill',
        description: 'Use a skill by its name.',
        inputSchema: UseSkillInput.$schema,
        outputSchema: stringSchema(),
        fn: (input, _) async {
          final skillName = input.skillName;
          final info = _skillCache[skillName];
          if (info == null) {
            throw Exception(
              'Access denied: Path is outside of skills directory or skill not found.',
            );
          }
          // In TS, there is a check for path traversal inside resolvePath.
          // Here, we rely on _skillCache which is built from scanning valid directories,
          // so we only access files we explicitly found.

          try {
            final content = await File(info.path).readAsString();
            return content;
          } catch (e) {
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
    _scanSkills();
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
            if (part.metadata?[metadataKey] == true ||
                part.text!.trim().startsWith(skillsTag)) {
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
