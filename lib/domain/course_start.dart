import 'course.dart';

class CourseStart {
  final List<LessonInfo> catalog;
  final Set<String> completed, active;
  final String? chosen;
  const CourseStart(this.catalog, this.completed, this.active, this.chosen);

  LessonInfo? get entry => catalog.where((l) => l.id == chosen).firstOrNull;
  int get floor => entry?.order ?? 0;

  bool deferred(LessonInfo lesson) =>
      lesson.order < floor &&
      !completed.contains(lesson.id) &&
      !active.contains(lesson.id);

  bool available(LessonInfo lesson) =>
      lesson.order <= floor ||
      active.contains(lesson.id) ||
      completed.contains(lesson.id) ||
      completed.contains(catalog[lesson.order - 1].id);

  LessonInfo? get next =>
      catalog.where((l) => active.contains(l.id)).firstOrNull ??
      catalog
          .where(
            (l) =>
                l.order >= floor && available(l) && !completed.contains(l.id),
          )
          .firstOrNull ??
      catalog.where((l) => deferred(l)).firstOrNull;
}
