import '../test/support.dart';
import 'package:orbitwords/data/mastery_repository.dart';
import 'package:orbitwords/domain/learning_unit.dart';
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
import 'package:orbitwords/data/practice_repository.dart';
import 'package:go_router/go_router.dart';

Future<void> marker(String value) async {
  await Process.run('/system/bin/log', ['-t', 'KVESMOS_QA', value]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'five extended courses, six practices, local voices, rewards and themes',
    (tester) async {
      final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
      final app = AppController(repo);
      await app.initialize();
      await app.finishOnboarding();
      await app.savePreferences(newTheme: ThemeMode.light);
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
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: name);
        await marker('V015_CAPTURE:$name');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      const practiceOnly = bool.fromEnvironment('KVESMOS_QA_PRACTICE_ONLY');

      for (final language in ['en', 'es', 'de', 'fr', 'zh']) {
        if (language == 'es') await marker('V015_ES_START');
        if (!practiceOnly && ['fr', 'zh'].contains(language)) {
          await marker('V015_${language.toUpperCase()}_CYCLE_START');
        }
        router.go('/courses');
        await tester.pumpAndSettle();
        await tap(find.byKey(ValueKey('course-ru-$language')));
        expect(app.course.language, language);
        final prior = language == 'en'
            ? 60
            : (language == 'es' || language == 'de' ? 30 : 20);
        for (final info in repo.catalog.take(prior)) {
          await repo.append(
            repo.event('complete', {
              'lesson': info.id,
              'session': 'seed:${info.id}',
            }),
          );
        }
        await app.refresh();
        if (practiceOnly) {
          final run = await repo.startLesson('$language-a1-${prior + 1}');
          for (var i = 0; i < run.lesson.exercises.length; i++) {
            final e = run.lesson.exercises[i];
            await repo.answer(
              run.session.id,
              i,
              e,
              e.answers.first,
              total: run.lesson.exercises.length,
            );
          }
          await app.refresh();
          continue;
        }
        router.go('/map');
        await capture('units-$language');
        router.go('/');
        await tester.pumpAndSettle();
        await tap(find.byKey(const Key('today-start')));
        await capture('teaching-$language');
        await tap(find.byTooltip('Послушать пример'));
        if (['en', 'es', 'de', 'fr'].contains(language)) {
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
        final intro = (await repo.startLesson(
          '$language-a1-${prior + 1}',
        )).lesson.guidedIntroduction.first;
        await tap(find.byKey(const Key('intro-option-0')));
        await tap(find.byKey(const Key('teaching-next')));
        await capture('intro-mistake-$language');
        await tap(find.byTooltip('Закрыть и сохранить'));
        await tap(find.byKey(const Key('today-start')));
        await tester.pumpAndSettle();
        expect(find.textContaining('Пока не совпало'), findsOneWidget);
        await tap(find.byKey(const Key('intro-reveal')));
        expect(find.text(intro.translation), findsWidgets);
        await advanceTeaching(tester);
        await capture('lesson-$language');
        final material = await repo.startLesson('$language-a1-${prior + 1}');
        for (final e in material.lesson.exercises) {
          if (e.recall != null) {
            await capture('recall-$language');
            await tap(find.byKey(const Key('recall-hide')));
          }
          if (e.options.isNotEmpty) {
            await tap(find.widgetWithText(OutlinedButton, e.answers.first));
          } else if (e.type == ExerciseType.order) {
            for (final token in e.tokens) {
              await tap(
                find
                    .byWidgetPredicate(
                      (w) =>
                          w is ActionChip &&
                          w.onPressed != null &&
                          w.label is Text &&
                          (w.label as Text).data == token,
                    )
                    .first,
              );
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
        expect(
          app.progress.xp,
          material.lesson.exercises.length * 10 + 20 + prior * 20,
        );
        expect(app.progress.streak(repo.now()), 1);
        expect(tester.takeException(), isNull);
        // Finish the paired topic, then verify optional mastery through UI.
        final unit = LearningUnit.fromCatalog(
          repo.catalog,
        ).firstWhere((u) => u.lessons.any((l) => l.id == material.lesson.id));
        for (final info in unit.lessons) {
          if ((await repo.progress()).completed.contains(info.id)) continue;
          final run = await repo.startLesson(info.id);
          for (var i = 0; i < run.lesson.exercises.length; i++) {
            final e = run.lesson.exercises[i];
            await repo.answer(
              run.session.id,
              i,
              e,
              e.answers.first,
              total: run.lesson.exercises.length,
            );
          }
        }
        await app.refresh();
        final mastery = MasteryRepository(repo, unit);
        final masteryXp = app.progress.xp;
        final masteryGrants = app.inventory.grants.length;
        router.go('/mastery/${Uri.encodeComponent(unit.id)}');
        await tester.pumpAndSettle();
        await capture('mastery-start-$language');
        var challenge = await mastery.open();
        while (challenge['done'] != true) {
          final item = (challenge['items'] as List)[challenge['index']];
          await tester.scrollUntilVisible(
            find.byKey(const Key('mastery-input')),
            180,
            maxScrolls: 35,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(
            find.byKey(const Key('mastery-input')),
            item['pronunciation'] ?? item['phrase'],
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tap(find.byKey(const Key('mastery-next')));
          await tap(find.byKey(const Key('mastery-next')));
          challenge = await mastery.open();
        }
        expect(await mastery.earned(), true);
        expect(app.progress.xp, masteryXp);
        expect(app.inventory.grants.length, masteryGrants);
        await capture('mastery-stamp-$language');
        router.go('/');
        await tester.pumpAndSettle();
        await marker('V015_WIDGET_${language.toUpperCase()}');
        await Future<void>.delayed(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        if (language == 'es') await marker('V015_ES_DONE');
        if (['fr', 'zh'].contains(language)) {
          await marker('V015_${language.toUpperCase()}_CYCLE_DONE');
        }
      }
      await app.selectCourse('ru-en');
      expect(app.progress.xp, greaterThanOrEqualTo(1310));
      expect(app.globalProgress.completed.length, greaterThanOrEqualTo(165));
      final grants = app.inventory.grants.length;
      await app.selectCourse('ru-es');
      await app.selectCourse('ru-de');
      await app.selectCourse('ru-en');
      expect(app.inventory.grants.length, grants);
      await app.selectCourse('ru-fr');
      final known = (await repo.lesson('fr-a1-07')).vocabulary.first;
      await repo.review(known, 'wrong');
      await app.refresh();
      for (final mode in PracticeMode.values) {
        final p = PracticeRepository(repo, mode: mode);
        final state = await p.open();
        expect(state['words'], isNotEmpty, reason: mode.name);
        final word = repo.vocabulary[(state['words'] as List).first]!;
        router.go('/practice/${mode.name}');
        await capture('practice-${mode.name}');
        await tap(find.byKey(const Key('practice-next')));
        await tester.ensureVisible(find.byKey(const Key('practice-input')));
        await tester.enterText(
          find.byKey(const Key('practice-input')),
          word.en,
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tap(find.byKey(const Key('practice-next')));
        expect((await p.open())['correct'], true);
      }
      await app.selectCourse('ru-en');
      await marker('V015_CHEST_START');
      router.go('/rewards');
      await capture('chest-list-before');
      final grant = app.inventory.pending.first;
      router.push('/chest/${Uri.encodeComponent(grant.id)}');
      await capture('chest-before');
      await tap(find.widgetWithText(FilledButton, 'Открыть'));
      await capture('chest-reveal');
      expect(app.inventory.pending.any((g) => g.id == grant.id), isFalse);
      final item = app.rewards.catalog.item(
        app.inventory.grants[grant.id]!.itemId!,
      );
      await tap(find.text('Примерить находку'));
      await capture('chest-try-on');
      await tap(find.byKey(const ValueKey('apply-cosmetic')));
      expect(app.inventory.equipped[item.slot], item.id);
      router.go('/rewards');
      await capture('chest-list-after');
      expect((await app.rewards.openOnce(grant.id)).fresh, isFalse);
      await marker('V015_CHEST_DONE');
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await app.savePreferences(newTheme: theme);
        for (final route in [
          '/',
          '/map',
          '/training',
          '/profile',
          '/inventory',
          '/rewards',
          '/achievements',
          '/stats',
          '/courses',
          '/settings',
          '/companion/reminders',
          '/companion/widget',
        ]) {
          router.go(route);
          await capture(
            '${theme.name}-${route == '/' ? 'today' : route.substring(1).replaceAll('/', '-')}',
          );
        }
        router.go('/profile');
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.text('Изучаю языков: 5'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await capture('${theme.name}-passport-five');
        for (final lang in ['fr', 'zh']) {
          await app.selectCourse('ru-$lang');
          router.go('/lesson/$lang-a1-02');
          await capture('${theme.name}-lesson-$lang');
        }
        router.go('/chest/${Uri.encodeComponent(grant.id)}');
        await capture('${theme.name}-chest-saved');
        router.go('/');
        await tester.pumpAndSettle();
        await marker('V015_WIDGET_${theme.name.toUpperCase()}');
        await Future<void>.delayed(const Duration(seconds: 7));
      }
      expect(tester.takeException(), isNull);
      await marker('V015_CYCLE_DONE');
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.db.close();
    },
  );
}
