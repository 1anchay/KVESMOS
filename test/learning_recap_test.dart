import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/learning_recap.dart';
import 'package:orbitwords/domain/progress.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  LearningEvent answer(int n, String exercise, bool correct) => LearningEvent(
    id: '$n',
    kind: 'answer',
    occurredAt: DateTime.utc(2026, 10, 23, 12, 0, n).toIso8601String(),
    day: '2026-10-23',
    data: {
      'session': 'run',
      'exercise': exercise,
      'correct': correct,
      'words': ['en:book'],
    },
  );
  test(
    'combos survive reopening, retries reset them, duplicate success earns no combo or XP',
    () {
      final events = [
        answer(0, 'a', true),
        answer(1, 'b', true),
        answer(2, 'c', false),
        answer(3, 'c', true),
        answer(4, 'c', true),
      ];
      final recap = LearningRecap.fromEvents([
        ...events.reversed,
        events.first,
      ], 'run');
      expect(recap.best, 2);
      expect(recap.streak, 1);
      expect(recap.difficultWords, {'en:book'});
      final progress = ProgressSnapshot.fromEvents(events);
      expect(progress.xp, 30);
      expect(progress.words['en:book']!.repetitions, 0);
      expect(progress.words['en:book']!.interval, 1);
    },
  );
  test(
    'error practice uses existing WordProgress, due dates and learned words',
    () {
      final progress = ProgressSnapshot.fromEvents([
        answer(0, 'a', false),
        answer(1, 'a', true),
      ]);
      final words = [
        const Vocabulary('en:book', 'book', 'книга'),
        const Vocabulary('en:pen', 'pen', 'ручка'),
      ];
      final today = DateTime.utc(2026, 10, 23, 14);
      expect(reviewWords(words, progress, today), isEmpty);
      expect(
        reviewWords(
          words,
          progress,
          today,
          mistakesOnly: true,
        ).map((w) => w.id),
        ['en:book'],
      );
      expect(
        reviewWords(
          words,
          progress,
          today.add(const Duration(days: 1)),
        ).map((w) => w.id),
        ['en:book'],
      );
      expect(progress.xp, 10);
    },
  );
  test(
    'mistake explanations use the original pinned lesson after asset changes',
    () async {
      final repo = memoryRepository();
      await repo.initialize();
      final run = await repo.startLesson('a1-01');
      final exercise = run.lesson.exercises.first;
      await repo.answer(run.session.id, 0, exercise, 'wrong', total: 10);
      repo.updatedMaterials['a1-01'] = '{}';
      final examples = await repo.mistakeExamples();
      expect(
        examples[exercise.wordIds.first]?.explanation,
        exercise.explanation,
      );
      expect((await repo.progress()).xp, 0);
      expect((await repo.session(run.session.id)).position, 0);
      await repo.db.close();
    },
  );
}
