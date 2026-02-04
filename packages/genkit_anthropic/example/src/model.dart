import 'package:schemantic/schemantic.dart';

part 'model.g.dart';

@Schematic()
abstract class $Person {
  String get name;
  int get age;
}

@Schematic()
abstract class $CalculatorInput {
  int get a;
  int get b;
}
