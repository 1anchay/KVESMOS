import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'package:orbitwords/ui/cutout_actor.dart';
import 'learning_audio_test.dart' show FakeTts;

void main() {
  testWidgets('hidden, background and reduced-motion actors stop scheduling', (
    tester,
  ) async {
    Future<void> show({bool hidden = false, bool reduced = false}) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reduced),
            child: TickerMode(
              enabled: !hidden,
              child: const CutoutActor(character: 'miko'),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }

    await show();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await show(hidden: true);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await tester.pump(const Duration(seconds: 10));
    expect(tester.binding.hasScheduledFrame, isFalse);
    await show(reduced: true);
    expect(tester.binding.hasScheduledFrame, isFalse);
    await show();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 10));
    expect(tester.takeException(), isNull);
  });

  testWidgets('celebrations finish once and have no delayed replay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CutoutActor(character: 'orbi', action: ActorAction.celebration),
      ),
    );
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 10));
    expect(tester.binding.hasScheduledFrame, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('speech gestures follow the matching actual playback and stop', (
    tester,
  ) async {
    final audio = LearningAudio(
      (_) async => null,
      (_, _) async {},
      backend: FakeTts(),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: SpeakingCharacter(audio: audio, character: 'miko'),
      ),
    );
    ActorAction action() =>
        tester.widget<CutoutActor>(find.byType(CutoutActor)).action;
    expect(action(), ActorAction.idle);
    audio.playback.value = const SpeechPlayback(
      'orbi',
      SpeechSource.recording,
      true,
    );
    await tester.pump();
    expect(action(), ActorAction.idle);
    audio.playback.value = const SpeechPlayback(
      'miko',
      SpeechSource.recording,
      true,
    );
    await tester.pump();
    expect(action(), ActorAction.talking);
    audio.playback.value = const SpeechPlayback(
      'miko',
      SpeechSource.recording,
      false,
      paused: true,
    );
    await tester.pump();
    expect(action(), ActorAction.idle);
    audio.playback.value = null;
    await tester.pump();
    expect(action(), ActorAction.idle);
    await tester.pumpWidget(const SizedBox.shrink());
    audio.playback.dispose();
  });
}
