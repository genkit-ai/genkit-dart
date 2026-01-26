import 'package:analysis_server_plugin/edit/dart/correction_producer.dart';
import 'package:analysis_server_plugin/edit/dart/dart_fix_kind_priority.dart';
import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';
import 'package:analyzer_plugin/utilities/change_builder/change_builder_core.dart';
import 'package:analyzer_plugin/utilities/fixes/fixes.dart';

final plugin = SimplePlugin();

class SimplePlugin extends Plugin {
  @override
  String get name => 'Schematic Plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(SchemanticNamingRule());
    registry.registerFixForRule(
      SchemanticNamingRule.code,
      AddSchematicPrefix.new,
    );
  }
}

class SchemanticNamingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'schemantic_naming',
    'Classes annotated with @Schematic must start with "\$" and be `abstract`.',
    correctionMessage: "Add a '\$' prefix to the class name.",
  );

  SchemanticNamingRule()
    : super(
        name: 'schemantic_naming',
        description: 'Enforces \$ prefix and abstract for Schemantic classes.',
      );

  @override
  LintCode get diagnosticCode => code;

  @override
  void registerNodeProcessors(
    RuleVisitorRegistry registry,
    RuleContext context,
  ) {
    var visitor = _Visitor(this, context);
    registry.addClassDeclaration(this, visitor);
  }
}

class _Visitor extends SimpleAstVisitor<void> {
  final AnalysisRule rule;
  final RuleContext context;

  _Visitor(this.rule, this.context);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (node.metadata.isEmpty) return;

    if (!node.metadata.any(
      (annotation) => annotation.name.name.endsWith('Schematic'),
    )) {
      return;
    }

    if (!node.namePart.typeName.lexeme.startsWith(r'$')) {
      rule.reportAtNode(node.namePart);
      return;
    }

    if (node.abstractKeyword == null) {
      rule.reportAtNode(node.namePart);
      return;
    }
  }
}

class AddSchematicPrefix extends ResolvedCorrectionProducer {
  static const _addPrefixKind = FixKind(
    'dart.fix.schematic.addPrefix',
    DartFixKindPriority.standard,
    "Fix Schematic class declaration",
  );

  AddSchematicPrefix({required super.context});

  @override
  CorrectionApplicability get applicability =>
      CorrectionApplicability.singleLocation;

  @override
  FixKind get fixKind => _addPrefixKind;

  @override
  Future<void> compute(ChangeBuilder builder) async {
    // Traverse up to find the class declaration from the reported node (the name identifier)
    final classDeclaration = node.thisOrAncestorOfType<ClassDeclaration>();

    if (classDeclaration != null) {
      final nameToken = classDeclaration.namePart.typeName;
      final name = nameToken.lexeme;

      await builder.addDartFileEdit(file, (builder) {
        // 1. Handle the '$' prefix
        if (!name.startsWith(r'$')) {
          builder.addInsertion(
            nameToken.offset,
            (builder) => builder.write(r'$'),
          );
        }

        // 2. Handle the 'abstract' keyword
        // The lint enforces both. If 'abstract' is missing, we insert it.
        if (classDeclaration.abstractKeyword == null) {
          final classKeyword = classDeclaration.classKeyword;
          builder.addInsertion(
            classKeyword.offset,
            (builder) => builder.write('abstract '),
          );
        }
      });
    }
  }
}
