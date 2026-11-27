import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
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
}
