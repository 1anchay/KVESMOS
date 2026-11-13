import 'course.dart';
import 'progress.dart';

enum StudySkill {
  words('Слова'),
  grammar('Грамматика'),
  sentences('Составление фраз'),
  listening('Аудирование'),
  dialogue('Диалоги');

  const StudySkill(this.label);
  final String label;

  static StudySkill? forExercise(Exercise exercise) => switch (exercise.type) {
    ExerciseType.order => sentences,
    ExerciseType.gap || ExerciseType.correct => grammar,
    ExerciseType.listen => listening,
    ExerciseType.dialogue => dialogue,
    ExerciseType.pairs || ExerciseType.review => words,
    ExerciseType.choice || ExerciseType.translate =>
      exercise.audio == null && exercise.wordIds.isNotEmpty ? words : null,
    ExerciseType.speak => null,
  };
}

class SkillEvidence {
  final int correct, errors, unresolved;
  final DateTime? last;
  const SkillEvidence(this.correct, this.errors, this.unresolved, this.last);
  int get attempts => correct + errors;
}

/// Each item on each study day counts as one observation.
/// A successful retry closes the item as a current difficulty, while the
/// original error remains visible in the observation for that day.
class SkillReport {
  final Map<StudySkill, SkillEvidence> evidence;
  final Map<StudySkill, Set<String>> difficult;
  const SkillReport(this.evidence, this.difficult);

  factory SkillReport.fromEvents(
    Iterable<LearningEvent> events, {
    required String course,
    required DateTime now,
    required StudySkill? Function(LearningEvent) historicalSkill,
  }) {
    final cutoff = now.toUtc().subtract(const Duration(days: 30));
    final sorted =
        events
            .where(
              (e) =>
                  e.courseId == course &&
                  e.kind == 'answer' &&
                  !DateTime.parse(e.occurredAt).isBefore(cutoff),
            )
            .toList()
          ..sort((a, b) {
            final order = DateTime.parse(
              a.occurredAt,
            ).compareTo(DateTime.parse(b.occurredAt));
            if (order != 0) return order;
            final verdict = (a.data['correct'] == true ? 1 : 0).compareTo(
              b.data['correct'] == true ? 1 : 0,
            );
            return verdict == 0 ? a.id.compareTo(b.id) : verdict;
          });
    final observations = <StudySkill, Map<(String, String), bool>>{};
    final latest = <StudySkill, Map<String, bool>>{};
    final last = <StudySkill, DateTime>{};
    for (final e in sorted) {
      final data = e.data;
      final named = data['skill'];
      final skill = named == null
          ? historicalSkill(e)
          : StudySkill.values.where((s) => s.name == named).firstOrNull;
      if (skill == null ||
          data['evidence'] == false ||
          skill == StudySkill.listening && data['evidence'] != true) {
        continue;
      }
      final item = data['exercise'] as String;
      final day = (item, e.day);
      final correct = data['correct'] == true;
      final byDay = observations.putIfAbsent(skill, () => {});
      byDay[day] = (byDay[day] ?? true) && correct;
      latest.putIfAbsent(skill, () => {})[item] = correct;
      last[skill] = DateTime.parse(e.occurredAt);
    }
    final difficult = {
      for (final skill in StudySkill.values)
        skill:
            latest[skill]?.entries
                .where((entry) => !entry.value)
                .map((entry) => entry.key)
                .toSet() ??
            <String>{},
    };
    return SkillReport({
      for (final skill in StudySkill.values)
        skill: SkillEvidence(
          observations[skill]?.values.where((correct) => correct).length ?? 0,
          observations[skill]?.values.where((correct) => !correct).length ?? 0,
          difficult[skill]!.length,
          last[skill],
        ),
    }, difficult);
  }
}
