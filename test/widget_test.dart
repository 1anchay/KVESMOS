import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/character_reactions.dart';
import 'support.dart';

Future<void> flushDb(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 120)),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setupSqlite);
  testWidgets('onboarding, navigation, real answer and restart position', (
    tester,
  ) async {
    final r = memoryRepository();
    final app = AppController(r);
    await tester.runAsync(app.initialize);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((ref) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Ваш следующий мир начинается со слова.'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      final next = find.widgetWithText(FilledButton, 'Продолжить');
      await tester.scrollUntilVisible(next, 250);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    final start = find.widgetWithText(FilledButton, 'Начать путешествие');
    await tester.scrollUntilVisible(start, 250);
    await tester.pumpAndSettle();
    await tester.tap(start);
    await flushDb(tester);
    expect(find.text('Галактика\nзнаний'), findsOneWidget);
    await tester.tap(find.text('Продолжить урок'));
    await flushDb(tester);
    await advanceTeaching(tester);
    expect(
      find.text(
        'Орби встречает тебя на космической станции. Что ему ответить?',
      ),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.widgetWithText(OutlinedButton, 'Hello!'),
      220,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(OutlinedButton, 'Hello!'));
    await flushDb(tester);
    final check = find.widgetWithText(FilledButton, 'Проверить');
    await tester.scrollUntilVisible(check, 250);
    await tester.pumpAndSettle();
    await tester.tap(check);
    await flushDb(tester);
    expect(app.progress.xp, 10);
    expect(find.text('Верно! +10 XP'), findsOneWidget);
    expect(find.text(CharacterCue.correct.lines.first), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть и сохранить'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Продолжить урок'));
    await flushDb(tester);
    final resumed = (await tester.runAsync(() => r.startLesson('a1-01')))!;
    expect(resumed.session.position, 1);
    expect(find.text(resumed.lesson.exercises[1].prompt), findsOneWidget);
    await tester.tap(find.byTooltip('Закрыть и сохранить'));
    await tester.pumpAndSettle();
    for (final label in ['Слова', 'Прогресс', 'Профиль', 'Карта']) {
      await tester.tap(find.text(label).last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(r.db.close);
  });
  testWidgets(
    'all pages fit small screen with 200% text; screenshots at normal scale',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        await app.finishOnboarding();
        final font = File(
          '.tools/flutter/bin/cache/artifacts/material_fonts/roboto-regular.ttf',
        );
        if (await font.exists()) {
          for (final family in ['OrbitSans', 'Roboto', 'Ahem']) {
            final loader = FontLoader(family)
              ..addFont(
                Future.value(ByteData.sublistView(await font.readAsBytes())),
              );
            await loader.load();
          }
          final icons = File(
            '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
          );
          final iconLoader = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(ByteData.sublistView(await icons.readAsBytes())),
            );
          await iconLoader.load();
        }
      });
      final boundary = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: RepaintBoundary(key: boundary, child: const OrbitApp()),
        ),
      );
      await tester.pumpAndSettle();
      final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
      for (final route in [
        '/',
        '/words',
        '/review',
        '/stats',
        '/achievements',
        '/quests',
        '/profile',
        '/inventory',
        '/rewards',
        '/crew',
        '/settings',
        '/offline',
      ]) {
        router.go(route);
        await flushDb(tester);
        expect(tester.takeException(), isNull, reason: route);
      }
      router.go('/');
      await tester.pumpAndSettle();
      if (Platform.environment['CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('test-output').create(recursive: true);
          await File(
            'test-output/home-light.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      await tester.runAsync(
        () => app.savePreferences(newTheme: ThemeMode.dark),
      );
      await tester.pumpAndSettle();
      if (Platform.environment['CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'test-output/home-dark.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final route in [
        '/',
        '/stats',
        '/settings',
        '/profile',
        '/inventory',
        '/rewards',
        '/crew',
        '/welcome',
        '/language',
        '/level',
        '/goal',
      ]) {
        router.go(route);
        await flushDb(tester);
        expect(tester.takeException(), isNull, reason: 'large text $route');
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
