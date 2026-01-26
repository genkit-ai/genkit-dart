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
class Schematic {
  const Schematic();
}
''');
    super.setUp();
  }

  void test_no_dollar() async {
    await assertDiagnostics(
      r'''
import 'package:schemantic/schemantic.dart';

@Schematic()
abstract class A {}
''',
      [lint(74, 1)],
    );
  }

  void test_is_not_abstract() async {
    await assertDiagnostics(
      r'''
import 'package:schemantic/schemantic.dart';

@Schematic()
class $A {}
''',
      [lint(65, 2)],
    );
  }

  void test_has_dollar() async {
    await assertNoDiagnostics(r'''
import 'package:schemantic/schemantic.dart';

@Schematic()
abstract class $A {}
''');
  }
}

void main() {
  defineReflectiveSuite(() {
    defineReflectiveTests(MyRuleTest);
  });
}
