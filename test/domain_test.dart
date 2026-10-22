import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/progress.dart';

LearningEvent answer(
  String id,
  DateTime at, {
  bool correct = true,
  String session = 's',
  String exercise = 'e',
}) => LearningEvent(
  id: id,
  kind: 'answer',
  occurredAt: at.toUtc().toIso8601String(),
  day: dayKey(at),
  data: {
    'session': session,
    'exercise': exercise,
    'correct': correct,
    'words': ['en:hello'],
  },
);
void main() {
  test(
    'normalization preserves meaningful words, accepts punctuation and contractions',
    () {
      expect(normalizeAnswer("  I'M from Russia! "), 'i am from russia');
      expect(
        normalizeAnswer('Hello, my name is Anna.'),
        'hello my name is anna',
      );
      expect(
        normalizeAnswer('I am not Anna'),
        isNot(normalizeAnswer('I am Anna')),
      );
    },
  );
  test(
    '20 lessons have unique ids, 200 exercises, 10 types, viable answers',
    () {
      final ids = <String>{};
      final words = <String>{};
      var count = 0;
      for (var i = 1; i <= 20; i++) {
        final lesson = Lesson.fromJson(
          jsonDecode(
            File(
              'assets/courses/a1-${i.toString().padLeft(2, '0')}.json',
            ).readAsStringSync(),
          ),
        );
        expect(lesson.exercises.length, 10);
        expect(
          lesson.exercises.map((e) => e.type).toSet(),
          ExerciseType.values.toSet(),
        );
        for (final v in lesson.vocabulary) {
          words.add(v.id);
        }
        for (final e in lesson.exercises) {
          expect(ids.add(e.id), isTrue);
          expect(e.explanation, isNotEmpty);
          expect(checkAnswer(e, e.answers.first), isTrue);
          expect(checkAnswer(e, ''), isFalse);
          expect(checkAnswer(e, 'nonsense'), isFalse);
          expect(
            e.wordIds.every((id) => lesson.vocabulary.any((w) => w.id == id)),
            isTrue,
          );
          if (e.options.isNotEmpty) {
            expect(e.options.length, 4);
            expect(e.options.toSet().length, 4);
            expect(e.options.where((o) => checkAnswer(e, o)).length, 1);
          }
          if (e.type == ExerciseType.order) {
            expect(checkAnswer(e, e.tokens.join(' ')), isTrue);
          }
          count++;
        }
      }
      expect(count, 200);
      expect(words.length, 60);
    },
  );
  test(
    'XP deduplicates events and successful exercise submissions, errors cost nothing',
    () {
      final time = DateTime(2026, 10, 21);
      final e = answer('a', time);
      final p = ProgressSnapshot.fromEvents([
        e,
        e,
        answer('b', time),
        answer('c', time, correct: false),
      ]);
      expect(p.xp, 10);
      expect(p.correct, 2);
      expect(p.errors, 1);
    },
  );
  test(
    'completion bonus is idempotent per session and unlocks achievements',
    () {
      final events = List.generate(
        5,
        (i) => LearningEvent(
          id: 'c$i',
          kind: 'complete',
          occurredAt: '2026-10-21T12:00:00Z',
          day: '2026-10-21',
          data: {'session': 's$i', 'lesson': 'l$i'},
        ),
      );
      final p = ProgressSnapshot.fromEvents([...events, events.first]);
      expect(p.xp, 100);
      expect(p.completed.length, 5);
      expect(p.achievements, contains('Исследователь'));
    },
  );
  test('SM-2 follows 1, 6, 15 days and resets repetitions after an error', () {
    final w = WordProgress();
    var now = DateTime.utc(2026, 1, 1);
    w.schedule(true, now);
    expect(w.interval, 1);
    now = w.next!;
    w.schedule(true, now);
    expect(w.interval, 6);
    now = w.next!;
    w.schedule(true, now);
    expect(w.interval, 15);
    now = w.next!;
    w.schedule(false, now);
    expect(w.interval, 1);
    expect(w.repetitions, 0);
    expect(w.ease, lessThan(2.5));
    for (var i = 0; i < 10; i++) {
      w.schedule(false, now);
    }
    expect(w.ease, 1.3);
  });
  test(
    'same-day retries do not inflate mastery and mistakes dominate that day',
    () {
      final t = DateTime.utc(2026, 10, 21);
      final p = ProgressSnapshot.fromEvents([
        answer('1', t, correct: false),
        answer('2', t, exercise: 'e2'),
        answer('3', t, exercise: 'e3'),
      ]);
      expect(p.words['en:hello']!.repetitions, 0);
      expect(p.words['en:hello']!.errors, 1);
    },
  );
  test('event merges are order-independent including offset timestamps', () {
    final a = answer('1', DateTime.utc(2026, 10, 20));
    final b = answer('2', DateTime.utc(2026, 10, 21), exercise: 'e2');
    expect(
      ProgressSnapshot.fromEvents([a, b, a]).xp,
      ProgressSnapshot.fromEvents([b, a]).xp,
    );
    expect(
      ProgressSnapshot.fromEvents([a, b]).words['en:hello']!.next,
      ProgressSnapshot.fromEvents([b, a]).words['en:hello']!.next,
    );
  });
  test(
    'streak allows today before studying, resets after a missed full day',
    () {
      final p = ProgressSnapshot.fromEvents([
        answer('1', DateTime(2026, 10, 19)),
        answer('2', DateTime(2026, 10, 20), exercise: 'e2'),
      ]);
      expect(p.streak(DateTime(2026, 10, 21)), 2);
      expect(p.streak(DateTime(2026, 10, 22)), 0);
    },
  );
}
