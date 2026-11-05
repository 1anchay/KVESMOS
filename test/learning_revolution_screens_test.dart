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
      testWidgets(
        '0.13 path, guide, practice and recall ${theme.name} ${small ? 320 : 390}',
        (tester) async {
          tester.view.physicalSize = Size(small ? 320 : 390, 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final r = memoryRepository(),
              app = AppController(r),
              boundary = GlobalKey();
          await tester.runAsync(() async {
            await Directory('test-output/v013').create(recursive: true);
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
            await app.selectCourse('ru-zh');
            for (final info in r.catalog.take(6)) {
              await r.append(
                r.event('complete', {
                  'lesson': info.id,
                  'session': 'seed:${info.id}',
                }),
              );
            }
            final word = r.vocabulary.values.first;
            await r.review(word, 'wrong');
            await app.refresh();
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appProvider.overrideWith((_) => app)],
              child: RepaintBoundary(key: boundary, child: const OrbitApp()),
            ),
          );
          await flushDb(tester);
          final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
          Future<void> capture(String name) async {
            await flushDb(tester);
            await tester.runAsync(() async {
              for (final image in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(image.image, boundary.currentContext!);
              }
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: name);
            await tester.runAsync(
              () => capturePreview(
                boundary,
                'v013/$name-${theme.name}-${small ? 320 : 390}',
              ),
            );
          }

          for (final route in [
            '/map',
            '/training',
            '/practice/listen',
            '/practice/speak',
            '/practice/mistakes',
          ]) {
            router.go(route);
            await capture(route.substring(1).replaceAll('/', '-'));
          }
          await tester.runAsync(() => app.selectCourse('ru-de'));
          await flushDb(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: 'switch course with practice mounted',
          );
          await tester.runAsync(() => app.selectCourse('ru-zh'));
          router.go('/map');
          await flushDb(tester);
          final guide = find.text('Перед стартом · справочник').first;
          await tester.scrollUntilVisible(
            guide,
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(guide);
          await tester.pumpAndSettle();
          await tester.tap(guide);
          await capture('guide');
          Navigator.of(tester.element(find.text('Перед стартом'))).pop();
          await flushDb(tester);
          router.go('/lesson/zh-a1-07');
          await flushDb(tester);
          await advanceTeaching(tester);
          await capture('lesson-zh');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(r.db.close);
        },
      );
    }
  }
}
