// No application data writes in this test. IMPORTANT: Flutter's integration
// runner may reinstall/clear its target package. Run ONLY on a disposable QA
// emulator with a verified backup, never on a user's phone. Restore the main
// APK and QA backup afterwards. Use install_preview.py for real updates.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/services/learning_audio.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'bundled voices decode, pause, resume, finish and cancel natively',
    (tester) async {
      final audio = LearningAudio((_) async => null, (_, _) async {});
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(body: Center(child: Text('KVESMOS audio QA'))),
        ),
      );
      await audio.initialize();
      expect(audio.recordings.recordings.length, 94);
      for (final id in ['orbi', 'miko', 'zig_quartz']) {
        final clip = audio.recordings.recordings.firstWhere(
          (r) => r.character == id && r.text.length > 12,
        );
        expect(await audio.speak(clip.text, character: id), true);
        expect(audio.lastSource, SpeechSource.recording);
        await Future<void>.delayed(const Duration(milliseconds: 120));
        expect(await audio.pauseOrResume(), true);
        expect(audio.playback.value?.paused, true);
        await Future<void>.delayed(const Duration(milliseconds: 250));
        expect(audio.playback.value?.paused, true);
        expect(await audio.pauseOrResume(), true);
        for (var i = 0; i < 150 && audio.playback.value != null; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
        expect(audio.playback.value, isNull, reason: 'native completion $id');
        expect(audio.lastProblem, isNull);
        expect(await audio.speak(clip.text, character: id, slow: true), true);
        expect(audio.lastSource, SpeechSource.recording);
        await audio.stop();
        expect(audio.playback.value, isNull);
      }
    },
  );
}
