import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/adventure_map.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'support.dart';
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;
import 'widget_test.dart' show flushDb;

GoRouter mapRouter(GlobalKey? boundary) => GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => RepaintBoundary(
        key: boundary,
        child: Scaffold(
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: const [AdventureMap()],
          ),
        ),
      ),
    ),
    GoRoute(
      path: '/lesson/:id',
      builder: (_, state) =>
          LessonScreen(lessonId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/offline',
      builder: (_, _) => const Scaffold(body: Text('Сохранить офлайн-урок')),
    ),
    GoRoute(
      path: '/rewards',
      builder: (_, _) => const Scaffold(body: Text('Полученные сундуки')),
    ),
  ],
);

void main() {
  setUpAll(setupSqlite);
  testWidgets('focused region preserves gates and offline access', (
    tester,
  ) async {
    final repo = memoryRepository();
    final app = AppController(repo);
    await tester.runAsync(app.initialize);
    final router = mapRouter(null);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: MaterialApp.router(
          theme: orbitTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-lesson-a1-01')), findsOneWidget);
    expect(find.byKey(const ValueKey('map-lesson-a1-20')), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('map-lesson-a1-02')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-lesson-a1-02')));
    await tester.pumpAndSettle();
    expect(router.routeInformationProvider.value.uri.path, '/');
    expect(
      find.text('Пройдите предыдущий урок, чтобы открыть эту орбиту.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.byKey(const ValueKey('map-lesson-a1-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-lesson-a1-01')));
    await flushDb(tester);
    expect(find.byKey(const Key('lesson-preview-title')), findsOneWidget);
    await tester.tap(find.byKey(const Key('lesson-preview-start')));
    await flushDb(tester);
    await advanceTeaching(tester);
    expect(
      find.text(
        'Орби встречает тебя на космической станции. Что ему ответить?',
      ),
      findsOneWidget,
    );
    router.go('/');
    await flushDb(tester);
    await tester.runAsync(() async {
      await repo.uninstall('a1-01');
      await app.refresh();
    });
    await tester.ensureVisible(find.byKey(const ValueKey('map-lesson-a1-01')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('map-lesson-a1-01')));
    await tester.pumpAndSettle();
    expect(find.text('Сохранить офлайн-урок'), findsOneWidget);
    expect(app.progress.xp, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repo.db.close);
  });
  testWidgets('completed region focuses next mission and map never grants XP', (
    tester,
  ) async {
    final repo = memoryRepository();
    final app = AppController(repo);
    await tester.runAsync(() async {
      await app.initialize();
      for (var n = 1; n <= 4; n++) {
        await repo.append(
          repo.event('complete', {
            'session': 's$n',
            'lesson': 'a1-${n.toString().padLeft(2, '0')}',
          }),
        );
      }
      await app.refresh();
    });
    final xp = app.progress.xp, grants = app.inventory.grants.length;
    final router = mapRouter(null);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: MaterialApp.router(
          theme: orbitTheme(Brightness.light),
          routerConfig: router,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('map-lesson-a1-05')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('map-world-0')));
    await tester.pumpAndSettle();
    expect(
      find.text('Область исследована! Печать в паспорте путешествий.'),
      findsOneWidget,
    );
    await tester.ensureVisible(find.text('К текущей миссии'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('К текущей миссии'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('map-lesson-a1-05'))).dy,
      greaterThanOrEqualTo(0),
    );
    expect(app.progress.xp, xp);
    expect(app.inventory.grants.length, grants);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repo.db.close);
  });
  testWidgets('five regions fit 390 and 320px 200 percent in both themes', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = memoryRepository();
    final app = AppController(repo);
    await tester.runAsync(() async {
      await app.initialize();
      await loadPreviewFonts();
      if (Platform.environment['CAPTURE_UI'] == '1') {
        await Directory('test-output/v07').create(recursive: true);
      }
    });
    final container = ProviderContainer(
      overrides: [appProvider.overrideWith((_) => app)],
    );
    addTearDown(container.dispose);
    for (final small in [false, true]) {
      tester.view.physicalSize = Size(small ? 320 : 390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
      for (final brightness in Brightness.values) {
        final boundary = GlobalKey();
        final router = mapRouter(boundary);
        addTearDown(router.dispose);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: orbitTheme(brightness),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var region = 0; region < 5; region++) {
          final chip = find.byKey(ValueKey('map-world-$region'));
          await tester.ensureVisible(chip);
          await tester.pumpAndSettle();
          await tester.tap(chip);
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$small $brightness region $region',
          );
          if (region == 0) {
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await tester.runAsync(
              () => capturePreview(
                boundary,
                'v07/map-${brightness.name}${small ? '-320-200' : ''}',
              ),
            );
          }
          for (var n = region * 4 + 1; n <= region * 4 + 4; n++) {
            await tester.ensureVisible(
              find.byKey(
                ValueKey('map-lesson-a1-${n.toString().padLeft(2, '0')}'),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
          }
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
    await tester.runAsync(repo.db.close);
  });
}
