import 'course.dart';
import 'progress.dart';

/// Derived from existing answer events, so reopening a lesson restores combos
/// without extra counters, migrations or rewards.
class LearningRecap {
  int streak = 0, best = 0;
  final Set<String> difficultWords = {};
  factory LearningRecap.fromEvents(
    Iterable<LearningEvent> events,
    String session,
  ) {
    final result = LearningRecap._();
    final answers =
        {for (final e in events) e.id: e}.values
            .where((e) => e.kind == 'answer' && e.data['session'] == session)
            .toList()
          ..sort((a, b) {
            final c = a.occurredAt.compareTo(b.occurredAt);
            return c == 0 ? a.id.compareTo(b.id) : c;
          });
    final completed = <String>{};
    for (final event in answers) {
      final exercise = '${event.data['exercise']}';
      if (completed.contains(exercise)) continue;
      if (event.data['correct'] == true) {
        completed.add(exercise);
        result.streak++;
        if (result.streak > result.best) result.best = result.streak;
      } else {
        result.streak = 0;
        result.difficultWords.addAll(
          List<String>.from(event.data['words'] ?? []),
        );
      }
    }
    return result;
  }
  LearningRecap._();
}

/// Scheduling still belongs to WordProgress/SM-2. Voluntary error practice
/// includes only learned words with a failed most recent scheduling day.
List<Vocabulary> reviewWords(
  Iterable<Vocabulary> words,
  ProgressSnapshot progress,
  DateTime now, {
  bool mistakesOnly = false,
}) {
  final selected = words.where((word) {
    final state = progress.words[word.id];
    if (state == null || state.next == null) return false;
    return mistakesOnly
        ? state.errors > 0 && state.repetitions == 0
        : !state.next!.isAfter(now.toUtc());
  }).toList();
  selected.sort((a, b) {
    final first = progress.words[a.id]!, second = progress.words[b.id]!;
    final due = first.next!.compareTo(second.next!);
    if (due != 0) return due;
    final errors = second.errors.compareTo(first.errors);
    return errors != 0 ? errors : a.id.compareTo(b.id);
  });
  return selected;
}
