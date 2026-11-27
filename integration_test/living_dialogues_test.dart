import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/domain/story_dialogue.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

const capture = bool.fromEnvironment('STORY_CAPTURE');
const comparisonOnly = bool.fromEnvironment('STORY_COMPARISON_ONLY');

class Player {
  Player(this.tester, {this.onCamera = false});
  final WidgetTester tester;
  bool onCamera;

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

  Future<void> pause([double seconds = 1.2]) async {
    await Future<void>.delayed(
      Duration(
        milliseconds: onCamera && capture ? (seconds * 1000).round() : 650,
      ),
    );
    await tester.pump();
  }

  Future<void> tap(String id, [double seconds = 1.2]) async {
    final target = find.byKey(Key(id));
    expect(target, findsOneWidget, reason: id);
    await tester.ensureVisible(target);
    await tester.pump(const Duration(milliseconds: 180));
    expect(target.hitTestable(), findsOneWidget, reason: id);
    await tester.tap(target);
    await pause(seconds);
    expect(tester.takeException(), isNull, reason: id);
  }

  Future<void> mount(AppController app) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(gameplayReboot: true),
      ),
    );
    await pause(2);
  }

  Future<void> orbi(FlightRoom room) async {
    await tap('flight-orbi', 2);
    for (final _ in FlightWord.deck(room)) {
      await tap('flight-understood', 1.4);
    }
  }

  Future<void> order(List<int> letters) async {
    for (final index in letters) {
      await tap('story-token-$index', .72);
    }
    await tap('story-submit', 2.1);
  }

  Future<void> journey({
    required bool guided,
    required void Function() nextDay,
    required AppController app,
  }) async {
    await tap('reboot-start', 2);
    await orbi(FlightRoom.airlock);
    await tap('flight-toolbox');
    await tap('flight-item-key');
    await tap('flight-hatch');
    await tap('flight-hatch', 1.8);

    await tap('flight-story-repair', 3.2);
    await tap('story-next', 3.1);
    if (guided) await tap('story-help', 2.8);
    await tap('story-option-1', 2.7);
    if (guided) {
      await tap('story-token-2', .8);
      await tap('story-token-4', .8);
      await tap('story-close');
      await tap('flight-story-repair', 1.8);
      expect(find.byKey(const Key('story-draft-token-2')), findsOneWidget);
      await order([3, 0]);
    } else {
      await order([2, 4, 3, 0]);
    }
    await tap('story-option-1', 2.5);
    await tap('story-choice-team', 3.5);
    await tap('story-next');
    nextDay();

    await orbi(FlightRoom.workshop);
    await tap('flight-battery');
    await tap('flight-story-battery', 3.3);
    await tap('story-next', 2.4);
    if (guided) await tap('story-help', 2.1);
    await tap('story-option-1', 2.2);
    if (guided) await tap('story-help', 2.1);
    await order([1, 4, 3, 0]);
    await tap('story-audio', 2);
    expect(app.audio.lastSource, SpeechSource.recording);
    await tap('story-next');

    await tap('flight-cable');
    await tap('flight-item-cable');
    await tap('flight-sockets');
    await tap('flight-item-battery');
    await tap('flight-charger');
    for (var i = 0; i < 3; i++) {
      await tap('flight-turn-a', .7);
    }
    await tap('flight-turn-b', .7);
    await tap('flight-breaker', 2);

    if (guided) {
      await tap('flight-story-power', 3);
      await tap('story-next', 3);
      await tap('story-option-1', 3);
      await tap('story-option-0', 3.4);
      expect(find.byKey(const Key('story-error')), findsOneWidget);
      await tap('story-option-2', 3);
      await order([2, 1, 0]);
      await tap('story-audio', 2);
      expect(app.audio.lastSource, SpeechSource.recording);
      await tap('story-next');
    }

    await tap('flight-to-bridge');
    await orbi(FlightRoom.bridge);
    await tap('flight-request');
    await tap('flight-item-key');
    await tap('flight-locker');
    await tap('flight-locker');
    await tap('flight-item-reserve');
    await tap('flight-nav-socket');
    await tap('flight-launch', 2.6);
    expect(find.byKey(const Key('flight-complete')), findsOneWidget);
  }

  Future<void> debrief(String expected) async {
    await tap('flight-story-debrief', 2.9);
    await tap('story-next', 3.0);
    expect(find.byKey(const Key('story-line-together')), findsOneWidget);
    await tap('story-next', 3.4);
    expect(find.byKey(Key('story-task-$expected')), findsOneWidget);
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Uint8List noviceBackup;

  testWidgets(
    'fresh flight, five formats, resumed sentence and radio decision',
    (tester) async {
      final learning = LearningRepository(AppDatabase(NativeDatabase.memory()));
      final app = AppController(learning);
      await app.initialize();
      final player = Player(tester, onCamera: !comparisonOnly);
      await player.mount(app);
      if (!comparisonOnly) {
        await player.mark('STORY_FULL_START');
        await player.pause(2);
      }
      await player.journey(guided: true, nextDay: () {}, app: app);
      noviceBackup = await ProgressTransfer(
        learning,
        app.rewards.catalog,
      ).export();
      if (comparisonOnly) {
        await tester.pumpWidget(const SizedBox.shrink());
        await learning.db.close();
        return;
      }
      await player.debrief('answer');
      await player.tap('story-help', 2.4);
      await player.tap('story-option-1', 2);
      await player.tap('story-choice-send-log', 3.6);
      await player.tap('story-audio', 2);
      expect(app.audio.lastSource, SpeechSource.recording);
      await player.tap('story-next');
      await player.mark('STORY_FULL_END');
      final reopened = await StoryRepository(learning).read();
      expect(reopened.trust(StorySpeaker.miko), 1);
      expect(reopened.trust(StorySpeaker.pixie), 1);
      expect(
        app.inventory.grants.keys.where((id) => id == FirstFlight.reward),
        hasLength(1),
      );
      expect(app.progress.xp, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await learning.db.close();
    },
    timeout: const Timeout(Duration(minutes: 7)),
  );

  testWidgets('compare restored novice and earned spaced profile', (
    tester,
  ) async {
    var clock = DateTime.utc(2026, 11, 24, 9);
    final learning = LearningRepository(
      AppDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    final trained = AppController(learning);
    await trained.initialize();
    final player = Player(tester);
    await player.mount(trained);
    await player.journey(
      guided: false,
      nextDay: () => clock = clock.add(const Duration(days: 1, minutes: 2)),
      app: trained,
    );
    final snapshot = await StoryRepository(learning).knowledge.read();
    expect(
      snapshot.of(KnowledgeCatalog.skills['en:grammar:i-need']!).stage(),
      KnowledgeStage.applied,
    );

    final other = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final novice = AppController(other);
    await novice.initialize();
    final transfer = ProgressTransfer(other, novice.rewards.catalog);
    await transfer.restore(await transfer.validate(noviceBackup));
    await novice.reloadTransferredProgress();
    await player.mount(novice);
    await player.tap('reboot-start');
    await player.debrief('answer');
    player.onCamera = true;
    await player.mark('STORY_COMPARE_START');
    await player.pause(6);
    // Unmounting its ProviderScope disposed the first controller. Recreate it
    // from the same profile, as the app would after a fresh launch.
    final resumed = AppController(learning);
    await resumed.initialize();
    await player.mount(resumed);
    await player.tap('reboot-start');
    await player.debrief('phrase');
    await player.pause(4);
    await player.tap('story-option-1');
    await player.tap('story-choice-send-basic');
    expect(
      find.descendant(
        of: find.byKey(const Key('story-term')),
        matching: find.text('I need a battery.'),
      ),
      findsOneWidget,
    );
    await player.tap('story-term', 5);
    expect(find.text('Мне нужна батарея.'), findsOneWidget);
    await player.mark('STORY_COMPARE_END');
    await tester.pumpWidget(const SizedBox.shrink());
    await other.db.close();
    await learning.db.close();
  }, timeout: const Timeout(Duration(minutes: 7)));
}
