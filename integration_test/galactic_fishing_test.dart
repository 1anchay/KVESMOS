import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/fishing_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/fishing_story.dart';
import 'package:orbitwords/domain/story_dialogue.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

import '../test/fishing_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const capture = bool.fromEnvironment('FISHING_CAPTURE');
  const audio = SoundEffectsService.channel;

  testWidgets('ship excursion, missed bite, journal, catch, report and atlas', (
    tester,
  ) async {
    final learning = LearningRepository(AppDatabase(NativeDatabase.memory()));
    await saveCompletedFirstFlight(learning);
    final app = AppController(learning);
    await app.initialize();

    Future<void> mark(String name) async {
      if (capture) {
        final call = await Process.run('/system/bin/log', [
          '-t',
          'KVESMOS11',
          name,
        ]);
        expect(call.exitCode, 0);
      }
    }

    Future<void> wait([int milliseconds = 240]) async {
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
      await tester.pump();
    }

    Finder key(String id) => find.byKey(Key(id));

    Future<void> until(String id, {int tries = 110}) async {
      for (var i = 0; i < tries; i++) {
        if (key(id).evaluate().isNotEmpty) return;
        await wait(105);
      }
      fail('Missing $id');
    }

    Future<void> tap(String id, {int? settle, bool scroll = false}) async {
      if (scroll) {
        await tester.scrollUntilVisible(
          key(id),
          160,
          scrollable: find
              .descendant(
                of: find.byType(ListView).last,
                matching: find.byType(Scrollable),
              )
              .first,
        );
      }
      await until(id);
      await tester.ensureVisible(key(id));
      await wait(95);
      expect(key(id).hitTestable(), findsOneWidget, reason: id);
      await tester.tap(key(id).hitTestable());
      await wait(settle ?? (capture ? 365 : 220));
      expect(tester.takeException(), isNull, reason: id);
    }

    Future<void> closeKnowledge() async {
      expect(await tester.binding.handlePopRoute(), true);
      await wait(295);
    }

    Future<Map<String, dynamic>> mixer() async =>
        (await audio.invokeMapMethod<String, dynamic>('soundscapeStatus'))!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(gameplayReboot: true),
      ),
    );
    await tap('reboot-start');
    await until('flight-nereya');
    await tester.ensureVisible(key('flight-nereya'));
    await mark('FISHING_START');
    try {
      if (capture) await wait(680);
      await tap('flight-nereya');
      await tap('fishing-briefing');
      await tap('story-next');
      await tap('story-option-1');
      await tap('story-submit');
      await until('story-correct');
      await tap('story-continue');
      await tap('story-next');
      await tap('story-next');
      await tap('story-next');
      await tap('fishing-depart', settle: 850);
      await until('fishing-phase-preparation');
      final water = await mixer();
      expect(water['scene'], 'water');
      expect(water['players'], 2);
      await tap('fishing-gear');
      await tap('fishing-bait-spores', scroll: true);
      await tap('fishing-close-panel');

      await tap('fishing-aim');
      await tap('fishing-zone-reeds');
      await tap('fishing-charge', settle: 545);
      await tap('fishing-cast');
      await until('fishing-phase-bite');
      await until('fishing-phase-escaped');
      await tap('fishing-retry');

      await tap('fishing-charge', settle: 560);
      await tap('fishing-cast');
      await until('fishing-phase-waiting');
      await tap('fishing-journal', settle: 350);
      await tap('journal-en:phrase:need-rod', scroll: true);
      await tap('term-audio', settle: 330);
      expect(app.audio.lastSource, SpeechSource.recording);
      expect((await mixer())['musicGain'], lessThan(.22));
      expect(await app.audio.play(SoundEffect.bite), false);
      for (
        var i = 0;
        i < 45 && app.audio.playback.value?.playing == true;
        i++
      ) {
        await wait(105);
      }
      expect(app.audio.playback.value?.playing, isNot(true));
      await wait(360);
      expect(key('fishing-phase-waiting'), findsOneWidget);
      expect((await mixer())['musicGain'], closeTo(.30, .04));
      expect((await mixer())['starts'], water['starts']);
      await closeKnowledge();
      await until('journal-en:phrase:need-rod');
      expect(key('fishing-phase-waiting'), findsOneWidget);
      await closeKnowledge();

      await until('fishing-phase-bite');
      await tap('fishing-strike', settle: 380);
      await until('fishing-reel');
      await tester.ensureVisible(key('fishing-reel'));
      await wait(90);
      final slider = tester.getRect(key('fishing-reel'));
      await tester.tapAt(
        Offset(slider.left + slider.width * .52, slider.center.dy),
      );
      await until('fishing-phase-caught');
      await until('fishing-finish');
      await tap('fishing-finish');
      expect(find.textContaining('В улове одна рыба'), findsOneWidget);
      await tap('fishing-report');
      await tap('story-next');
      await tap('story-option-1');
      await tap('story-submit');
      await tap('story-continue');
      await tap('story-choice-share');
      await tap('story-audio', settle: 800);
      expect(app.audio.lastSource, SpeechSource.recording);
      await tap('story-next');
      await tap('fishing-collection');
      expect(find.text('Открыто 1 из 8 · улов 1'), findsOneWidget);
      if (capture) await wait(880);
      await tap('fishing-close-panel');
      await tap('fishing-return', settle: 750);
      await until('flight-complete');
    } finally {
      await mark('FISHING_END');
    }
    final saved = await FishingRepository(learning).read();
    expect(saved.catches.values.single.discovery, true);
    expect(saved.activeTrip, isNull);
    expect(saved.reports.length, 1);
    final story = await StoryRepository(learning).read();
    expect(story.runs[FishingStory.report.id]!.finished, true);
    expect(story.trust(StorySpeaker.pixie), 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await learning.db.close();
  }, timeout: const Timeout(Duration(minutes: 6)));
}
