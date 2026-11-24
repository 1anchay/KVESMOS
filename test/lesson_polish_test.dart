import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'package:orbitwords/ui/lesson_effects.dart';
import 'package:orbitwords/ui/design.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  testWidgets('checked word order stays fixed until the next question', (
    tester,
  ) async {
    final r = memoryRepository();
    final app = AppController(r);
    await tester.runAsync(() async {
      await app.initialize();
      final material = await r.startLesson('a1-01');
      for (var i = 0; i < 2; i++) {
        final exercise = material.lesson.exercises[i];
        await r.answer(
          material.session.id,
          i,
          exercise,
          exercise.answers.first,
          total: material.lesson.exercises.length,
        );
      }
      await app.refresh();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: MaterialApp(home: const LessonScreen(lessonId: 'a1-01')),
      ),
    );
    await flushDb(tester);
    final material = (await tester.runAsync(() => r.previewLesson('a1-01')))!;
    final exercise = material.lesson.exercises[2];
    expect(exercise.type, ExerciseType.order);
    for (final token in exercise.tokens) {
      final chip = find
          .byWidgetPredicate(
            (widget) =>
                widget is ActionChip &&
                widget.onPressed != null &&
                widget.label is Text &&
                (widget.label as Text).data == token,
          )
          .first;
      await tester.scrollUntilVisible(chip, 150);
      await tester.tap(chip);
      await flushDb(tester);
    }
    await tester.tap(find.text('Проверить'));
    await flushDb(tester);
    expect(find.text('Есть контакт! +10 XP'), findsOneWidget);
    expect(
      tester
          .widgetList<InputChip>(find.byType(InputChip))
          .every((chip) => chip.onDeleted == null),
      isTrue,
    );
    expect(find.byType(InputChip), findsNothing);
    expect(find.byType(Chip), findsNWidgets(exercise.tokens.length));
    expect(
      tester
          .widgetList<ActionChip>(find.byType(ActionChip))
          .every((chip) => chip.onPressed == null),
      isTrue,
    );
    expect(app.progress.xp, 30);
    await tester.tap(find.text('Дальше'));
    await flushDb(tester);
    expect(app.progress.xp, 30);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(r.db.close);
  });
  testWidgets(
    'wrong answer supports retry; saved success animates XP and advances exactly once',
    (tester) async {
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(app.initialize);
      final lesson = (await tester.runAsync(
        () => r.startLesson('a1-01'),
      ))!.lesson;
      final first = lesson.exercises.first;
      final wrong = first.options.firstWhere((v) => !checkAnswer(first, v));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: orbitTheme(Brightness.light),
            home: const LessonScreen(lessonId: 'a1-01'),
          ),
        ),
      );
      await flushDb(tester);
      await advanceTeaching(tester);
      await flushDb(tester);
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, wrong),
        220,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, wrong));
      await flushDb(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить'));
      await flushDb(tester);
      expect(app.progress.xp, 0);
      expect(app.progress.errors, 1);
      expect(find.text('Почти! Я помогу.'), findsOneWidget);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Попробовать снова'));
      await flushDb(tester);
      await tester.scrollUntilVisible(
        find.widgetWithText(OutlinedButton, first.answers.first),
        -250,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(OutlinedButton, first.answers.first),
      );
      await flushDb(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить'));
      await flushDb(tester);
      expect(app.progress.xp, 10);
      await tester.pumpAndSettle();
      expect(
        tester.widget<LessonProgress>(find.byType(LessonProgress)).done,
        1,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дальше'));
      await flushDb(tester);
      expect(find.text(lesson.exercises[1].prompt), findsOneWidget);
      expect(find.byType(QuestionEntrance), findsNWidgets(2));
      expect(app.progress.xp, 10);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  testWidgets(
    'completion reports session XP and all-attempt accuracy; large text and reduced motion fit',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository();
      final app = AppController(r);
      late String lastAnswer;
      late bool lastHasOptions;
      await tester.runAsync(() async {
        await app.initialize();
        final lesson = await r.lesson('a1-01');
        final session = await r.start(lesson.id);
        await r.answer(
          session.id,
          0,
          lesson.exercises.first,
          'wrong',
          total: lesson.exercises.length,
        );
        for (var i = 0; i < lesson.exercises.length - 1; i++) {
          await r.answer(
            session.id,
            i,
            lesson.exercises[i],
            lesson.exercises[i].answers.first,
            total: lesson.exercises.length,
          );
        }
        lastAnswer = lesson.exercises.last.answers.first;
        lastHasOptions = lesson.exercises.last.options.isNotEmpty;
        await app.refresh();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: orbitTheme(Brightness.dark),
            home: MediaQuery(
              data: const MediaQueryData(
                disableAnimations: true,
                size: Size(320, 720),
                textScaler: TextScaler.linear(2),
              ),
              child: const LessonScreen(lessonId: 'a1-01'),
            ),
          ),
        ),
      );
      await flushDb(tester);
      final option = find.widgetWithText(OutlinedButton, lastAnswer);
      if (lastHasOptions) {
        await tester.scrollUntilVisible(option, 200);
        await tester.pumpAndSettle();
        await tester.tap(option);
      } else {
        await tester.scrollUntilVisible(find.byType(TextField), 200);
        await tester.enterText(find.byType(TextField), lastAnswer);
      }
      await flushDb(tester);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Проверить'));
      await flushDb(tester);
      expect(app.progress.xp, 120);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Дальше'));
      await flushDb(tester);
      final next = find.byKey(const Key('completion-next'));
      expect(next.hitTestable(), findsOneWidget);
      expect(
        find.descendant(of: next, matching: find.text('Начать урок')),
        findsOneWidget,
      );
      expect(find.text('Открыть находки').hitTestable(), findsOneWidget);
      await tester.scrollUntilVisible(find.text('+120 XP'), 250);
      await tester.pumpAndSettle();
      expect(find.text('+120 XP'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('91%'), 250);
      await tester.pumpAndSettle();
      expect(find.text('91%'), findsOneWidget);
      expect(app.progress.xp, 120);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
