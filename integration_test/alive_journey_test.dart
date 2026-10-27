// Disposable QA emulator ONLY. Flutter's runner may clear its target package.
// Back up the QA app before running; restore the production APK and backup after.
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('first minute, real lesson, daily rewards and next step', (
    tester,
  ) async {
    // Isolated fixture; never clear or modify the installed user's database.
    final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(repo);
    await app.initialize();
    expect(
      app.progress.xp,
      0,
      reason: 'Use a disposable fresh QA emulator only',
    );
    await app.saveAudio(
      const AudioPreferences(speech: false, effects: true, reactions: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    debugPrint('ALIVE_RECORD_START');
    await Future<void>.delayed(const Duration(seconds: 1));
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

    for (var i = 0; i < 3; i++) {
      await tap(find.text('Продолжить'));
    }
    await tap(find.text('Начать путешествие'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await tap(find.byKey(const Key('today-start')));
    for (
      var i = 0;
      i < 10 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
      i++
    ) {
      await tap(find.byKey(const Key('teaching-next')));
    }
    final material = await repo.startLesson('a1-01');
    for (final e in material.lesson.exercises) {
      debugPrint('ALIVE_STEP ${e.id}');
      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      list.position.jumpTo(0);
      await tester.pumpAndSettle();
      if (e == material.lesson.exercises.first) {
        await tap(
          find.widgetWithText(
            OutlinedButton,
            e.options.firstWhere((v) => !e.answers.contains(v)),
          ),
        );
        await tap(find.text('Проверить'));
        expect(find.text('Почти! Я помогу.'), findsOneWidget);
        await Future<void>.delayed(const Duration(seconds: 1));
        await tap(find.text('Попробовать снова'));
      }
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
      if (find.byKey(const Key('checkpoint-continue')).evaluate().isNotEmpty) {
        await tap(find.byKey(const Key('checkpoint-continue')));
      }
    }
    expect(app.progress.xp, 120);
    expect(app.progress.errors, 1);
    expect(app.inventory.grants.length, 3);
    expect(find.text('Ещё одно открытие!'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 2));
    await tap(find.text('Открыть находки'));
    await tap(find.text('Открыть сундук').first);
    await tap(find.text('Открыть').first);
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    debugPrint('ALIVE_RECORD_DONE');
    await app.refresh();
    final count = app.inventory.grants.length;
    await app.refresh();
    expect(app.inventory.grants.length, count);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.db.close();
  });
}
