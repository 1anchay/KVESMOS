import 'dart:convert';
import '../domain/course.dart';
import 'repository.dart';

class PlacementRepository {
  final LearningRepository learning;
  final String courseId;
  PlacementRepository(this.learning) : courseId = learning.course.id;
  String get key => 'kvesmos.placement.v1:$courseId';

  Future<Map<String, dynamic>> open() => learning.db.transaction(() async {
    if (learning.course.id != courseId) throw StateError('Курс изменился');
    final saved = await learning.setting(key);
    if (saved != null) return Map<String, dynamic>.from(jsonDecode(saved));
    final installed = (await learning.installed()).toSet();
    final questions = <Map<String, dynamic>>[];
    for (final order in [0, 2, 4, 6, 8, 10, 12, 14]) {
      final info = learning.catalog[order];
      if (!installed.contains(info.id)) continue;
      final material = (await learning.previewLesson(info.id)).lesson;
      final exercise = material.exercises
          .where(
            (e) =>
                (e.type == ExerciseType.choice || e.type == ExerciseType.gap) &&
                e.options.length >= 2 &&
                e.audio == null,
          )
          .firstOrNull;
      if (exercise == null) continue;
      final options = exercise.options.toList();
      // Deterministic rotation means resumed questions never move under focus.
      final shift = questions.length % options.length;
      questions.add({
        'order': order,
        'prompt': exercise.prompt,
        'options': [...options.skip(shift), ...options.take(shift)],
        'answers': exercise.answers,
      });
    }
    if (questions.length < 5) {
      throw StateError('Для диагностики нужны сохранённые уроки курса.');
    }
    final state = <String, dynamic>{
      'questions': questions,
      'results': <bool>[],
    };
    await learning.setSetting(key, jsonEncode(state));
    return state;
  });

  Future<Map<String, dynamic>> answer(
    int expected,
    String option,
  ) => learning.db.transaction(() async {
    final state = await open();
    final results = List<bool>.from(state['results']);
    final questions = state['questions'] as List;
    if (expected != results.length || expected >= questions.length) {
      return state;
    }
    final question = questions[expected] as Map;
    if (!(question['options'] as List).contains(option)) return state;
    results.add(
      (question['answers'] as List).any(
        (a) => normalizeAnswer(a) == normalizeAnswer(option),
      ),
    );
    state['results'] = results;
    if (results.length == questions.length) {
      // Stop at the first gap in the sampled sequence. This is a suggestion,
      // never a completion or a measurement of CEFR proficiency.
      final firstGap = results.indexOf(false);
      final order = firstGap < 0
          ? (questions.last['order'] as int) + 1
          : questions[firstGap]['order'] as int;
      state['recommendation'] = learning.catalog[order].id;
    }
    await learning.setSetting(key, jsonEncode(state));
    return state;
  });
}
