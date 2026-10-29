import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'package:orbitwords/ui/lesson_effects.dart';
import 'package:orbitwords/ui/mission_checkpoint.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  for (final small in [false, true]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'ordinary learning cycle ${theme.name} ${small ? "320 200%" : "390"}',
        (tester) async {
          tester.view.physicalSize = Size(small ? 320 : 390, small ? 760 : 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final repo = memoryRepository(now: () => DateTime(2026, 10, 29, 12));
          final app = AppController(repo), boundary = GlobalKey();
          final before = Platform.environment['BASELINE_V010'] == '1';
          final video =
              Platform.environment['LEARNING_VIDEO'] == '1' &&
              !small &&
              theme == ThemeMode.light;
          var frame = 0;
          await tester.runAsync(() async {
            await loadPreviewFonts();
            await Directory('test-output/v010/frames').create(recursive: true);
            await app.initialize();
            await app.finishOnboarding();
            await app.savePreferences(newTheme: theme);
            await app.saveAudio(
              AudioPreferences(
                speech: false,
                effects: false,
                reactions: !small,
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
          Future<void> film() async {
            if (!video) return;
            for (var i = 0; i < 3; i++) {
              await tester.pump(const Duration(milliseconds: 200));
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  'test-output/v010/frames/${(frame++).toString().padLeft(5, '0')}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }

          Future<void> tap(Finder target) async {
            if (target.hitTestable().evaluate().isEmpty) {
              final body = find.descendant(
                of: find.byType(QuestionEntrance),
                matching: find.byType(Scrollable),
              );
              final scrollable = body.evaluate().isNotEmpty
                  ? body.first
                  : find.byType(Scrollable).first;
              tester.state<ScrollableState>(scrollable).position.jumpTo(0);
              await tester.pumpAndSettle();
              for (
                var step = 0;
                step < 30 && target.evaluate().isEmpty;
                step++
              ) {
                final position = tester
                    .state<ScrollableState>(scrollable)
                    .position;
                position.jumpTo(
                  (position.pixels + 140).clamp(0, position.maxScrollExtent),
                );
                await tester.pumpAndSettle();
              }
              expect(target, findsOneWidget);
              await tester.ensureVisible(target);
              await tester.pumpAndSettle();
            }
            await tester.tap(target);
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 120)),
            );
            await film();
            await tester.pumpAndSettle();
          }

          Future<void> capture(String name) async {
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
                'v010/${before ? "before" : "after"}-$name-${theme.name}${small ? '-320-200' : ''}',
              ),
            );
          }

          await capture('today');
          router.go('/map');
          await flushDb(tester);
          await capture('map');
          if (!before) {
            await tap(find.byKey(const Key('map-lesson-a1-01')));
            await capture('preview');
            Navigator.of(
              tester.element(find.byKey(const Key('lesson-preview-start'))),
            ).pop();
            await tester.pumpAndSettle();
          }
          router.go('/lesson/a1-01');
          await flushDb(tester);
          await capture('intro');
          for (
            var i = 0;
            i < 12 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
            i++
          ) {
            await tap(find.byKey(const Key('teaching-next')));
          }
          final material = await tester.runAsync(
            () => repo.startLesson('a1-01'),
          );
          for (final e in material!.lesson.exercises) {
            if (e == material.lesson.exercises.first) {
              await capture('lesson-1');
              await tap(
                find.widgetWithText(
                  OutlinedButton,
                  e.options.firstWhere((o) => !e.answers.contains(o)),
                ),
              );
              await tap(find.text('Проверить'));
              await capture('error');
              await tap(find.text('Попробовать снова'));
              expect(find.text('Проверить'), findsOneWidget);
              if (!before) {
                await tap(find.text('Нужна подсказка?'));
                await capture('hint');
                await tap(find.text('Нужна подсказка?'));
              }
            }
            if (e.options.isNotEmpty) {
              await tap(find.widgetWithText(OutlinedButton, e.answers.first));
            } else if (e.type == ExerciseType.order) {
              for (final token in e.tokens) {
                await tap(find.widgetWithText(ActionChip, token));
              }
              await capture('sentence');
            } else if (e.type == ExerciseType.pairs) {
              for (final pair in e.pairs) {
                await tap(find.widgetWithText(OutlinedButton, pair.en));
                await tap(find.widgetWithText(OutlinedButton, pair.ru));
              }
              await capture('pairs');
            } else {
              await tester.scrollUntilVisible(
                find.byType(TextField),
                150,
                maxScrolls: 30,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(find.byType(TextField), e.answers.first);
              await tester.pumpAndSettle();
            }
            await tap(find.text('Проверить'));
            if (e == material.lesson.exercises.first) await capture('correct');
            await tap(find.text('Дальше'));
            if (find.byType(MissionCheckpoint).evaluate().isNotEmpty) {
              await capture('checkpoint');
              await tap(find.byKey(const Key('checkpoint-continue')));
            }
          }
          expect(app.progress.xp, 120);
          expect(app.progress.errors, 1);
          expect(app.inventory.grants.length, 3);
          await capture('completion');
          router.go('/');
          await flushDb(tester);
          await capture('daily-goal');
          await tester.runAsync(() async {
            final second = await repo.startLesson('a1-02');
            for (var i = 0; i < 10; i++) {
              final e = second.lesson.exercises[i];
              await repo.answer(
                second.session.id,
                i,
                e,
                e.answers.first,
                total: 10,
              );
            }
            final third = await repo.startLesson('a1-03');
            await repo.markTeachingSeen(third.session.id);
            await app.refresh();
          });
          router.go('/lesson/a1-03');
          await flushDb(tester);
          await capture('lesson-3');
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(repo.db.close);
        },
      );
    }
  }
}
