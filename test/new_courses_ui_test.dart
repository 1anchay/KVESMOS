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

import 'package:orbitwords/domain/languages.dart';

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'all 20 new lessons complete through UI with language-specific fallback',
    (tester) async {
      for (final id in [
        for (var n = 21; n <= 28; n++) 'en-a1-$n',
        for (final lang in ['es', 'de'])
          for (var n = 1; n <= 6; n++)
            '$lang-a1-${n.toString().padLeft(2, '0')}',
      ]) {
        final number = int.parse(id.split('-').last);
        final r = memoryRepository();
        final app = AppController(r);
        late Lesson l;
        await tester.runAsync(() async {
          await app.initialize();
          await app.selectCourse(StudyCourse.forContent(id).id);
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
                'lesson': r.catalog[previous - 1].id,
                'session': 'seed$previous',
              }),
            );
          }
          await app.refresh();
          l = Lesson.fromJson(
            jsonDecode(await File('assets/courses/$id.json').readAsString()),
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
        await advanceTeaching(tester);
        await flushDb(tester);
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
          // SQLite runs on the real event loop; scrolling in fake time must
          // not race an in-flight answer transaction on a busy CI runner.
          for (
            var wait = 0;
            wait < 40 && find.text('Сохраняем…').evaluate().isNotEmpty;
            wait++
          ) {
            await flushDb(tester);
          }
          expect(find.text('Сохраняем…'), findsNothing);
        }

        for (final e in l.exercises) {
          if (e.audio != null) {
            await tap(find.widgetWithText(OutlinedButton, 'Прослушать'));
            await top();
            final transcript = find.byKey(const Key('audio-transcript'));
            await tester.scrollUntilVisible(
              transcript,
              200,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.pumpAndSettle();
            expect(transcript, findsOneWidget);
            expect(tester.widget<Text>(transcript).data, e.audio!);
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
          if (find
              .byKey(const Key('checkpoint-continue'))
              .evaluate()
              .isNotEmpty) {
            await tap(find.byKey(const Key('checkpoint-continue')));
          }
        }
        expect(app.progress.completed, contains(id));
        expect(app.progress.xp, 120 + (number - 1) * 20);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      }
    },
  );
}
