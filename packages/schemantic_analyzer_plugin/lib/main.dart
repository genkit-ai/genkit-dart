import 'package:analysis_server_plugin/plugin.dart';
import 'package:analysis_server_plugin/registry.dart';
import 'package:analyzer/analysis_rule/analysis_rule.dart';
import 'package:analyzer/analysis_rule/rule_context.dart';
import 'package:analyzer/analysis_rule/rule_visitor_registry.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/error/error.dart';

final plugin = SimplePlugin();

class SchemanticNamingRule extends AnalysisRule {
  static const LintCode code = LintCode(
    'schemantic_naming',
    'Classes annotated with @Schemantic must start with "\$".',
    correctionMessage: "Add a '\$' prefix to the class name.",
  );

  SchemanticNamingRule()
    : super(
        name: 'schemantic_naming',
        description: 'Enforces \$ prefix for Schemantic classes.',
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
      (annotation) => annotation.name.name.endsWith('Schemantic'),
    )) {
      return;
    }

    if (!node.namePart.typeName.lexeme.startsWith(r'$')) {
      rule.reportAtNode(node.namePart);
    }
  }
}

class SimplePlugin extends Plugin {
  @override
  String get name => 'Schemantic Plugin';

  @override
  void register(PluginRegistry registry) {
    registry.registerWarningRule(SchemanticNamingRule());
  }
}
