// Dedicated QA emulator only. Uses an isolated in-memory fixture; the runner
// may clear its package. Back up and restore the QA install around this test.
import 'dart:convert';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:go_router/go_router.dart';
import 'package:drift/native.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/adventures_repository.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/space_adventures.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'lesson unlocks station; all three games, offline clips and replay',
    (tester) async {
      final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
      final app = AppController(repo);
      await app.initialize();
      await app.finishOnboarding();
      await app.saveAudio(const AudioPreferences(speech: false, effects: true));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(Finder finder) async {
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          finder,
          180,
          maxScrolls: 40,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await Future<void>.delayed(const Duration(milliseconds: 180));
        await tester.pumpAndSettle();
      }

      final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
      router.go('/lesson/a1-01');
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 12 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
        i++
      ) {
        await tap(find.byKey(const Key('teaching-next')));
      }
      final material = await repo.startLesson('a1-01');
      for (final e in material.lesson.exercises) {
        if (e.options.isNotEmpty) {
          await tap(find.widgetWithText(OutlinedButton, e.answers.first));
        } else if (e.type == ExerciseType.order) {
          for (final token in e.tokens) {
            await tap(find.widgetWithText(ActionChip, token));
          }
        } else {
          await tester.enterText(find.byType(TextField), e.answers.first);
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
      router.go('/map');
      await tester.pumpAndSettle();
      await tap(find.byKey(const Key('adventure-beacon')));
      final timings = <FrameTiming>[];
      void collect(List<FrameTiming> batch) => timings.addAll(batch);
      WidgetsBinding.instance.addTimingsCallback(collect);
      for (final adventure in SpaceAdventure.all) {
        // Later prerequisites use the same repository answers, not fake XP rows.
        for (final id in adventure.prerequisites.where(
          (id) => !app.progress.completed.contains(id),
        )) {
          final m = await repo.startLesson(id);
          for (var i = 0; i < 10; i++) {
            final e = m.lesson.exercises[i];
            await repo.answer(m.session.id, i, e, e.answers.first, total: 10);
          }
        }
        await app.refresh();
        router.go('/adventure/${adventure.id}');
        await tester.pumpAndSettle();
        final before = app.progress.xp;
        for (var run = 0; run < (adventure.id == 'beacon' ? 2 : 1); run++) {
          for (final step in adventure.steps) {
            await tap(find.byKey(ValueKey('object-${step.target}')));
            if (step.id == 'hello' && run == 0) {
              await tap(find.byKey(const Key('answer-Goodbye!')));
            }
            switch (step.action) {
              case AdventureAction.inspect:
                await tap(find.byKey(const Key('adventure-submit')));
              case AdventureAction.dialogue:
              case AdventureAction.route:
                await tap(find.byKey(ValueKey('answer-${step.answer}')));
              case AdventureAction.assemble:
                for (final tile in step.answer.split(' ')) {
                  await tap(find.byKey(ValueKey('tile-$tile')));
                }
                await tap(find.byKey(const Key('adventure-submit')));
              case AdventureAction.cargo:
                await tap(find.byKey(ValueKey('cargo-${step.answer}')));
                await tap(find.byKey(const Key('adventure-submit')));
            }
          }
          expect(
            (await AdventuresRepository(repo).read(adventure.id)).completed,
            true,
          );
          expect(app.progress.xp, before + adventure.xp);
          if (adventure.id == 'beacon' && run == 0) {
            await tap(find.byKey(const Key('adventure-replay')));
          }
        }
      }
      WidgetsBinding.instance.removeTimingsCallback(collect);
      Map<String, dynamic> stats(List<double> samples) {
        samples.sort();
        return {
          'count': samples.length,
          'medianMs': samples[samples.length ~/ 2],
          'p95Ms': samples[((samples.length - 1) * .95).round()],
        };
      }

      debugPrint(
        'SPACE_FRAME_TIMINGS ${jsonEncode({'build': stats(timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()), 'raster': stats(timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList())})}',
      );
      await app.saveAudio(const AudioPreferences());
      for (final a in SpaceAdventure.all) {
        for (final phrase in a.steps.map((s) => s.english).toSet()) {
          expect(
            await app.audio.speak(phrase, character: a.guide, slow: true),
            true,
          );
          expect(app.audio.lastSource, SpeechSource.recording);
          await app.audio.stop();
        }
      }
      for (final effect in [
        SoundEffect.interact,
        SoundEffect.pickup,
        SoundEffect.chapter,
      ]) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        expect(await app.audio.play(effect), true);
      }
      router.go('/rewards');
      await tester.pumpAndSettle();
      await tap(find.text('Открыть сундук').first);
      await tap(find.text('Открыть').first);
      expect(app.inventory.owned.length, 1);
      router.go('/profile');
      await tester.pumpAndSettle();
      router.go('/map');
      await tester.pumpAndSettle();
      expect(app.completedAdventures.length, 3);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await repo.db.close();
    },
  );
}
