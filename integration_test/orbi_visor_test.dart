import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/character_moment.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('Orbi visor reacts to native playback and lesson events', (
    tester,
  ) async {
    final audio = LearningAudio((_) async => null, (_, _) async {});
    await audio.initialize();
    final clip = audio.recordings.recordings.firstWhere(
      (r) =>
          r.character == 'orbi' &&
          r.locale.startsWith('en') &&
          r.text.length > 12,
    );
    Future<void> show(
      CharacterState state, {
      ThemeMode theme = ThemeMode.dark,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          themeMode: theme,
          theme: ThemeData.light(),
          darkTheme: ThemeData.dark(),
          home: Scaffold(
            backgroundColor: theme == ThemeMode.dark
                ? const Color(0xff12232d)
                : const Color(0xfff7f5f0),
            body: Center(
              child: SpeakingCharacter(
                audio: audio,
                character: 'orbi',
                state: state,
                size: 210,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> mark(String value) async {
      expect(
        (await Process.run('/system/bin/log', [
          '-t',
          'KVESMOS11',
          value,
        ])).exitCode,
        0,
      );
    }

    await show(CharacterState.idle);
    await mark('VIDEO_START:orbi');
    await Future<void>.delayed(const Duration(seconds: 6));
    expect(
      await audio.speak(
        clip.text,
        character: 'orbi',
        locale: clip.locale,
        slow: true,
      ),
      isTrue,
    );
    await tester.pump();
    expect(
      tester
          .widget<CharacterMoment>(find.byType(CharacterMoment))
          .effectiveState,
      CharacterState.talking,
    );
    await mark('CAPTURE:orbi-native-speech');
    for (var i = 0; i < 100 && audio.playback.value != null; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(audio.playback.value, isNull);
    final reactions = [
      CharacterState.greeting,
      CharacterState.correct,
      CharacterState.support,
      CharacterState.surprise,
      CharacterState.celebration,
      CharacterState.goodbye,
    ];
    for (final (index, state) in reactions.indexed) {
      await show(state, theme: index < 3 ? ThemeMode.dark : ThemeMode.light);
      await Future<void>.delayed(const Duration(milliseconds: 3700));
    }
    await audio.stop();
    await mark('VIDEO_DONE:orbi');
    await mark('DONE');
  });
}
