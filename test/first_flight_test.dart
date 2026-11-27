import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/first_flight_page.dart';

import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);

  test('teaching gates, circuit, resume, and atomic reward', () async {
    final learning = memoryRepository();
    addTearDown(learning.db.close);
    await learning.setSetting('legacy-progress-check', 'keep');
    final repo = FirstFlightRepository(learning);
    var f = await repo.read();
    Future<String?> act(FlightAction action, [Object? value]) async {
      final result = await repo.act(f.revision, action, value);
      f = result.flight;
      return result.message;
    }

    expect(await act(FlightAction.take, FlightItem.key), contains('Орби'));
    expect(await act(FlightAction.teach, FlightWord.key), isNotNull);
    for (final w in FlightWord.deck(f.room)) {
      expect(await act(FlightAction.teach, w), isNull);
    }
    expect(await act(FlightAction.take, FlightItem.key), isNull);
    expect(await act(FlightAction.unlock, FlightItem.key), isNull);
    expect(await act(FlightAction.travel, FlightRoom.workshop), isNull);
    for (final w in FlightWord.deck(f.room)) {
      expect(await act(FlightAction.teach, w), isNull);
    }
    expect(await act(FlightAction.take, FlightItem.cable), isNull);
    expect(await act(FlightAction.take, FlightItem.battery), isNull);
    f = await FirstFlightRepository(learning).read();
    expect(f.room, FlightRoom.workshop);
    expect(f.inventory, {FlightItem.cable, FlightItem.battery, FlightItem.key});
    expect(await act(FlightAction.fitCable, FlightItem.cable), isNull);
    expect(await act(FlightAction.fitBattery, FlightItem.battery), isNull);
    expect(await act(FlightAction.breaker), contains('разомкнута'));
    for (var i = 0; i < 3; i++) {
      expect(await act(FlightAction.turnA), isNull);
    }
    expect(await act(FlightAction.turnB), isNull);
    expect(await act(FlightAction.breaker), isNull);
    expect(await act(FlightAction.travel, FlightRoom.bridge), isNull);
    for (final w in FlightWord.deck(f.room)) {
      expect(await act(FlightAction.teach, w), isNull);
    }
    expect(await act(FlightAction.unlock, FlightItem.key), contains('Попроси'));
    expect(await act(FlightAction.requestReserve), isNull);
    expect(await act(FlightAction.unlock, FlightItem.key), isNull);
    expect(await act(FlightAction.take, FlightItem.reserve), isNull);
    expect(await act(FlightAction.launch), contains('Свет'));
    expect(await act(FlightAction.fitReserve, FlightItem.reserve), isNull);
    final revision = f.revision;
    await Future.wait([
      repo.act(revision, FlightAction.launch),
      repo.act(revision, FlightAction.launch),
    ]);
    expect((await repo.read()).complete, isTrue);
    final inventory = Inventory.decode(
      await learning.setting(RewardsRepository.storageKey),
    );
    expect(inventory.grants.keys, [FirstFlight.reward]);
    expect(await learning.setting('legacy-progress-check'), 'keep');
  });

  testWidgets(
    'fresh Russian entry teaches before acting at 320dp and 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final db = memoryRepository();
      final app = AppController(db);
      await tester.runAsync(app.initialize);
      await tester.runAsync(
        () => app.saveAudio(
          const AudioPreferences(speech: false, reactions: false),
        ),
      );
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
        await tester.pump();
        expect(target.hitTestable(), findsOneWidget, reason: key);
        await tester.tap(target);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pump(const Duration(milliseconds: 400));
        await flushDb(tester);
        expect(tester.takeException(), isNull, reason: key);
      }

      expect(app.onboarded, isFalse);
      expect(tester.takeException(), isNull);
      expect(find.byType(RebootHome), findsOneWidget);
      expect(find.byKey(const Key('reboot-study')), findsOneWidget);
      await tap('reboot-start');
      expect(find.text('Поговори с Орби'), findsOneWidget);
      expect(find.text('Door'), findsNothing);
      await tap('flight-orbi');
      expect(find.text('Door'), findsOneWidget);
      expect(find.text('дверь'), findsOneWidget);
      await tap('flight-understood');
      expect(find.text('Key'), findsOneWidget);
      await tap('flight-understood');
      await tap('flight-toolbox');
      await tap('flight-item-key');
      await tap('flight-hatch');
      expect(find.textContaining('Замок открылся'), findsOneWidget);
      await tap('flight-hatch');
      await tap('flight-orbi');
      await tap('flight-understood');
      await tap('flight-understood');
      await tap('flight-cable');
      await tap('flight-battery');
      await tap('flight-item-cable');
      await tap('flight-sockets');
      await tap('flight-item-battery');
      await tap('flight-charger');
      await tap('flight-turn-a');
      await tap('flight-turn-a');
      await tap('flight-turn-a');
      await tap('flight-turn-b');
      await tap('flight-breaker');
      await tap('flight-to-bridge');
      await tap('flight-orbi');
      for (final _ in FlightWord.deck(FlightRoom.bridge)) {
        await tap('flight-understood');
      }
      await tap('flight-request');
      await tap('flight-item-key');
      await tap('flight-locker');
      await tap('flight-locker');
      await tap('flight-item-reserve');
      await tap('flight-nav-socket');
      await tap('flight-launch');
      expect(find.byKey(const Key('flight-complete')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await db.db.close();
    },
  );

  testWidgets('an existing profile still opens the study shell and practice', (
    tester,
  ) async {
    final db = memoryRepository();
    final app = AppController(db);
    await tester.runAsync(app.initialize);
    await tester.runAsync(app.finishOnboarding);
    await tester.runAsync(
      () => app.saveAudio(
        const AudioPreferences(speech: false, reactions: false),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(gameplayReboot: true),
      ),
    );
    await flushDb(tester);
    final study = find.byKey(const Key('reboot-study'));
    await tester.ensureVisible(study);
    await tester.tap(study);
    await flushDb(tester);
    expect(
      tester.widget<OrbitShell>(find.byType(OrbitShell)).location,
      '/study',
    );
    await tester.tap(find.byIcon(Icons.style_outlined).last);
    await flushDb(tester);
    expect(
      tester.widget<OrbitShell>(find.byType(OrbitShell)).location,
      '/training',
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await db.db.close();
  });
}
