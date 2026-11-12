import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/practice_repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test(
    '48 additive packs teach before assessment and have distinct situations',
    () {
      final situations = <String>{};
      var total = 0;
      for (final entry in {
        'en': (28, 40),
        'es': (6, 18),
        'de': (6, 18),
        'fr': (6, 12),
        'zh': (6, 12),
      }.entries) {
        for (var n = entry.value.$1 + 1; n <= entry.value.$2; n++) {
          final id = '${entry.key}-a1-${n.toString().padLeft(2, '0')}';
          final l = Lesson.fromJson(
            jsonDecode(File('assets/courses/$id.json').readAsStringSync()),
          );
          total++;
          expect(
            situations.add(
              l.exercises.singleWhere((e) => e.scene != null).scene!,
            ),
            isTrue,
          );
          expect(l.exercises.length, 10);
          expect(
            l.exercises.map((e) => e.type).toSet().length,
            greaterThanOrEqualTo(8),
          );
          expect(
            l.teachingSteps.map((s) => s.phrase).toSet(),
            containsAll(l.vocabulary.map((w) => w.en)),
          );
          final recall = l.exercises.singleWhere((e) => e.recall != null);
          expect(
            l.teachingSteps.map((s) => s.phrase),
            contains(recall.recall!['phrase']),
          );
          for (final e in l.exercises) {
            if (e.options.isNotEmpty) {
              expect(e.options, contains(e.answers.first), reason: e.id);
            }
            if (e.tokens.isNotEmpty) {
              expect(checkAnswer(e, e.tokens.join(' ')), isTrue, reason: e.id);
            }
            if (e.type == ExerciseType.translate ||
                e.type == ExerciseType.speak) {
              expect(
                l.teachingSteps.map((s) => s.phrase),
                contains(e.answers.first),
              );
              if (entry.key == 'zh') {
                expect(checkAnswer(e, e.pronunciation!), isTrue);
              }
            }
          }
          if (entry.key == 'zh') {
            final story = l.exercises.singleWhere((e) => e.scene != null);
            expect(story.scenePronunciation, isNotNull);
            expect(story.scene!.split('\n'), hasLength(2));
          }
        }
      }
      expect(total, 48);
    },
  );
  test(
    'six modes share daily credit, drafts survive, unit practice stays scoped',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await r.selectCourse('ru-zh');
      final l = await r.lesson('zh-a1-07');
      final word = l.vocabulary.first;
      await r.append(r.event('complete', {'lesson': l.id, 'session': 'seed'}));
      await r.append(
        r.event('answer', {
          'lesson': l.id,
          'session': 'seed',
          'exercise': 'wrong',
          'correct': false,
          'words': [word.id],
        }),
      );
      final baseline = (await r.progress()).xp;
      for (final mode in PracticeMode.values) {
        final p = PracticeRepository(r, mode: mode);
        expect((await p.open())['words'], contains(word.id), reason: mode.name);
        await p.advance(0, 0, '');
        await p.draft(0, 'partial');
        expect(
          (await PracticeRepository(r, mode: mode).open())['text'],
          'partial',
        );
        await p.advance(0, 1, word.pronunciation!);
        expect((await p.open())['correct'], true);
        expect((await r.progress()).xp, baseline + 10);
      }
      final unit = PracticeRepository(
        r,
        mode: PracticeMode.words,
        lessonIds: [l.id],
      );
      expect((await unit.open())['words'], [word.id]);
      final excluded = PracticeRepository(
        r,
        mode: PracticeMode.words,
        lessonIds: ['zh-a1-08'],
      );
      expect((await excluded.open())['words'], isEmpty);
      await r.selectCourse('ru-de');
      expect(unit.open(), throwsStateError);
    },
  );
  test(
    'new replays cannot award XP again; existing pinned sessions remain resumable',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await r.selectCourse('ru-de');
      Future<void> finish() async {
        final run = await r.startLesson('de-a1-07');
        for (var i = 0; i < run.lesson.exercises.length; i++) {
          final e = run.lesson.exercises[i];
          await r.answer(run.session.id, i, e, e.answers.first, total: 10);
        }
      }

      await finish();
      final first = await r.progress();
      expect(first.xp, 120);
      await finish();
      final second = await r.progress();
      expect(second.xp, first.xp);
      expect(second.dailyLessons, first.dailyLessons);
      final run = await r.startLesson('de-a1-08');
      await r.draft(
        run.session.id,
        0,
        jsonEncode({'text': 'mein Entwurf', 'recallHidden': true}),
      );
      final resumed = await r.startLesson('de-a1-08');
      expect(resumed.session.id, run.session.id);
      expect(jsonDecode(resumed.session.draft)['text'], 'mein Entwurf');
    },
  );
}
