import 'package:genkit/genkit.dart';
import 'package:test/test.dart';
import 'schemas/my_schemas.dart';
import 'schemas/stream_schemas.dart';

void main() {
  group('GenkitConverter', () {
    group('toRequestData', () {
      test('should convert String input to itself', () {
        final converter = GenkitConverter<String, String, void>(
          toRequestData: (input) => input,
          fromResponseData: (data) => data as String,
        );
        expect(converter.toRequestData('hello'), 'hello');
      });

      test('should convert MyInput to Map using toJson', () {
        final input = MyInput(message: 'test', count: 1);
        final converter = GenkitConverter<MyInput, MyOutput, void>(
          toRequestData: (obj) => obj.toJson(),
          fromResponseData: (data) => MyOutput.fromJson(data),
        );
        expect(converter.toRequestData(input), {'message': 'test', 'count': 1});
      });
    });

    group('fromResponseData', () {
      test('should convert String data to String output', () {
        final converter = GenkitConverter<String, String, void>(
          toRequestData: (input) => input,
          fromResponseData: (data) => data as String,
        );
        expect(converter.fromResponseData('world'), 'world');
      });

      test('should convert Map data to MyOutput using fromJson', () {
        // MyOutput.fromJson expects 'reply' and 'newCount'
        final data = {'reply': 'success', 'newCount': 2};
        final converter = GenkitConverter<MyInput, MyOutput, void>(
          toRequestData: (obj) => obj.toJson(),
          fromResponseData: (data) => MyOutput.fromJson(data),
        );
        expect(converter.fromResponseData(data).reply, 'success');
        expect(converter.fromResponseData(data).newCount, 2);
      });

      test('should handle primitive types directly if defined', () {
        final converter = GenkitConverter<int, int, void>(
          toRequestData: (i) => i,
          fromResponseData: (d) => d as int,
        );
        expect(converter.fromResponseData(123), 123);
      });
    });

    group('fromStreamChunkData', () {
      test('should convert Map json to TestStreamChunk using fromJson', () {
        final jsonData = {'chunk': 'stream data'};
        final converter = GenkitConverter<String, String, TestStreamChunk>(
          toRequestData: (input) => input,
          fromResponseData: (data) => data as String,
          fromStreamChunkData:
              (json) => TestStreamChunk.fromJson(json as Map<String, dynamic>),
        );
        expect(converter.fromStreamChunkData!(jsonData).chunk, 'stream data');
      });

      test('should return null if fromStreamChunkData is not provided', () {
        final converter = GenkitConverter<String, String, void>(
          toRequestData: (input) => input,
          fromResponseData: (data) => data as String,
        );
        expect(converter.fromStreamChunkData, isNull);
      });

      test('should handle dynamic map for stream chunk if defined', () {
        final jsonData = {'type': 'update', 'value': 42};
        final converter = GenkitConverter<String, String, Map<String, dynamic>>(
          toRequestData: (input) => input,
          fromResponseData: (data) => data as String,
          fromStreamChunkData: (json) => json as Map<String, dynamic>,
        );
        expect(converter.fromStreamChunkData!(jsonData), {
          'type': 'update',
          'value': 42,
        });
      });
    });

    group('FullConverter (MyInput, MyOutput, TestStreamChunk)', () {
      final fullConverter = GenkitConverter<MyInput, MyOutput, TestStreamChunk>(
        toRequestData: (input) => input.toJson(),
        fromResponseData:
            (data) => MyOutput.fromJson(data as Map<String, dynamic>),
        fromStreamChunkData:
            (json) => TestStreamChunk.fromJson(json as Map<String, dynamic>),
      );

      test('toRequestData should work correctly with MyInput', () {
        final input = MyInput(message: 'full', count: 100);
        expect(fullConverter.toRequestData(input), {
          'message': 'full',
          'count': 100,
        });
      });

      test('fromResponseData should work correctly with MyOutput', () {
        final data = {'reply': 'full success', 'newCount': 101};
        expect(fullConverter.fromResponseData(data).reply, 'full success');
        expect(fullConverter.fromResponseData(data).newCount, 101);
      });

      test(
        'fromStreamChunkData should work correctly with TestStreamChunk',
        () {
          final jsonData = {'chunk': 'full stream data'};
          expect(
            fullConverter.fromStreamChunkData!(jsonData).chunk,
            'full stream data',
          );
        },
      );
    });
  });
}
