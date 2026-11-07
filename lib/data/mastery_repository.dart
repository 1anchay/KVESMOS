import 'dart:convert';
import '../domain/course.dart';
import '../domain/learning_unit.dart';
import 'repository.dart';

/// Optional recall over completed, pinned materials. Never writes XP or loot.
class MasteryRepository {
  final LearningRepository learning;
  final LearningUnit unit;
  final String courseId;
  MasteryRepository(this.learning, this.unit) : courseId = learning.course.id;
  String get key => 'kvesmos.mastery.v1:$courseId:${unit.id}';
  String get stampKey => '$key:stamp';
  String get difficultKey => '$key:difficult';

  Future<bool> earned() async => await learning.setting(stampKey) != null;
  void _checkCourse() {
    if (learning.course.id != courseId) throw StateError('Course changed');
  }

  Future<Map<String, dynamic>> open({bool restart = false}) =>
      learning.db.transaction(() async {
        _checkCourse();
        final catalogUnit = LearningUnit.fromCatalog(
          learning.catalog,
        ).where((u) => u.id == unit.id).firstOrNull;
        if (catalogUnit == null ||
            catalogUnit.lessons.map((l) => l.id).join(',') !=
                unit.lessons.map((l) => l.id).join(',') ||
            !unit.mastered(await learning.progress())) {
          throw StateError('Сначала заверши уроки этой темы.');
        }
        final raw = await learning.setting(key);
        if (raw != null && !restart) {
          return Map<String, dynamic>.from(jsonDecode(raw));
        }
        final items = <Map<String, dynamic>>[];
        final seen = <String>{};
        // Interleave lessons so one long vocabulary list cannot dominate.
        final groups = <List<Vocabulary>>[];
        final explanations = <String, String>{};
        for (final lesson in unit.lessons) {
          final content = (await learning.previewLesson(lesson.id)).lesson;
          groups.add(content.vocabulary);
          for (final word in content.vocabulary) {
            explanations[word.id] = content.guide;
          }
        }
        for (var i = 0; i < 3; i++) {
          for (final group in groups) {
            if (i >= group.length) continue;
            final word = group[i];
            if (!seen.add(normalizeAnswer(word.en))) continue;
            items.add({
              'id': word.id,
              'phrase': word.en,
              'meaning': word.ru,
              'pronunciation': word.pronunciation,
              'explanation': explanations[word.id],
            });
          }
        }
        if (items.isEmpty) {
          throw StateError('В теме нет материала для проверки.');
        }
        final state = <String, dynamic>{
          'items': items,
          'index': 0,
          'text': '',
          'checked': false,
          'correct': false,
          'score': 0,
          'difficult': <String>[],
          'done': false,
          'passed': false,
        };
        await _save(state);
        return state;
      });

  Future<void> _save(Map<String, dynamic> state) =>
      learning.setSetting(key, jsonEncode(state));
  Future<void> draft(int index, String text) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] == index &&
            state['checked'] == false &&
            state['done'] == false) {
          state['text'] = text;
          await _save(state);
        }
      });

  Future<Map<String, dynamic>> advance(int index, bool checked, String text) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] != index ||
            state['checked'] != checked ||
            state['done'] == true) {
          return state;
        }
        final items = state['items'] as List;
        final item = items[index] as Map;
        if (!checked) {
          if (text.trim().isEmpty) return state;
          final correct = [item['phrase'], item['pronunciation']]
              .whereType<String>()
              .any((a) => normalizeAnswer(a) == normalizeAnswer(text));
          state['text'] = text;
          state['checked'] = true;
          state['correct'] = correct;
          if (correct) {
            state['score'] = (state['score'] as int) + 1;
          } else {
            state['difficult'] = [...state['difficult'] as List, item['id']];
          }
        } else {
          state['index'] = index + 1;
          state['checked'] = false;
          state['text'] = '';
          if (index + 1 == items.length) {
            state['done'] = true;
            state['passed'] = (state['score'] as int) / items.length >= .8;
            await learning.setSetting(
              difficultKey,
              jsonEncode(state['difficult']),
            );
            if (state['passed'] == true && !await earned()) {
              await learning.setSetting(
                stampKey,
                learning.now().toUtc().toIso8601String(),
              );
            }
          }
        }
        await _save(state);
        return state;
      });
}
