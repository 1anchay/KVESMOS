import 'dart:convert';

import '../domain/course.dart';
import '../domain/learning_unit.dart';
import 'repository.dart';

class SmartPlacementRepository {
  static const prefix = 'kvesmos.placement.v2:';
  static const version = 2;
  final LearningRepository learning;
  final String courseId;
  SmartPlacementRepository(this.learning) : courseId = learning.course.id;
  String get key => '$prefix$courseId';

  Future<Map<String, dynamic>?> saved() async {
    final raw = await learning.setting(key);
    if (raw == null || raw.length > 100000) return null;
    try {
      final state = Map<String, dynamic>.from(jsonDecode(raw));
      return valid(state, learning.catalog.map((l) => l.id).toSet())
          ? state
          : null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> open({bool restart = false}) =>
      learning.db.transaction(() async {
        _checkCourse();
        final previous = await saved();
        if (previous != null && !restart) return previous;
        final lessons = learning.catalog;
        final units = LearningUnit.fromCatalog(lessons);
        final questions = <Map<String, dynamic>>[];
        const formats = [
          [ExerciseType.choice, ExerciseType.translate],
          [ExerciseType.gap, ExerciseType.correct],
          [ExerciseType.order, ExerciseType.translate],
          [ExerciseType.dialogue, ExerciseType.choice],
        ];
        for (var band = 0; band < 3; band++) {
          for (var n = 0; n < 5; n++) {
            final index = ((band * .29 + n * .048) * lessons.length).floor();
            final lesson = Lesson.fromJson(
              jsonDecode(learning.updatedMaterials[lessons[index].id]!),
            );
            final kinds = formats[n % formats.length];
            final available = lesson.exercises
                .where(
                  (e) =>
                      kinds.contains(e.type) &&
                      e.audio == null &&
                      e.answers.isNotEmpty &&
                      (e.type != ExerciseType.dialogue || e.scene != null) &&
                      !questions.any(
                        (q) => q['prompt'] == e.prompt && q['scene'] == e.scene,
                      ),
                )
                .toList();
            if (available.isEmpty) continue;
            final item = available.first;
            final options = item.options.toList();
            if (options.isNotEmpty) {
              final shift = (band + n) % options.length;
              options.addAll(options.take(shift).toList());
              options.removeRange(0, shift);
            }
            final answers = item.answers.toList();
            questions.add({
              'id': item.id,
              'band': band,
              'skill': switch (item.type) {
                ExerciseType.dialogue => 'Диалоги',
                ExerciseType.gap || ExerciseType.correct => 'Грамматика',
                ExerciseType.order || ExerciseType.translate => 'Фразы',
                _ => 'Слова',
              },
              'prompt': item.prompt,
              'scene': item.scene,
              'pinyin': item.scenePronunciation,
              'options': options,
              'answers': answers,
              'tokens': item.type == ExerciseType.order
                  ? item.tokens
                  : <String>[],
            });
          }
        }
        if (questions.length < 10) {
          throw StateError('Недостаточно заданий диагностики.');
        }
        final state = <String, dynamic>{
          'assessmentVersion': version,
          'started': learning.now().toUtc().toIso8601String(),
          'questions': questions,
          'results': <Map<String, dynamic>>[],
          'sectionStarts': [
            units.first.lessons.first.id,
            units[(units.length * .24).floor()].lessons.first.id,
            units[(units.length * .50).floor()].lessons.first.id,
          ],
          if (previous?['recommendation'] != null)
            'previous': {
              'recommendation': previous!['recommendation'],
              'finished': previous['finished'],
              'level': previous['level'],
            },
        };
        await _save(state);
        return state;
      });

  static Map<String, dynamic>? question(Map<String, dynamic> state) {
    if (state['recommendation'] != null) return null;
    final rows = List<Map<String, dynamic>>.from(state['questions']);
    final results = List<Map<String, dynamic>>.from(state['results']);
    final used = results.map((r) => r['id']).toSet();
    final remaining = rows.where((q) => !used.contains(q['id'])).toList();
    if (remaining.isEmpty || results.length >= 12) return null;
    final current = results.isEmpty ? 0 : results.last['band'] as int;
    final recent = results.where((r) => r['band'] == current).toList();
    final passed = recent.where((r) => r['correct'] == true).length;
    final target = recent.length >= 2 && passed >= 2
        ? (current + 1).clamp(0, 2)
        : recent.length >= 3 && passed <= 1
        ? (current - 1).clamp(0, 2)
        : current;
    // Once a band is exhausted, prefer its neighbour; never repeat a task.
    remaining.sort((a, b) {
      final distance = ((a['band'] as int) - target).abs().compareTo(
        ((b['band'] as int) - target).abs(),
      );
      return distance != 0
          ? distance
          : rows.indexOf(a).compareTo(rows.indexOf(b));
    });
    return remaining.first;
  }

  Future<Map<String, dynamic>> answer(String id, String input) =>
      learning.db.transaction(() async {
        _checkCourse();
        final state = (await saved())!;
        final item = question(state);
        if (item == null ||
            item['id'] != id ||
            input.trim().isEmpty ||
            input.length > 400) {
          return state;
        }
        final results = List<Map<String, dynamic>>.from(state['results']);
        final correct = (item['answers'] as List).any(
          (value) => normalizeAnswer(value) == normalizeAnswer(input),
        );
        results.add({
          'id': id,
          'band': item['band'],
          'skill': item['skill'],
          'correct': correct,
        });
        state['results'] = results;
        if (question(state) == null) {
          var level = 0;
          for (final band in [1, 2]) {
            final seen = results.where((r) => r['band'] == band).toList();
            if (seen.where((r) => r['correct'] == true).length >= 3 &&
                seen.where((r) => r['correct'] == false).length <= 1) {
              level = band;
            }
          }
          state['level'] = level;
          state['recommendation'] = (state['sectionStarts'] as List)[level];
          state['finished'] = learning.now().toUtc().toIso8601String();
        }
        await _save(state);
        return state;
      });

  Future<void> _save(Map<String, dynamic> state) =>
      learning.setSetting(key, jsonEncode(state));

  void _checkCourse() {
    if (learning.course.id != courseId) throw StateError('Курс изменился.');
  }

  static bool valid(Map<String, dynamic> state, Set<String> lessons) {
    if (state['assessmentVersion'] != version ||
        DateTime.tryParse('${state['started']}') == null) {
      return false;
    }
    final questions = List<Map<String, dynamic>>.from(state['questions']);
    final results = List<Map<String, dynamic>>.from(state['results']);
    final ids = questions.map((q) => q['id']).toSet();
    final starts = List<String>.from(state['sectionStarts']);
    return questions.length >= 10 &&
        questions.length <= 15 &&
        ids.length == questions.length &&
        starts.length == 3 &&
        starts.every(lessons.contains) &&
        results.length <= 12 &&
        results.map((r) => r['id']).toSet().length == results.length &&
        questions.every(
          (q) =>
              q['id'] is String &&
              q['prompt'] is String &&
              q['skill'] is String &&
              [0, 1, 2].contains(q['band']) &&
              List<String>.from(q['answers']).isNotEmpty &&
              List<String>.from(q['options']).length <= 10 &&
              List<String>.from(q['tokens']).length <= 25 &&
              (q['scene'] == null || q['scene'] is String) &&
              (q['pinyin'] == null || q['pinyin'] is String),
        ) &&
        results.every(
          (r) =>
              ids.contains(r['id']) &&
              r['correct'] is bool &&
              [0, 1, 2].contains(r['band']) &&
              r['skill'] is String,
        ) &&
        (state['recommendation'] == null ||
            starts.contains(state['recommendation']) &&
                [0, 1, 2].contains(state['level']) &&
                DateTime.tryParse('${state['finished']}') != null);
  }
}
