import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/knowledge_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized().framePolicy =
      LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  const capture = bool.fromEnvironment('FIRST_FLIGHT_CAPTURE');

  testWidgets('clean launch, speech, exploration, recovery, saved ending', (
    tester,
  ) async {
    final learning = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(learning);
    await app.initialize();
    expect(app.onboarded, isFalse);

    Future<void> mark(String label) async {
      if (capture) {
        await Process.run('/system/bin/log', ['-t', 'KVESMOS11', label]);
      }
    }

    Future<void> pause(int seconds) => Future<void>.delayed(
      Duration(milliseconds: capture ? seconds * 1000 : 650),
    );

    Future<void> tap(String id, [int seconds = 5]) async {
      final target = find.byKey(Key(id));
      expect(target, findsOneWidget, reason: id);
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(target.hitTestable(), findsOneWidget, reason: id);
      await tester.tap(target);
      await pause(seconds);
      await tester.pump();
      expect(tester.takeException(), isNull, reason: id);
    }

    Future<void> briefing(FlightRoom room) async {
      await tap('flight-orbi', 9);
      for (final w in FlightWord.deck(room)) {
        expect(find.text(w.english), findsOneWidget);
        expect(find.text(w.translation), findsOneWidget);
        expect(app.audio.lastSource, SpeechSource.recording, reason: w.english);
        await tap('flight-understood', w == FlightWord.deck(room).last ? 6 : 9);
      }
    }

    await mark('FIRST_FLIGHT_START');
    if (capture) await Future<void>.delayed(const Duration(seconds: 1));
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(gameplayReboot: true),
      ),
    );
    await pause(6);
    await tester.pump();
    await tap('reboot-start', 10);
    expect(find.text('Door'), findsNothing);
    await tester.tapAt(
      tester.getTopLeft(find.byKey(const Key('flight-floor'))) +
          const Offset(155, 185),
    );
    await pause(4);
    await tap('flight-porthole', 6);
    await tap('flight-log', 7);
    await briefing(FlightRoom.airlock);
    await tap('flight-hatch', 7);
    expect(find.textContaining('Замок открывается ключом'), findsOneWidget);
    await tap('flight-toolbox', 7);
    await tap('flight-item-key');
    await tap('flight-hatch');
    await tap('flight-hatch', 8);
    await briefing(FlightRoom.workshop);
    await tap('flight-cable');
    await tap('flight-battery');
    await tap('flight-item-cable');
    await tap('flight-sockets');
    await tap('flight-item-battery');
    await tap('flight-charger');
    await tap('flight-breaker', 8);
    expect(find.textContaining('Цепь ещё разомкнута'), findsOneWidget);
    await tap('flight-help', 8);
    await tap('flight-turn-a');
    await tap('flight-turn-a', 4);
    await tap('flight-turn-a', 4);
    await tap('flight-turn-b', 4);
    await tap('flight-breaker', 7);
    await tap('flight-to-airlock');
    await tap('flight-porthole', 7);
    await tap('flight-hatch');
    await tap('flight-to-bridge', 8);
    await briefing(FlightRoom.bridge);
    await tap('flight-request', 8);
    await tap('flight-item-key');
    await tap('flight-locker');
    await tap('flight-locker');
    await tap('flight-item-reserve');
    await tap('flight-nav-socket', 8);
    expect(find.text('Свет горит'), findsOneWidget);
    expect(app.audio.lastText, FlightWord.press.english);
    expect(app.audio.lastSource, SpeechSource.recording);
    await tap('flight-launch', 10);
    expect(find.byKey(const Key('flight-complete')), findsOneWidget);
    await mark('FIRST_FLIGHT_END');

    await tap('flight-home', 2);
    expect(find.text('Итоги полёта'), findsOneWidget);
    await tap('reboot-start', 2);
    expect(find.byKey(const Key('flight-complete')), findsOneWidget);
    expect(
      app.inventory.grants.keys.where((id) => id == FirstFlight.reward),
      hasLength(1),
    );
    expect(
      (await FirstFlightRepository(learning).read()).learned,
      hasLength(8),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await learning.db.close();
  }, timeout: const Timeout(Duration(minutes: 12)));

  testWidgets('offline translation, favorite and immersion on the ship', (
    tester,
  ) async {
    const record = bool.fromEnvironment('IMMERSION_CAPTURE');
    var clock = DateTime.utc(2026, 11, 23);
    final learning = LearningRepository(
      AppDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    final app = AppController(learning);
    await app.initialize();
    final flight = FirstFlightRepository(learning);
    var f = await flight.read();
    for (final term in FlightWord.deck(FlightRoom.airlock)) {
      f = (await flight.act(f.revision, FlightAction.teach, term)).flight;
    }
    // Simulated days make the small demo reproducible without weakening the policy.
    final door = KnowledgeCatalog.flight[FlightWord.door]!;
    final repo = KnowledgeRepository(learning);
    await repo.check(
      door.skill,
      context: 'journal-recall',
      check: KnowledgeCheck.recall,
      correct: true,
    );
    clock = clock.add(const Duration(days: 1));
    await repo.check(
      door.skill,
      context: 'journal-recall',
      check: KnowledgeCheck.recall,
      correct: true,
    );

    Future<void> mark(String text) async {
      if (record) {
        await Process.run('/system/bin/log', ['-t', 'KVESMOS11', text]);
      }
    }

    Future<void> settle([int seconds = 3]) async {
      await Future<void>.delayed(
        Duration(milliseconds: record ? seconds * 1000 : 700),
      );
      await tester.pump();
    }

    Future<void> tap(Finder target, [int seconds = 3]) async {
      expect(target, findsOneWidget);
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
      expect(target.hitTestable(), findsOneWidget);
      await tester.tap(target);
      await settle(seconds);
    }

    Future<void> pop(Finder marker) async {
      Navigator.of(tester.element(marker)).pop();
      await settle(2);
    }

    Finder byKey(String id) => find.byKey(Key(id));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(gameplayReboot: true),
      ),
    );
    await settle();
    await mark('FIRST_FLIGHT_START');
    await settle(2);
    await tap(byKey('reboot-start'));
    expect(
      find.descendant(
        of: byKey('flight-term-hatch'),
        matching: find.text('Door'),
      ),
      findsOneWidget,
    );
    await tap(byKey('flight-term-hatch'), 5);
    await tap(byKey('term-audio'), 3);
    expect(app.audio.lastSource, SpeechSource.recording);
    await tap(byKey('term-favorite'));
    expect((await flight.read()).revision, 2);
    await pop(byKey('term-favorite'));
    await tap(byKey('flight-toolbox'));
    expect(
      find.descendant(
        of: byKey('flight-inventory-term-key'),
        matching: find.text('Ключ · Key'),
      ),
      findsOneWidget,
    );
    await tap(byKey('flight-journal'), 4);
    await tap(find.text('Избранное'));
    expect(find.byKey(ValueKey('journal-${door.skill.id}')), findsOneWidget);
    await tap(find.text('Режим погружения'));
    await tap(byKey('immersion-beginner'));
    await pop(byKey('immersion-beginner'));
    await pop(byKey('journal-search'));
    expect(
      find.descendant(
        of: byKey('flight-term-hatch'),
        matching: find.text('дверь · Door'),
      ),
      findsOneWidget,
    );
    await tap(byKey('flight-item-key'));
    await tap(byKey('flight-hatch'), 4);
    expect((await flight.read()).unlocked, isTrue);
    await mark('FIRST_FLIGHT_END');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await learning.db.close();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
