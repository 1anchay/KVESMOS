import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'package:orbitwords/ui/personal_practice.dart';
import 'package:orbitwords/ui/expeditions_page.dart';
import 'package:orbitwords/ui/design.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'five answered tasks resume at a saved checkpoint, not a new session',
    (tester) async {
      final repo = memoryRepository();
      final app = AppController(repo);
      await tester.runAsync(() async {
        await app.initialize();
        await app.saveAudio(
          const AudioPreferences(
            speech: false,
            effects: false,
            reactions: false,
          ),
        );
        final l = await repo.startLesson('a1-01');
        await repo.markTeachingSeen(l.session.id);
        for (var n = 0; n < 5; n++) {
          await repo.answer(
            l.session.id,
            n,
            l.lesson.exercises[n],
            l.lesson.exercises[n].answers.first,
            total: 10,
          );
        }
        await app.refresh();
      });
      final session = (await tester.runAsync(
        () => repo.startLesson('a1-01'),
      ))!.session.id;
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
      expect(find.text('Первый этап пройден!'), findsOneWidget);
      expect(app.progress.xp, 50);
      await tester.ensureVisible(find.byKey(const Key('checkpoint-continue')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('checkpoint-continue')));
      await flushDb(tester);
      expect(find.text('Первый этап пройден!'), findsNothing);
      final resumed = (await tester.runAsync(() => repo.startLesson('a1-01')))!;
      expect(resumed.session.id, session);
      expect(resumed.session.position, 5);
      expect(app.progress.xp, 50);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.db.close);
    },
  );
  testWidgets(
    'personal word practice teaches, hides, explains a mistake and accepts independent recall',
    (tester) async {
      final repo = memoryRepository();
      final app = AppController(repo);
      await tester.runAsync(() async {
        await app.initialize();
        await app.saveAudio(
          const AudioPreferences(
            speech: false,
            effects: false,
            reactions: false,
          ),
        );
        await repo.review(repo.vocabulary.values.first, 'wrong');
        await app.refresh();
      });
      final word = repo.vocabulary.values.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: orbitTheme(Brightness.light),
            home: const Scaffold(body: PersonalPracticePage()),
          ),
        ),
      );
      await flushDb(tester);
      Future<void> next() async {
        await tester.ensureVisible(find.byKey(const Key('practice-next')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('practice-next')));
        await flushDb(tester);
      }

      expect(find.text(word.en), findsOneWidget);
      await next();
      expect(find.text(word.en), findsNothing);
      await tester.enterText(find.byKey(const Key('practice-input')), 'wrong');
      await next();
      expect(find.text('Разберём и попробуем'), findsOneWidget);
      await next();
      await tester.enterText(find.byKey(const Key('practice-input')), word.en);
      await next();
      expect(find.text('Получилось!'), findsOneWidget);
      expect(app.progress.xp, 10);
      await next();
      expect(find.text('Слова снова на связи!'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.db.close);
    },
  );
  testWidgets(
    'checkpoint practice and passport render in both themes at 390 and 320px 200%',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.runAsync(() async {
        await loadPreviewFonts();
        if (Platform.environment['CAPTURE_UI'] == '1') {
          await Directory('test-output/v07').create(recursive: true);
        }
      });
      for (final small in [false, true]) {
        for (final brightness in Brightness.values) {
          for (final page in ['checkpoint', 'practice', 'passport']) {
            tester.view.physicalSize = Size(small ? 320 : 390, 844);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
            final repo = memoryRepository();
            final app = AppController(repo);
            final key = GlobalKey();
            await tester.runAsync(() async {
              await app.initialize();
              await app.saveAudio(
                const AudioPreferences(
                  speech: false,
                  effects: false,
                  reactions: false,
                ),
              );
              final material = await repo.startLesson('a1-01');
              await repo.markTeachingSeen(material.session.id);
              for (var n = 0; n < 5; n++) {
                await repo.answer(
                  material.session.id,
                  n,
                  material.lesson.exercises[n],
                  material.lesson.exercises[n].answers.first,
                  total: 10,
                );
              }
              await repo.review(repo.vocabulary.values.first, 'wrong');
              await app.refresh();
            });
            final body = page == 'checkpoint'
                ? const LessonScreen(lessonId: 'a1-01')
                : Scaffold(
                    body: page == 'practice'
                        ? const PersonalPracticePage()
                        : const ExpeditionsPage(),
                  );
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appProvider.overrideWith((_) => app)],
                child: RepaintBoundary(
                  key: key,
                  child: MaterialApp(
                    debugShowCheckedModeBanner: false,
                    theme: orbitTheme(brightness),
                    home: body,
                  ),
                ),
              ),
            );
            await flushDb(tester);
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$page $brightness $small',
            );
            await tester.runAsync(
              () => capturePreview(
                key,
                'v07/$page-${brightness.name}${small ? '-320-200' : ''}',
              ),
            );
            await tester.drag(
              find.byType(Scrollable).first,
              const Offset(0, -500),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(repo.db.close);
          }
        }
      }
    },
  );
}
