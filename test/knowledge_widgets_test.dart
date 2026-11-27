import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/knowledge_repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);

  for (final brightness in ['light', 'dark']) {
    testWidgets('journal and independent hit targets in $brightness theme', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var now = DateTime.utc(2026, 11, 20);
      final learning = memoryRepository(now: () => now);
      final app = AppController(learning);
      final knowledge = KnowledgeRepository(learning);
      final door = KnowledgeCatalog.flight[FlightWord.door]!;
      final flight = FirstFlight()
        ..revision = 2
        ..learned.addAll(FlightWord.deck(FlightRoom.airlock));
      await tester.runAsync(() async {
        await learning.setSetting('theme', brightness);
        await app.initialize();
        await app.saveAudio(
          const AudioPreferences(speech: false, reactions: false),
        );
        await learning.setSetting(
          FirstFlightRepository.key,
          jsonEncode(flight.toJson()),
        );
        await knowledge.check(
          door.skill,
          check: KnowledgeCheck.recall,
          context: 'journal-recall',
          correct: true,
        );
        now = now.add(const Duration(days: 1));
        await knowledge.check(
          door.skill,
          check: KnowledgeCheck.recall,
          context: 'journal-recall',
          correct: true,
        );
        now = now.add(const Duration(days: 8));
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(gameplayReboot: true),
        ),
      );
      await flushDb(tester);
      Future<void> tap(String key) async {
        final target = find.byKey(Key(key));
        await tester.ensureVisible(target);
        await tester.pumpAndSettle();
        expect(target.hitTestable(), findsOneWidget, reason: key);
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 400));
        await flushDb(tester);
        expect(tester.takeException(), isNull);
      }

      Future<void> pop(Key key) async {
        Navigator.of(tester.element(find.byKey(key))).pop();
        await flushDb(tester);
      }

      await tap('reboot-start');
      expect(
        Theme.of(
          tester.element(find.byKey(const Key('flight-journal'))),
        ).brightness,
        brightness == 'dark' ? Brightness.dark : Brightness.light,
      );
      expect(
        find.descendant(
          of: find.byKey(const Key('flight-term-hatch')),
          matching: find.text('Door'),
        ),
        findsOneWidget,
      );
      await tap('flight-term-hatch');
      expect(find.text('Открой дверь.'), findsOneWidget);
      expect(find.text('/dɔɹ/'), findsOneWidget);
      await tap('term-favorite');
      final afterLabel = await tester.runAsync(
        () async => (await FirstFlightRepository(learning).read()).revision,
      );
      expect(afterLabel, 2);
      await pop(const Key('term-favorite'));
      await tap('flight-hatch');
      expect(find.textContaining('Замок открывается ключом'), findsOneWidget);
      await tap('flight-journal');
      final search = find.byKey(const Key('journal-search'));
      await tester.enterText(search, 'дверь');
      await flushDb(tester);
      expect(find.byKey(ValueKey('journal-${door.skill.id}')), findsOneWidget);
      expect(find.text('Ключ · Key'), findsNothing);
      await tester.enterText(search, 'door');
      await flushDb(tester);
      expect(find.byKey(ValueKey('journal-${door.skill.id}')), findsOneWidget);
      await tap('journal-practice');
      await tester.enterText(
        find.byKey(const Key('knowledge-answer')),
        'DOOR.',
      );
      await tap('knowledge-check');
      expect(
        find.text('Верно. Записано как ответ с подсказкой.'),
        findsOneWidget,
      );
      await pop(const Key('knowledge-feedback'));
      await pop(const Key('journal-search'));
      expect(find.text('Шлюз'), findsOneWidget);
      final state = await tester.runAsync(
        () async => (await knowledge.read()).of(door.skill),
      );
      expect(state!.favorite, isTrue);
      expect(state.independent, 2);
      expect(state.assisted, 1);
      expect(
        find.descendant(
          of: find.byKey(const Key('flight-term-hatch')),
          matching: find.text('дверь · Door'),
        ),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await learning.db.close();
    });
  }
}
