import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'package:orbitwords/ui/design.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  test(
    'three authored pilots validate and complete through the existing checker with unchanged XP',
    () async {
      final r = memoryRepository();
      await r.initialize();
      for (final id in ['a1-01', 'a1-02', 'a1-03']) {
        final result = await r.startLesson(id);
        final l = result.lesson;
        expect(l.exercises, hasLength(10));
        expect(
          l.exercises.map((e) => e.type).toSet().length,
          greaterThanOrEqualTo(7),
        );
        expect(l.exercises.map((e) => e.phase).toSet(), {
          'Знакомство',
          'Понимание',
          'Практика',
          'Закрепление',
        });
        expect(l.exercises.map((e) => e.id).toSet(), hasLength(10));
        final profiles = CharacterVoiceProfile.all.map((p) => p.id).toSet();
        for (var i = 0; i < l.exercises.length; i++) {
          final e = l.exercises[i];
          expect(profiles, contains(e.character));
          expect(e.explanation, isNotEmpty);
          expect(e.wordIds.every(r.vocabulary.containsKey), true);
          if (e.options.isNotEmpty) {
            expect(e.options.any((o) => checkAnswer(e, o)), true);
            expect(e.options.any((o) => !checkAnswer(e, o)), true);
          }
          if (e.tokens.isNotEmpty) {
            expect(checkAnswer(e, e.tokens.join(' ')), true);
          }
          expect(
            await r.answer(result.session.id, i, e, e.answers.first, total: 10),
            true,
          );
        }
        expect((await r.session(result.session.id)).done, true);
      }
      final p = await r.progress();
      expect(p.xp, 360);
      expect(p.completed, {'a1-01', 'a1-02', 'a1-03'});
      expect(p.correct, 30);
      await r.db.close();
    },
  );
  test(
    'old draft stays unchanged; demo snapshot resumes through the normal route and survives asset updates',
    () async {
      final r = memoryRepository();
      await r.initialize();
      final old = await r.start('a1-01');
      await r.draft(old.id, 0, '{"text":"черновик"}');
      final original = await r.lesson('a1-01');
      final resumed = await r.startLesson('a1-01', demo: true);
      expect(resumed.session.id, old.id);
      expect(resumed.session.draft, '{"text":"черновик"}');
      expect(resumed.lesson.exercises.first.id, original.exercises.first.id);
      final pilot = await r.startLesson('a1-02', demo: true);
      await r.draft(pilot.session.id, 0, '{"text":"friend"}');
      final changed = jsonDecode(
        await File('assets/courses/a1-02.json').readAsString(),
      );
      changed['exercises'][0]['prompt'] = 'Updated installed course';
      await r.installRaw('a1-02', jsonEncode(changed));
      final resumedPilot = await r.startLesson('a1-02');
      expect(
        resumedPilot.lesson.exercises.first.id,
        pilot.lesson.exercises.first.id,
      );
      expect(resumedPilot.session.draft, '{"text":"friend"}');
      expect(
        resumedPilot.lesson.exercises.first.prompt,
        pilot.lesson.exercises.first.prompt,
      );
      expect((await r.lesson('a1-02')).exercises.first.id, 'a1-02-e01');
      expect((await r.progress()).xp, 0);
      await r.db.close();
    },
  );
  test(
    'switching an old lesson preserves XP, events and draft; retry reuses the new session',
    () async {
      final r = memoryRepository();
      await r.initialize();
      final old = await r.start('a1-01');
      final material = await r.lesson('a1-01');
      await r.answer(
        old.id,
        0,
        material.exercises.first,
        material.exercises.first.answers.first,
        total: 10,
      );
      await r.draft(old.id, 1, '{"text":"Anna"}');
      final before = await r.session(old.id);
      final events = (await r.allEvents()).map((e) => e.toJson()).toList();
      final updated = await r.restartUpdated('a1-01', old.id);
      final again = await r.restartUpdated('a1-01', old.id);
      expect(again.session.id, updated.session.id);
      expect(updated.lesson.exercises.first.phase, 'Знакомство');
      expect(updated.session.position, 0);
      expect((await r.startLesson('a1-01')).session.id, updated.session.id);
      expect((await r.session(old.id)).toJson(), before.toJson());
      expect((await r.allEvents()).map((e) => e.toJson()).toList(), events);
      expect((await r.progress()).xp, 10);
      await r.db.close();
    },
  );
  testWidgets(
    'old session can switch from its screen without losing earned XP',
    (tester) async {
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        final old = await r.start('a1-01');
        final l = await r.lesson('a1-01');
        await r.answer(
          old.id,
          0,
          l.exercises.first,
          l.exercises.first.answers.first,
          total: 10,
        );
        await app.refresh();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(home: const LessonScreen(lessonId: 'a1-01')),
        ),
      );
      await flushDb(tester);
      await tester.scrollUntilVisible(
        find.text('Начать обновлённый урок'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Начать обновлённый урок'));
      await flushDb(tester);
      expect(find.text('Новый формат'), findsOneWidget);
      expect(
        find.text('Орби встречает тебя на космической станции. Что ему ответить?'),
        findsOneWidget,
      );
      expect(app.progress.xp, 10);
      expect(app.progress.correct, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  testWidgets(
    'all three pilots complete with audio disabled through real controls',
    (tester) async {
      for (var number = 1; number <= 3; number++) {
        final r = memoryRepository();
        final app = AppController(r);
        final id = 'a1-0$number';
        late Lesson l;
        await tester.runAsync(() async {
          await app.initialize();
          await app.saveAudio(
            const AudioPreferences(
              speech: false,
              effects: false,
              reactions: false,
            ),
          );
          for (var previous = 1; previous < number; previous++) {
            await r.append(
              r.event('complete', {
                'lesson': 'a1-0$previous',
                'session': 'seed$previous',
              }),
            );
          }
          await app.refresh();
          l = Lesson.fromJson(
            jsonDecode(
              await File('assets/courses/demo/$id.json').readAsString(),
            ),
          );
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              theme: orbitTheme(Brightness.light),
              home: LessonScreen(lessonId: id, demo: true),
            ),
          ),
        );
        // File-backed pilot material and the transaction finish on separate
        // event-loop turns; do not spin a loading indicator in fake time.
        for (
          var wait = 0;
          wait < 10 &&
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty;
          wait++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 80)),
          );
          await tester.pump(const Duration(milliseconds: 250));
        }
        await tester.pumpAndSettle();
        if (l.teachingSteps.isNotEmpty) {
          for (var page = 0; page < l.teachingSteps.length - 1; page++) {
            expect(find.text('Понятно, дальше'), findsOneWidget);
            await tester.tap(find.text('Понятно, дальше'));
            await tester.pumpAndSettle();
          }
          await tester.tap(find.text('Начать практику'));
          await flushDb(tester);
        }
        Future<void> top() async {
          final list = tester.state<ScrollableState>(
            find.byType(Scrollable).first,
          );
          list.position.jumpTo(0);
          await tester.pumpAndSettle();
        }

        Future<void> tap(Finder target) async {
          await top();
          await tester.scrollUntilVisible(
            target,
            230,
            maxScrolls: 35,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.tap(target);
          await flushDb(tester);
        }

        for (final e in l.exercises) {
          if (e.audio != null) {
            await tap(find.widgetWithText(OutlinedButton, 'Прослушать'));
            await top();
            final transcript = find.descendant(
              of: find.byType(Card),
              matching: find.text(e.audio!),
            );
            await tester.scrollUntilVisible(
              transcript,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(transcript, findsOneWidget);
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
            await top();
            await tester.scrollUntilVisible(
              find.byType(TextField),
              230,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            await tester.enterText(find.byType(TextField), e.answers.first);
            await flushDb(tester);
          }
          await tap(find.text('Проверить'));
          expect(app.progress.errors, 0, reason: e.id);
          await tap(find.text('Дальше'));
        }
        expect(app.progress.completed, contains(id));
        expect(app.progress.xp, 120 + (number - 1) * 20);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      }
    },
  );
  testWidgets(
    'picture, audio choices and conversation cards fit 320px with 200% text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final brightness in Brightness.values) {
        for (final config in [('a1-03', 0), ('a1-01', 2), ('a1-02', 7)]) {
          final r = memoryRepository();
          final app = AppController(r);
          await tester.runAsync(() async {
            await app.initialize();
            for (var n = 1; n < 3; n++) {
              await r.append(
                r.event('complete', {'lesson': 'a1-0$n', 'session': 'seed$n'}),
              );
            }
            await app.refresh();
            final result = await r.startLesson(config.$1, demo: true);
            for (var i = 0; i < config.$2; i++) {
              final e = result.lesson.exercises[i];
              await r.answer(
                result.session.id,
                i,
                e,
                e.answers.first,
                total: 10,
              );
            }
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appProvider.overrideWith((_) => app)],
              child: MaterialApp(
                theme: orbitTheme(brightness),
                home: MediaQuery(
                  data: const MediaQueryData(
                    textScaler: TextScaler.linear(2),
                    disableAnimations: true,
                  ),
                  child: LessonScreen(lessonId: config.$1),
                ),
              ),
            ),
          );
          await flushDb(tester);
          await tester.scrollUntilVisible(
            find.text('Проверить'),
            230,
            maxScrolls: 35,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$brightness $config');
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(r.db.close);
        }
      }
    },
  );
}
