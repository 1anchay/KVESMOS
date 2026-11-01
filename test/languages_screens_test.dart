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
          await Directory('test-output/v011').create(recursive: true);
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
          expect(tester.takeException(), isNull, reason: label);
          await tester.runAsync(
            () => capturePreview(
              boundary,
              'v011/$label-${theme.name}-${small ? "320-200" : "390"}',
            ),
          );
        }

        router.go('/courses');
        await capture('courses');
        for (final lang in ['es', 'de', 'en']) {
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
