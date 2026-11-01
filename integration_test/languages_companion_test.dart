// Run only on the dedicated QA emulator; preserve and restore its app data.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:drift/native.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'package:go_router/go_router.dart';

Future<void> marker(String value) async {
  await Process.run('/system/bin/log', ['-t', 'KVESMOS_QA', value]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'three native courses offline with independent XP and widget projection',
    (tester) async {
      final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
      final app = AppController(repo);
      await app.initialize();
      await app.finishOnboarding();
      await app.saveAudio(
        const AudioPreferences(speech: true, effects: true, reactions: true),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        if (finder.evaluate().isEmpty ||
            finder.hitTestable().evaluate().isEmpty) {
          await tester.scrollUntilVisible(
            finder,
            180,
            maxScrolls: 35,
            scrollable: find.byType(Scrollable).first,
          );
        }
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
        for (
          var i = 0;
          i < 30 && find.text('Сохраняем…').evaluate().isNotEmpty;
          i++
        ) {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await tester.pumpAndSettle();
        }
        await Future<void>.delayed(const Duration(milliseconds: 80));
      }

      final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
      await marker('V011_PIN_WIDGET');
      await app.companion.pinWidget();
      // The companion QA driver confirms Android's system pin dialog.
      await Future<void>.delayed(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      await marker('V011_CYCLE_START');
      for (final language in ['en', 'es', 'de']) {
        if (language == 'es') await marker('V011_ES_START');
        router.go('/courses');
        await tester.pumpAndSettle();
        await tap(find.byKey(ValueKey('course-ru-$language')));
        expect(app.course.language, language);
        expect(app.progress.xp, 0);
        await tap(find.byKey(const Key('today-start')));
        await tap(find.text('Послушать пример'));
        if (language == 'en') {
          expect(app.audio.lastSource, SpeechSource.recording);
        } else {
          expect(app.audio.lastSource, isNot(SpeechSource.recording));
        }
        if (app.audio.lastProblem != null) {
          await Future<void>.delayed(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
        await tap(find.text('Медленнее'));
        if (app.audio.lastProblem != null) {
          await Future<void>.delayed(const Duration(seconds: 5));
          await tester.pumpAndSettle();
        }
        for (
          var i = 0;
          i < 10 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
          i++
        ) {
          await tap(find.byKey(const Key('teaching-next')));
        }
        final material = await repo.startLesson(
          language == 'en' ? 'a1-01' : '$language-a1-01',
        );
        for (final e in material.lesson.exercises) {
          if (e.options.isNotEmpty) {
            await tap(find.widgetWithText(OutlinedButton, e.answers.first));
          } else if (e.type == ExerciseType.order) {
            for (final token in e.tokens) {
              await tap(find.widgetWithText(ActionChip, token));
            }
          } else if (e.type == ExerciseType.pairs) {
            for (final pair in e.pairs) {
              await tap(find.widgetWithText(OutlinedButton, pair.en));
              await tap(find.widgetWithText(OutlinedButton, pair.ru));
            }
          } else {
            await tester.scrollUntilVisible(
              find.byType(TextField),
              180,
              maxScrolls: 35,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.enterText(find.byType(TextField), e.answers.first);
            await tester.pumpAndSettle();
          }
          await tap(find.text('Проверить'));
          await tap(find.text('Дальше'));
          if (find
              .byKey(const Key('checkpoint-continue'))
              .evaluate()
              .isNotEmpty) {
            await tap(find.byKey(const Key('checkpoint-continue')));
          }
        }
        expect(app.progress.xp, 120);
        expect(app.progress.streak(repo.now()), 1);
        expect(tester.takeException(), isNull);
        router.go('/');
        await tester.pumpAndSettle();
        await marker('V011_WIDGET_${language.toUpperCase()}');
        await Future<void>.delayed(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        if (language == 'es') await marker('V011_ES_DONE');
      }
      await app.selectCourse('ru-en');
      expect(app.progress.xp, 120);
      expect(app.globalProgress.xp, 360);
      final grants = app.inventory.grants.length;
      await app.selectCourse('ru-es');
      await app.selectCourse('ru-de');
      await app.selectCourse('ru-en');
      expect(app.inventory.grants.length, grants);
      await marker('V011_CYCLE_DONE');
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.db.close();
    },
  );
}
