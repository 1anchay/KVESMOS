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
import 'package:orbitwords/ui/pages.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'package:go_router/go_router.dart';

Future<void> marker(String value) async {
  await Process.run('/system/bin/log', ['-t', 'KVESMOS_QA', value]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'five native courses, onboarding decisions, local voices, chest handoff and themes',
    (tester) async {
      final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
      final app = AppController(repo);
      await app.initialize();
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

      final router = GoRouter.of(tester.element(find.byType(OnboardingPage)));
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        await marker('V012_CAPTURE:$name');
        await Future<void>.delayed(const Duration(seconds: 2));
      }

      for (var step = 0; step < 4; step++) {
        await tap(find.widgetWithText(FilledButton, 'Продолжить'));
      }
      await capture('onboarding-reminders');
      await marker('V012_PERMISSION_DENY');
      await tap(find.widgetWithText(FilledButton, 'Включить напоминания'));
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(app.companion.preferences.enabled, isFalse);
      await capture('onboarding-denied');
      await tap(find.widgetWithText(TextButton, 'Продолжить'));
      await capture('onboarding-widget');
      await marker('V012_PIN_WIDGET');
      await tap(find.widgetWithText(FilledButton, 'Добавить виджет'));
      await Future<void>.delayed(const Duration(seconds: 12));
      await tester.pumpAndSettle();
      await tap(find.widgetWithText(TextButton, 'Продолжить'));
      expect(app.onboarded, isTrue);
      router.go('/settings');
      await tester.pumpAndSettle();
      await marker('V012_PERMISSION_ALLOW');
      await tap(find.byKey(const Key('reminders-enabled')));
      await Future<void>.delayed(const Duration(seconds: 8));
      await tester.pumpAndSettle();
      expect(app.companion.preferences.enabled, isTrue);
      await capture('reminders-enabled');
      await marker('V012_CYCLE_START');
      for (final language in ['en', 'es', 'de', 'fr', 'zh']) {
        if (language == 'es') await marker('V012_ES_START');
        router.go('/courses');
        await tester.pumpAndSettle();
        await tap(find.byKey(ValueKey('course-ru-$language')));
        expect(app.course.language, language);
        expect(app.progress.xp, 0);
        await tap(find.byKey(const Key('today-start')));
        await capture('teaching-$language');
        await tap(find.text('Послушать пример'));
        if (['en', 'es', 'de'].contains(language)) {
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
        await capture('lesson-$language');
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
        await marker('V012_WIDGET_${language.toUpperCase()}');
        await Future<void>.delayed(const Duration(seconds: 7));
        await tester.pumpAndSettle();
        if (language == 'es') await marker('V012_ES_DONE');
      }
      await app.selectCourse('ru-en');
      expect(app.progress.xp, 120);
      expect(app.globalProgress.xp, 600);
      final grants = app.inventory.grants.length;
      await app.selectCourse('ru-es');
      await app.selectCourse('ru-de');
      await app.selectCourse('ru-en');
      expect(app.inventory.grants.length, grants);
      await marker('V012_CHEST_START');
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
      await marker('V012_CHEST_DONE');
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await app.savePreferences(newTheme: theme);
        for (final route in [
          '/',
          '/map',
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
        await marker('V012_WIDGET_${theme.name.toUpperCase()}');
        await Future<void>.delayed(const Duration(seconds: 7));
      }
      expect(tester.takeException(), isNull);
      await marker('V012_CYCLE_DONE');
      await tester.pumpWidget(const SizedBox.shrink());
      await repo.db.close();
    },
  );
}
