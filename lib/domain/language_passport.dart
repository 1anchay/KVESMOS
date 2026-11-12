import 'languages.dart';
import 'progress.dart';

/// Read-only projections. Selecting a course is not a learning event.
class LanguagePassport {
  final StudyCourse course;
  final ProgressSnapshot progress;
  final bool started;
  LanguagePassport(this.course, Iterable<LearningEvent> events)
    : progress = ProgressSnapshot.fromEvents(events),
      started = events.any(
        (e) => const {'answer', 'complete', 'review'}.contains(e.kind),
      );

  static List<LanguagePassport> fromEvents(List<LearningEvent> events) => [
    for (final c in StudyCourse.all)
      LanguagePassport(c, events.where((e) => e.courseId == c.id)),
  ];
  int get mastered => progress.words.values.where((w) => w.mastery >= 1).length;
  List<String> achievements(DateTime now) => [
    if (started) 'Первый шаг',
    if (progress.completed.isNotEmpty) 'Первый разговор',
    if (progress.completed.length >= course.lessons)
      'Начальный маршрут пройден',
    if (progress.streak(now) >= 3) 'Три дня вместе',
    if (mastered >= 3) 'Слова надолго',
  ];
}
