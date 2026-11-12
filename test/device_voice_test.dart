import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/device.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'denied microphone permission returns to text without recognition or results',
    () async {
      const channel = MethodChannel('plugin.csdcorp.com/speech_to_text');
      final calls = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls.add(call.method);
            if (call.method == 'initialize' ||
                call.method == 'has_permission') {
              return false;
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final results = <String>[];
      final service = VoiceService();
      expect(await service.listen(results.add, (_) {}), false);
      expect(results, isEmpty);
      expect(calls, contains('initialize'));
      expect(calls, isNot(contains('listen')));
      await service.stop();
    },
  );
}
