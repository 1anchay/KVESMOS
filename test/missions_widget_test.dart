import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/missions.dart';
import 'package:orbitwords/ui/app.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'missions award automatically; resume on a new date refreshes the open page',
    (tester) async {
      var clock = DateTime(2026, 10, 21, 12);
      final r = memoryRepository(now: () => clock);
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        await app.finishOnboarding();
        await r.append(
          r.event('complete', {'session': 'done', 'lesson': 'a1-01'}),
        );
        for (var i = 0; i < 10; i++) {
          await r.append(
            r.event('answer', {
              'session': 's',
              'exercise': 'q$i',
              'correct': true,
              'words': [],
            }),
          );
        }
        await app.refresh();
        await app.refresh();
      });
      expect(app.inventory.grants, hasLength(3)); // milestone + 2 daily rewards
      expect(app.progress.xp, 120);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
      router.go('/quests');
      await flushDb(tester);
      expect(find.text('Сегодня: 2026-10-21'), findsOneWidget);
      expect(app.missions!.awarded(DailyMission.all[0]), isTrue);
      expect(app.missions!.awarded(DailyMission.all[1]), isTrue);
      expect(find.text('Выполнено · сундук получен'), findsOneWidget);
      clock = DateTime(2026, 10, 22, 8);
      app.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await flushDb(tester);
      expect(find.text('Сегодня: 2026-10-22'), findsOneWidget);
      expect(find.text('Выполнено · сундук получен'), findsNothing);
      expect(app.inventory.grants, hasLength(3));
      expect(app.missions!.progress.answers, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  testWidgets(
    'foreground calendar timer updates at local midnight without a restart',
    (tester) async {
      var clock = DateTime(2026, 10, 21, 23, 59, 59, 990);
      final r = memoryRepository(now: () => clock);
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        expect(app.missions!.day, '2026-10-21');
        clock = DateTime(2026, 10, 22);
        final deadline = DateTime.now().add(const Duration(seconds: 3));
        while (app.missions!.day != '2026-10-22' &&
            DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(app.missions!.day, '2026-10-22');
        app.dispose();
        await r.db.close();
      });
    },
  );
  testWidgets('mission cards fit 320 pixels at 200% text in both themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final r = memoryRepository();
    final app = AppController(r);
    await tester.runAsync(() async {
      await app.initialize();
      await app.finishOnboarding();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
    router.go('/quests');
    await flushDb(tester);
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      await tester.runAsync(() => app.savePreferences(newTheme: theme));
      await tester.pumpAndSettle();
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      for (final mission in DailyMission.all) {
        await tester.scrollUntilVisible(find.text(mission.title), 250);
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: '${theme.name} ${mission.id}',
        );
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(r.db.close);
  });
}
