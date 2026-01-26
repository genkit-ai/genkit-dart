// ignore_for_file: non_constant_identifier_names

import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:schemantic_analyzer_plugin/main.dart';
import 'package:test_reflective_loader/test_reflective_loader.dart';

@reflectiveTest
class MyRuleTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = SchemanticNamingRule();
    newPackage('schemantic').addFile('lib/schemantic.dart', r'''
class Schemantic {
  const Schemantic();
}
''');
    super.setUp();
  }

  void test_has_await() async {
    await assertDiagnostics(
      r'''
import 'package:schemantic/schemantic.dart';

@Schemantic()
class A {}
''',
      [lint(66, 1)],
    );
  }

  void test_no_await() async {
    await assertNoDiagnostics(r'''
import 'package:schemantic/schemantic.dart';

@Schemantic()
class $A {}
''');
  }
}

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MyRuleTest);
  });
}
