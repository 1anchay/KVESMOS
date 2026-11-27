import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'learning_audio_test.dart' show FakeTts;

void main() {
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
    CharacterState action() => tester
        .widget<CharacterMoment>(find.byType(CharacterMoment))
        .effectiveState;
    expect(action(), CharacterState.idle);
    audio.playback.value = const SpeechPlayback(
      'orbi',
      SpeechSource.recording,
      true,
    );
    await tester.pump();
    expect(action(), CharacterState.idle);
    audio.playback.value = const SpeechPlayback(
      'miko',
      SpeechSource.recording,
      true,
    );
    await tester.pump();
    expect(action(), CharacterState.talking);
    audio.playback.value = const SpeechPlayback(
      'miko',
      SpeechSource.recording,
      false,
      paused: true,
    );
    await tester.pump();
    expect(action(), CharacterState.idle);
    audio.playback.value = null;
    await tester.pump();
    expect(action(), CharacterState.idle);
    await tester.pumpWidget(const SizedBox.shrink());
    audio.playback.dispose();
  });
}
