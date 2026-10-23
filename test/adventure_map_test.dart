import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/adventure_map.dart';
import 'package:orbitwords/ui/character_reactions.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'support.dart';
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
  testWidgets(
    'map preserves locking, opens current lesson and sends missing packs to offline',
    (tester) async {
      final repository = memoryRepository();
      final controller = AppController(repository);
      await tester.runAsync(controller.initialize);
      final router = mapRouter(null);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => controller)],
          child: MaterialApp.router(
            theme: orbitTheme(Brightness.light),
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Текущий урок'), findsOneWidget);
      expect(find.byKey(const ValueKey('map-lesson-a1-20')), findsOneWidget);
      await tester.ensureVisible(
        find.byKey(const ValueKey('map-lesson-a1-02')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-lesson-a1-02')));
      await tester.pumpAndSettle();
      expect(
        find.text('Пройдите предыдущий урок, чтобы открыть эту орбиту.'),
        findsOneWidget,
      );
      expect(router.routeInformationProvider.value.uri.path, '/');
      await tester.ensureVisible(
        find.byKey(const ValueKey('map-lesson-a1-01')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-lesson-a1-01')));
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
        await repository.uninstall('a1-01');
        await controller.refresh();
      });
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('map-lesson-a1-01')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('map-lesson-a1-01')));
      await tester.pumpAndSettle();
      expect(find.text('Сохранить офлайн-урок'), findsOneWidget);
      expect(controller.progress.xp, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repository.db.close);
    },
  );
  testWidgets(
    'progress moves focus; map jumps to current stop and earned reward opens without granting again',
    (tester) async {
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        for (var i = 1; i <= 4; i++) {
          await r.append(
            r.event('complete', {
              'session': 's$i',
              'lesson': 'a1-${i.toString().padLeft(2, '0')}',
            }),
          );
        }
        await app.refresh();
      });
      final grants = app.inventory.grants.keys.toSet();
      final events = (await tester.runAsync(r.allEvents))!.length;
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
      expect(find.text('4 из 20 остановок освоено'), findsOneWidget);
      await tester.tap(find.text('К текущему уроку'));
      await tester.pumpAndSettle();
      final stop = find.byKey(const ValueKey('map-lesson-a1-05'));
      expect(tester.getTopLeft(stop).dy, greaterThanOrEqualTo(0));
      expect(
        tester.getTopLeft(stop).dy,
        lessThan(tester.view.physicalSize.height),
      );
      await tester.ensureVisible(find.byKey(const ValueKey('map-guide-2')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('На связи: Зиг Кварц'));
      await tester.pumpAndSettle();
      expect(find.text(CharacterCue.engineer.lines.first), findsOneWidget);
      final reward = find.byKey(
        const ValueKey('map-reward-unique_lessons_3_v1'),
      );
      await tester.ensureVisible(reward);
      await tester.pumpAndSettle();
      await tester.tap(reward);
      await tester.pumpAndSettle();
      expect(find.text('Полученные сундуки'), findsOneWidget);
      expect(app.inventory.grants.keys.toSet(), grants);
      expect((await tester.runAsync(r.allEvents))!.length, events);
      router.go('/');
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await r.append(
          r.event('complete', {'session': 's5', 'lesson': 'a1-05'}),
        );
        await app.refresh();
      });
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('map-lesson-a1-06')),
          matching: find.text('Текущий урок'),
        ),
        findsOneWidget,
      );
      expect(find.text('Текущий урок'), findsOneWidget);
      await tester.runAsync(() async {
        for (var i = 6; i <= 20; i++) {
          await r.append(
            r.event('complete', {
              'session': 's$i',
              'lesson': 'a1-${i.toString().padLeft(2, '0')}',
            }),
          );
        }
        await app.refresh();
      });
      await tester.pumpAndSettle();
      expect(find.text('Текущий урок'), findsNothing);
      expect(find.text('20 из 20 остановок освоено'), findsOneWidget);
      expect(find.text('Повторить первый урок'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  testWidgets(
    'ten worlds and twenty stops fit 320 pixels at 200% in both themes; captures normal layout',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository();
      final app = AppController(r);
      final boundary = GlobalKey();
      await tester.runAsync(() async {
        await app.initialize();
        for (var i = 1; i <= 4; i++) {
          await r.append(
            r.event('complete', {
              'session': 's$i',
              'lesson': 'a1-${i.toString().padLeft(2, '0')}',
            }),
          );
        }
        await app.refresh();
        final bytes = ByteData.sublistView(
          await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
        );
        for (final family in ['OrbitSans', 'Roboto', 'Ahem']) {
          final loader = FontLoader(family)..addFont(Future.value(bytes));
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(materialIconsFontPath()).readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
      final router = mapRouter(boundary);
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: orbitTheme(
                ref.watch(appProvider).theme == ThemeMode.dark
                    ? Brightness.dark
                    : Brightness.light,
              ),
              routerConfig: router,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        if (Platform.environment['CAPTURE_UI'] != '1') return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('test-output').create(recursive: true);
          await File(
            'test-output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      await tester.runAsync(() async {
        final context = tester.element(find.byType(AdventureMap));
        for (final type in ['explorer', 'nebula', 'supernova']) {
          await precacheImage(
            AssetImage('assets/kvesmos/${type}_closed.png'),
            context,
          );
        }
      });
      await tester.runAsync(() async {
        final context = tester.element(find.byType(AdventureMap));
        for (final name in ['miko', 'zig_quartz', 'aster']) {
          await precacheImage(AssetImage('assets/kvesmos/$name.png'), context);
        }
      });
      await tester.pumpAndSettle();
      await capture('kvesmos-map-overview');
      await tester.ensureVisible(find.byKey(const ValueKey('map-world-2')));
      await tester.pumpAndSettle();
      await capture('kvesmos-map-current');
      tester.view.physicalSize = const Size(320, 720);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await tester.runAsync(() => app.savePreferences(newTheme: theme));
        await tester.pumpAndSettle();
        for (final info in r.catalog) {
          await tester.ensureVisible(
            find.byKey(ValueKey('map-lesson-${info.id}')),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '${theme.name} ${info.id}',
          );
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
