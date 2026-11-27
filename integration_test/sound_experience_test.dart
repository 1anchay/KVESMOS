import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const capture = bool.fromEnvironment('SOUND_CAPTURE');
  const channel = SoundEffectsService.channel;

  testWidgets('native mix follows the ship, dialogue, speech and lifecycle', (
    tester,
  ) async {
    final repository = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(repository);
    await app.initialize();

    Future<void> mark(String name) async {
      if (capture) {
        expect(
          (await Process.run('/system/bin/log', [
            '-t',
            'KVESMOS11',
            name,
          ])).exitCode,
          0,
        );
      }
    }

    Future<void> pause([int milliseconds = 720]) async {
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
      await tester.pump();
    }

    Future<void> tap(String key, [int? milliseconds]) async {
      final target = find.byKey(Key(key));
      expect(target, findsOneWidget, reason: key);
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 180));
      await tester.tap(target.hitTestable());
      await pause(milliseconds ?? (capture ? 1300 : 720));
      expect(tester.takeException(), isNull, reason: key);
    }

    Future<Map<String, dynamic>> status() async =>
        (await channel.invokeMapMethod<String, dynamic>('soundscapeStatus'))!;

    await mark('SOUND_START');
    try {
      if (capture) await pause(850);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(gameplayReboot: true),
        ),
      );
      await pause(capture ? 3600 : 1100);
      expect(await status(), containsPair('scene', 'menu'));
      expect((await status())['musicGain'], closeTo(.30, .03));
      await tap('reboot-start', capture ? 2700 : 1100);
      final ship = await status();
      expect(ship['scene'], 'ship');
      expect(ship['players'], 2);
      expect(ship['ambienceGain'], closeTo(.40, .03));

      Future<void> briefing(FlightRoom room) async {
        await tap('flight-orbi');
        for (final _ in FlightWord.deck(room)) {
          await tap('flight-understood');
        }
      }

      await briefing(FlightRoom.airlock);
      await tap('flight-toolbox');
      await tap('flight-item-key');
      await tap('flight-hatch');
      await tap('flight-hatch');
      await tap('flight-story-repair', capture ? 2300 : null);
      expect((await status())['starts'], ship['starts']);
      await tap('story-next');
      await tap('story-option-1');
      await tap('story-submit');
      expect(find.byKey(const Key('story-correct')), findsOneWidget);
      await tap('story-continue');
      await tap('story-token-2');
      await tap('story-draft-token-2');
      for (final index in [2, 4, 3, 0]) {
        await tap('story-token-$index');
      }
      await tap('story-submit');
      await tap('story-continue');
      await tap('story-option-1');
      await tap('story-submit');
      await tap('story-continue');
      await tap('story-choice-team');
      await tap('story-next');

      await briefing(FlightRoom.workshop);
      await tap('flight-battery');
      await tap('flight-story-battery');
      await tap('story-next');
      await tap('story-option-1');
      await tap('story-submit');
      await tap('story-continue');
      for (final index in [1, 4, 3, 0]) {
        await tap('story-token-$index');
      }
      await tap('story-submit');
      await tap('story-continue');
      await tap('story-audio', 420);
      expect(app.audio.lastSource, SpeechSource.recording);
      expect(app.audio.playback.value?.playing, true);
      final underSpeech = await status();
      expect(underSpeech['musicGain'], lessThan(.16));
      expect(underSpeech['ambienceGain'], lessThan(.19));
      expect(await app.audio.play(SoundEffect.token), false);
      expect(app.audio.playback.value?.playing, true);
      await pause(2300);
      expect(app.audio.playback.value, isNull);
      final restored = await status();
      expect(restored['musicGain'], closeTo(.30, .03));
      expect(restored['ambienceGain'], closeTo(.40, .03));
      expect(restored['starts'], ship['starts']);
      await tap('story-next');
    } finally {
      await mark('SOUND_END');
    }

    final starts = (await status())['starts'];
    await app.saveAudio(app.audio.preferences.copyWith(ambience: false));
    await pause();
    expect((await status())['musicGain'], closeTo(.30, .03));
    expect((await status())['ambienceGain'], 0.0);
    await app.saveAudio(app.audio.preferences.copyWith(muted: true));
    await pause();
    expect((await status())['running'], false);
    await app.saveAudio(const AudioPreferences());
    await pause();
    expect((await status())['starts'], starts);

    binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 720));
    expect((await status())['running'], false);
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await pause();
    expect((await status())['running'], true);
    expect((await status())['players'], 2);
    await tester.pumpWidget(const SizedBox.shrink());
    await pause();
    expect((await status())['players'], 0);
    await repository.db.close();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
