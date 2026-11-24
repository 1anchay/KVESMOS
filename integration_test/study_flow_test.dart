import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'package:orbitwords/ui/lesson_screen.dart';

import '../test/support.dart' show advanceTeaching;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('first three lessons from a clean offline profile', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp('study-flow-');
    final file = File('${directory.path}/progress.sqlite');
    late LearningRepository repository;
    late AppController app;
    Future<void> launch() async {
      repository = LearningRepository(AppDatabase(NativeDatabase(file)));
      app = AppController(repository);
      await app.initialize();
      await app.saveAudio(
        const AudioPreferences(speech: false, effects: false, reactions: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> settle() async {
      for (var attempt = 0; attempt < 30; attempt++) {
        await tester.pumpAndSettle();
        if (find.text('Сохраняем…').evaluate().isEmpty &&
            find.text('Восстанавливаем…').evaluate().isEmpty) {
          return;
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }
      fail('The lesson did not finish saving');
    }

    Future<void> tap(Finder target) async {
      if (target.hitTestable().evaluate().isEmpty) {
        final scrollable = find.byType(Scrollable).first;
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(target, 190, scrollable: scrollable);
      }
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await settle();
    }

    Future<void> capture(String name) async {
      expect(tester.takeException(), isNull, reason: name);
      final marker = await Process.run('/system/bin/log', [
        '-t',
        'KVESMOS11',
        'CAPTURE:$name',
      ]);
      expect(marker.exitCode, 0);
      await Future<void>.delayed(const Duration(milliseconds: 850));
    }

    Future<void> stop() async {
      await tester.pumpWidget(const SizedBox.shrink());
      await repository.db.close();
    }

    await launch();
    try {
      expect(app.progress.xp, 0);
      await capture('01-welcome');
      await tap(find.text('Продолжить'));
      await tap(find.byKey(const ValueKey('course-ru-en')));
      await tap(find.text('Начать с нуля'));
      await tap(find.text('К уроку'));
      expect(app.onboarded, isTrue);
      expect(app.companion.preferences.enabled, isFalse);

      var totalCorrect = 0;
      for (var number = 1; number <= 3; number++) {
        final id = 'a1-0$number';
        expect(
          tester.widget<LessonScreen>(find.byType(LessonScreen)).lessonId,
          id,
        );
        await advanceTeaching(tester);
        final material = await repository.previewLesson(id);
        final lesson = material.lesson;
        final session = material.session!;
        if (number == 1) await capture('02-first-exercise');
        for (final (index, exercise) in lesson.exercises.indexed) {
          if (number == 1 && index == 0) {
            final wrong = exercise.options.firstWhere(
              (option) => !checkAnswer(exercise, option),
            );
            await tap(find.widgetWithText(OutlinedButton, wrong));
            await tap(find.text('Проверить'));
            expect(find.text('Почти! Я помогу.'), findsOneWidget);
            expect(
              find.text('Верный вариант: ${exercise.answers.first}'),
              findsOneWidget,
            );
            expect(app.progress.xp, 0);
            await capture('03-first-mistake');
            await tap(find.text('Попробовать снова'));
          }
          if (exercise.audio != null) {
            await tap(find.widgetWithText(OutlinedButton, 'Прослушать'));
            expect(
              tester
                  .widget<Text>(find.byKey(const Key('audio-transcript')))
                  .data,
              exercise.audio,
            );
          }
          if (exercise.options.isNotEmpty) {
            await tap(
              find.widgetWithText(OutlinedButton, exercise.answers.first),
            );
          } else if (exercise.type == ExerciseType.order) {
            for (final word in exercise.tokens) {
              await tap(
                find
                    .byWidgetPredicate(
                      (widget) =>
                          widget is ActionChip &&
                          widget.onPressed != null &&
                          widget.label is Text &&
                          (widget.label as Text).data == word,
                    )
                    .first,
              );
            }
          } else if (exercise.type == ExerciseType.pairs) {
            for (final pair in exercise.pairs) {
              await tap(find.widgetWithText(OutlinedButton, pair.en));
              await tap(find.widgetWithText(OutlinedButton, pair.ru));
            }
          } else {
            final input = find.byType(TextField);
            await tester.ensureVisible(input);
            await tester.enterText(input, exercise.answers.first);
            await settle();
          }
          await tap(find.text('Проверить'));
          if (number == 1 &&
              exercise.type == ExerciseType.order &&
              index == 2) {
            expect(
              tester
                  .widgetList<InputChip>(find.byType(InputChip))
                  .every((chip) => chip.onDeleted == null),
              isTrue,
            );
            await capture('07-checked-word-order');
          }
          await tap(find.text('Дальше'));
          totalCorrect++;
          final checkpoint = find.byKey(const Key('checkpoint-continue'));
          if (checkpoint.evaluate().isNotEmpty) await tap(checkpoint);
          if (number == 2 && index == 0) {
            final before = await repository.session(session.id);
            final xp = app.progress.xp;
            await stop();
            await launch();
            expect(app.progress.xp, xp);
            expect(find.text('Продолжить урок'), findsOneWidget);
            await capture('05-resume-after-reopen');
            await repository.uninstall(id);
            await app.refresh();
            await settle();
            expect(find.text('Восстановить урок'), findsOneWidget);
            await tap(find.byKey(const Key('today-start')));
            expect(find.text('Восстановить и открыть'), findsOneWidget);
            await capture('06-offline-restore');
            await tap(find.text('Восстановить и открыть'));
            expect(app.installed, contains(id));
            expect(app.progress.xp, xp);
            expect(find.byType(LessonIntroduction), findsNothing);
            final after = (await repository.previewLesson(id)).session!;
            expect(after.id, before.id);
            expect(after.position, before.position);
          }
        }
        expect(app.progress.completed, contains(id));
        expect(app.progress.correct, totalCorrect);
        expect(app.progress.errors, 1);
        expect(find.text('Ещё одно открытие!'), findsOneWidget);
        final next = find.byKey(const Key('completion-next'));
        expect(next.hitTestable(), findsOneWidget);
        if (number == 1) {
          expect(find.text('Открыть находки').hitTestable(), findsOneWidget);
        }
        await capture('lesson-$number-completion');
        if (number < 3) await tap(next);
      }
      expect(app.progress.completed, {'a1-01', 'a1-02', 'a1-03'});
      final router = GoRouter.of(tester.element(find.byType(LessonScreen)));
      router.go('/');
      await tester.pumpAndSettle();
      expect(app.courseStart.next?.id, 'a1-04');
      await capture('next-lesson-after-three');
      await Process.run('/system/bin/log', ['-t', 'KVESMOS11', 'DONE']);
    } finally {
      await stop();
      await directory.delete(recursive: true);
    }
  });
}
