import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  for (final small in [false, true]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('languages ${theme.name} ${small ? "320-200" : "390"}', (
        tester,
      ) async {
        tester.view.physicalSize = Size(small ? 320 : 390, small ? 760 : 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final r = memoryRepository(),
            app = AppController(r),
            boundary = GlobalKey();
        await tester.runAsync(() async {
          await Directory('test-output/v012').create(recursive: true);
          await loadPreviewFonts();
          await app.initialize();
          await app.finishOnboarding();
          await app.savePreferences(newTheme: theme);
          await app.saveAudio(
            const AudioPreferences(
              speech: false,
              effects: false,
              reactions: false,
            ),
          );
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: RepaintBoundary(key: boundary, child: const OrbitApp()),
          ),
        );
        await flushDb(tester);
        final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
        Future<void> capture(String label) async {
          await flushDb(tester);
          await tester.runAsync(() async {
            for (final image in tester.widgetList<Image>(find.byType(Image))) {
              await precacheImage(image.image, boundary.currentContext!);
            }
          });
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: label);
          await tester.runAsync(
            () => capturePreview(
              boundary,
              'v012/$label-${theme.name}-${small ? "320-200" : "390"}',
            ),
          );
        }

        router.go('/courses');
        await capture('courses');
        for (final lang in ['es', 'de', 'fr', 'zh', 'en']) {
          await tester.runAsync(() => app.selectCourse('ru-$lang'));
          router.go('/');
          await capture('today-$lang');
          router.go('/map');
          await capture('map-$lang');
          if (lang == 'en') {
            await tester.runAsync(() async {
              for (final lesson in r.catalog.take(20)) {
                await r.append(
                  r.event('complete', {
                    'lesson': lesson.id,
                    'session': 'preview-${lesson.id}',
                  }),
                );
              }
              await app.refresh();
            });
          }
          router.go('/lesson/${lang == 'en' ? 'en-a1-21' : '$lang-a1-01'}');
          await capture('teaching-$lang');
          await advanceTeaching(tester);
          await capture('lesson-$lang');
        }
        for (final language in ['en', 'es', 'de', 'fr', 'zh']) {
          await tester.runAsync(() async {
            await app.selectCourse('ru-$language');
            final run = await r.startLesson(r.catalog.first.id);
            await r.answer(
              run.session.id,
              0,
              run.lesson.exercises.first,
              run.lesson.exercises.first.answers.first,
              total: 10,
            );
            await app.refresh();
          });
        }
        for (final route in [
          '/profile',
          '/inventory',
          '/rewards',
          '/achievements',
          '/stats',
          '/companion/reminders',
          '/companion/widget',
        ]) {
          router.go(route);
          await capture(route.substring(1).replaceAll('/', '-'));
        }
        router.go('/profile');
        await flushDb(tester);
        await tester.scrollUntilVisible(
          find.text('Изучаю языков: 5'),
          250,
          maxScrolls: 40,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('passport-five');
        final grant = app.inventory.pending.first;
        router.go('/chest/${Uri.encodeComponent(grant.id)}');
        await capture('chest-before');
        await tester.ensureVisible(find.text('Без анимации'));
        await tester.tap(find.text('Без анимации'));
        await capture('chest-reveal');
        expect(app.inventory.pending.any((g) => g.id == grant.id), isFalse);
        router.go('/rewards');
        await capture('chest-removed');
        router.go('/settings');
        await flushDb(tester);
        await tester.scrollUntilVisible(
          find.byKey(const Key('reminders-enabled')),
          300,
          maxScrolls: 50,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('reminders');
        await tester.scrollUntilVisible(
          find.byKey(const Key('add-home-widget')),
          250,
          maxScrolls: 50,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('widget-help');
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      });
    }
  }
}
