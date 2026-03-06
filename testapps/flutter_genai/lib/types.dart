import 'package:schemantic/schemantic.dart';

part 'types.g.dart';

@Schema()
abstract class $ServerFlowInput {
  String get provider;
  String get prompt;
}
