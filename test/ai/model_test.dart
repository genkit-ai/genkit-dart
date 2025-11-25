import 'package:genkit/schema.dart';
import 'package:genkit/src/ai/model.dart';
import 'package:genkit/src/types.dart';
import 'package:test/test.dart';

part 'model_test.schema.g.dart';

@GenkitSchema()
abstract class TestCustomOptionsSchema {
  String get customField;
}

void main() {
  group('Model', () {
    test('should include customOptions in metadata', () {
      final model = Model(
        name: 'testModel',
        fn: (ModelRequest request, context) async {
          return ModelResponse.from(
            finishReason: FinishReason.stop,
            message: Message.from(
              role: Role.model,
              content: [TextPart.from(text: 'hi')],
            ),
          );
        },
        customOptions: TestCustomOptionsType,
      );

      final metadata = model.metadata;
      expect(metadata['model']['customOptions'], isNotNull);
      expect(metadata['model']['customOptions'], {
        'type': 'object',
        'properties': {
          'customField': {'type': 'string'},
        },
        'required': ['customField'],
      });
    });
  });
}
