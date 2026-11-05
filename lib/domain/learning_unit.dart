import 'course.dart';
import 'progress.dart';

/// Presentation over durable lesson IDs. Reading a unit never writes progress.
class LearningUnit {
  final String id, title, section;
  final List<LessonInfo> lessons;
  const LearningUnit(this.id, this.title, this.section, this.lessons);

  int completed(ProgressSnapshot progress) =>
      lessons.where((l) => progress.completed.contains(l.id)).length;
  bool mastered(ProgressSnapshot progress) =>
      lessons.isNotEmpty && completed(progress) == lessons.length;
  LessonInfo? next(ProgressSnapshot progress) =>
      lessons.where((l) => !progress.completed.contains(l.id)).firstOrNull;

  static List<LearningUnit> fromCatalog(List<LessonInfo> catalog) {
    final units = <LearningUnit>[];
    var group = <LessonInfo>[];
    void finish() {
      if (group.isEmpty) return;
      final first = group.first;
      units.add(
        LearningUnit(
          'unit:${first.id}',
          group.length == 1
              ? first.title
              : '${first.title} · ${group.last.title}',
          first.section,
          List.unmodifiable(group),
        ),
      );
      group = [];
    }

    for (final lesson in catalog) {
      if (group.isNotEmpty &&
          (group.length == 2 ||
              group.first.section != lesson.section ||
              group.first.topic != lesson.topic)) {
        finish();
      }
      group.add(lesson);
    }
    finish();
    return units;
  }
}
