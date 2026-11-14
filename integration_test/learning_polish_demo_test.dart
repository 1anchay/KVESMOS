import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/conversation_repository.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/picture_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/smart_placement_repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/mistake_feedback.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_screen.dart';

Future<void> marker(String value) =>
    Process.run('/system/bin/log', ['-t', 'KVESMOS11', value]);

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('five offline learning flows on Android', (tester) async {
    var clock = DateTime.now();
    final today = clock;
    final r = LearningRepository(
      AppDatabase(NativeDatabase.memory()),
      now: () => clock,
    );
    final app = AppController(r);
    await app.initialize();
    await app.finishOnboarding();
    await app.saveAudio(
      const AudioPreferences(speech: false, effects: false, reactions: false),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
    Future<void> go(String route) async {
      router.go(route);
      await tester.pumpAndSettle();
    }

    Future<void> show(Finder finder) async {
      if (finder.hitTestable().evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          200,
          maxScrolls: 35,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
    }

    Future<void> tap(Finder finder) async {
      await show(finder);
      await tester.tap(finder);
      await tester.pumpAndSettle();
      await Future<void>.delayed(const Duration(milliseconds: 180));
      await tester.pumpAndSettle();
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: name);
      await marker('CAPTURE:$name');
      await Future<void>.delayed(const Duration(seconds: 2));
    }

    for (final (index, lang) in ['en', 'es', 'de', 'fr', 'zh'].indexed) {
      await app.savePreferences(
        newTheme: index.isEven ? ThemeMode.light : ThemeMode.dark,
      );
      if (lang == 'en' || lang == 'zh') await marker('VIDEO_START:$lang');
      await go('/courses');
      await tap(find.byKey(ValueKey('course-ru-$lang')));
      expect(find.text('С чего начнём?'), findsOneWidget);
      final test = find.widgetWithText(OutlinedButton, 'Проверить мои знания');
      await tap(test);
      await capture('placement-$lang');
      final placement = SmartPlacementRepository(r);
      var state = (await placement.saved())!;
      final beforePlacement = await r.progress();
      final beforeGrants = app.inventory.grants.length;
      for (var step = 0; step < 12; step++) {
        final question = SmartPlacementRepository.question(state)!;
        final answer = (question['answers'] as List).first as String;
        final tokens = question['tokens'] as List;
        if (tokens.isNotEmpty) {
          for (var i = 0; i < tokens.length; i++) {
            await tap(find.byKey(ValueKey('placement-token-$i')));
          }
          await tap(find.widgetWithText(FilledButton, 'Ответить'));
        } else if ((question['options'] as List).isNotEmpty) {
          await tap(find.widgetWithText(OutlinedButton, answer));
        } else {
          final input = find.byType(TextField);
          await show(input);
          await tester.enterText(input, answer);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tap(find.widgetWithText(FilledButton, 'Ответить'));
        }
        final next = (await placement.saved())!;
        expect(
          (next['results'] as List).length,
          (state['results'] as List).length + 1,
        );
        state = next;
        if (lang == 'en' && (state['results'] as List).length == 1) {
          await tap(find.byTooltip('Сохранить и выйти'));
          await tap(find.byKey(ValueKey('course-ru-$lang')));
          await tap(test);
          expect(find.text('Задание 2'), findsOneWidget);
        }
      }
      expect(state['level'], greaterThan(0));
      expect((await r.progress()).xp, beforePlacement.xp);
      await capture('recommendation-$lang');
      await tap(find.widgetWithText(FilledButton, 'Начать с рекомендованного'));
      expect(
        tester.widget<LessonScreen>(find.byType(LessonScreen)).lessonId,
        state['recommendation'],
      );
      expect((await r.progress()).completed, beforePlacement.completed);
      expect(app.inventory.grants.length, beforeGrants);
      await capture('recommended-lesson-$lang');
      if (lang == 'en' || lang == 'zh') await marker('VIDEO_DONE:$lang');
      await r.chooseCourseStart(r.catalog.first.id);
      await app.refresh();

      final pictures = PictureRepository(r);
      final cards = await pictures.cards;
      final scene = (await Conversation.load()).firstWhere(
        (c) => c.language == lang,
      );
      final completed = {cards['book']!.prerequisite!, scene.prerequisite};
      for (final lesson in completed) {
        clock = DateTime(today.year, today.month, today.day - 1, 12);
        await r.append(
          r.event('complete', {'lesson': lesson, 'session': 'demo:$lesson'}),
        );
      }
      clock = today;
      await app.refresh();
      final xp = app.progress.xp;
      final selected = cards[((await pictures.open())['ids'] as List).first]!;
      await go('/pictures');
      await capture('picture-$lang');
      expect(find.text(selected.forms.first), findsNothing);
      final input = find.byKey(const Key('picture-input'));
      await show(input);
      await tester.enterText(
        input,
        selected.pinyin.firstOrNull ?? selected.bare(selected.forms.first),
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tap(find.byKey(const Key('picture-next')));
      await show(find.text(selected.forms.join(' / ')));
      await capture('picture-answer-$lang');
      expect(app.progress.xp, xp);
      if (lang == 'zh') {
        await tap(find.text('Послушать'));
        expect(find.textContaining('Голос недоступен'), findsOneWidget);
        await capture('picture-no-voice-zh');
      }

      final (lessonId, exerciseId) = switch (lang) {
        'en' => ('en-a1-61', 'en-a1-61-e06'),
        'es' => ('es-a1-07', 'es-a1-07-e06'),
        'de' => ('de-a1-08', 'de-a1-08-e06'),
        'fr' => ('fr-a1-14', 'fr-a1-14-e05'),
        _ => ('zh-a1-17', 'zh-a1-17-e06'),
      };
      final previous =
          r.catalog[r.catalog.indexWhere((info) => info.id == lessonId) - 1];
      if (!app.progress.completed.contains(previous.id)) {
        await r.append(
          r.event('complete', {
            'lesson': previous.id,
            'session': 'demo:${previous.id}',
          }),
        );
      }
      final run = await r.startLesson(lessonId);
      await r.markTeachingSeen(run.session.id);
      final step = run.lesson.exercises.indexWhere((e) => e.id == exerciseId);
      for (var i = 0; i < step; i++) {
        final e = run.lesson.exercises[i];
        await r.answer(
          run.session.id,
          i,
          e,
          e.answers.first,
          total: run.lesson.exercises.length,
        );
      }
      await app.refresh();
      await go('/lesson/$lessonId');
      final checkpoint = find.byKey(const Key('checkpoint-continue'));
      if (checkpoint.evaluate().isNotEmpty) await tap(checkpoint);
      final e = run.lesson.exercises[step];
      final wrong = e.options.firstWhere((o) => !checkAnswer(e, o));
      await tap(find.text(wrong));
      await tap(find.text('Проверить'));
      expect(find.text(mistakeExplanation(e, wrong)), findsOneWidget);
      await capture('feedback-$lang');

      final beforeConversation = app.progress.xp,
          grants = app.inventory.grants.length;
      await go('/conversation/${scene.id}');
      final path = scene.paths[1];
      Finder choice(String text) => find.ancestor(
        of: find.textContaining(text),
        matching: find.byType(OutlinedButton),
      );
      await tap(choice(path.request.text));
      await capture('branch-$lang');
      expect(find.text(path.reply.text), findsOneWidget);
      await tap(choice(scene.paths[0].confirmation.text));
      expect(find.textContaining('Мико уточняет'), findsOneWidget);
      await capture('branch-retry-$lang');
      await tap(choice(path.confirmation.text));
      await tap(choice(path.farewell.text));
      expect(find.text('Разговор завершён'), findsOneWidget);
      await capture('conversation-done-$lang');
      expect(app.progress.xp, beforeConversation);
      expect(app.inventory.grants.length, grants);
      await go('/stats');
      await show(find.text('30 дней занятий'));
      await capture('calendar-$lang');
    }
    await marker('DONE');
    await tester.pumpWidget(const SizedBox.shrink());
    await r.db.close();
  });
}
