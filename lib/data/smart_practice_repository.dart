import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../domain/course.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import '../domain/study_skills.dart';
import 'repository.dart';
import 'listening_repository.dart';

class SmartItem {
  final String? lessonId;
  final Vocabulary? word;
  final Exercise exercise;
  const SmartItem(this.exercise, {this.lessonId, this.word});
}

typedef SmartPlan = ({
  StudySkill? skill,
  String reason,
  SkillReport report,
  List<SmartItem> items,
  String? listeningScene,
});

class SmartPracticeRepository {
  final LearningRepository learning;
  final String courseId;
  SmartPracticeRepository(this.learning) : courseId = learning.course.id;
  String get key => 'kvesmos.smart.v1:$courseId';

  Future<Map<String, SmartItem>> _exercises(Set<String> lessonIds) async {
    final installed = await learning.installed();
    final result = <String, SmartItem>{};
    for (final id in lessonIds.where(installed.contains)) {
      final raw = learning.updatedMaterials[id];
      final lesson = raw == null
          ? await learning.lesson(id)
          : Lesson.fromJson(jsonDecode(raw));
      for (final exercise in lesson.exercises) {
        if (StudySkill.forExercise(exercise) != null) {
          result[exercise.id] = SmartItem(exercise, lessonId: id);
        }
      }
    }
    return result;
  }

  SmartItem _word(Vocabulary word) => SmartItem(
    Exercise(
      id: 'review:${word.id}',
      type: ExerciseType.review,
      prompt: 'Вспомни на изучаемом языке: «${word.ru}»',
      answers: [word.en, if (word.pronunciation != null) word.pronunciation!],
      wordIds: [word.id],
      explanation: '${word.en} — ${word.ru}',
    ),
    word: word,
  );

  Future<SmartPlan> plan() async {
    if (learning.course.id != courseId) throw StateError('Курс изменился.');
    final now = learning.now();
    final all = await learning.allEvents();
    final events = all.where((e) => e.courseId == courseId).toList();
    final progress = ProgressSnapshot.fromEvents(events);
    final cutoff = now.toUtc().subtract(const Duration(days: 30));
    final tried = events.where(
      (e) =>
          e.kind == 'answer' &&
          e.data['lesson'] is String &&
          !DateTime.parse(e.occurredAt).isBefore(cutoff),
    );
    final catalog = learning.catalog.map((l) => l.id).toSet();
    final available = await _exercises({
      ...progress.completed.where(catalog.contains),
      ...tried.map((e) => e.data['lesson'] as String).where(catalog.contains),
    });
    final attemptedIds = tried.map((e) => e.data['exercise']).toSet();
    final missing = tried.where(
      (e) =>
          e.data['skill'] == null && !available.containsKey(e.data['exercise']),
    );
    final historical = <String, StudySkill?>{};
    final materials = <String, Lesson?>{};
    for (final event in missing) {
      final session = event.data['session'] as String;
      if (!materials.containsKey(session)) {
        final raw = await learning.setting(
          'kvesmos.session.material.v1:$session',
        );
        materials[session] = raw == null
            ? null
            : Lesson.fromJson(jsonDecode(raw));
      }
      final exercise = materials[session]?.exercises
          .where((e) => e.id == event.data['exercise'])
          .firstOrNull;
      if (exercise != null) {
        historical[event.id] = StudySkill.forExercise(exercise);
      }
    }
    final report = SkillReport.fromEvents(
      events,
      course: courseId,
      now: now,
      historicalSkill: (event) {
        final id = event.data['exercise'] as String;
        if (id.startsWith('review:')) return StudySkill.words;
        final exercise = available[id]?.exercise;
        return historical[event.id] ??
            (exercise == null ? null : StudySkill.forExercise(exercise));
      },
    );
    final due = personalPractice(
      learning.vocabulary.values,
      progress,
      now,
      limit: 6,
    );
    final known =
        learning.vocabulary.values
            .where((w) => progress.words.containsKey(w.id))
            .toList()
          ..sort((a, b) {
            final left = progress.words[a.id]!.next ?? now;
            final right = progress.words[b.id]!.next ?? now;
            final time = left.compareTo(right);
            return time == 0 ? a.id.compareTo(b.id) : time;
          });
    final eligible = <StudySkill, List<SmartItem>>{};
    for (final item in available.values) {
      final skill = StudySkill.forExercise(item.exercise)!;
      if (skill == StudySkill.words ||
          skill == StudySkill.dialogue ||
          skill == StudySkill.listening && item.exercise.audio == null) {
        continue;
      }
      if (!progress.completed.contains(item.lessonId) &&
          !attemptedIds.contains(item.exercise.id)) {
        continue;
      }
      eligible.putIfAbsent(skill, () => []).add(item);
    }
    if (known.isNotEmpty) {
      eligible[StudySkill.words] = {
        for (final pick in due) pick.word.id: _word(pick.word),
        for (final word in known) word.id: _word(word),
      }.values.toList();
    }
    final listeningErrors = report.difficult[StudySkill.listening]!;
    String? sceneId;
    if (listeningErrors.isNotEmpty) {
      final scenes = ListeningScene.parse(
        await learning.loadAsset('assets/learning/listening.txt'),
      );
      final candidate = scenes
          .where(
            (scene) =>
                scene.language == learning.course.language &&
                listeningErrors.any((id) => id.startsWith('${scene.id}:')),
          )
          .firstOrNull;
      final maxUnresolved = eligible.keys.fold<int>(0, (max, skill) {
        final count = report.evidence[skill]!.unresolved;
        return count > max ? count : max;
      });
      if (candidate != null && listeningErrors.length >= maxUnresolved) {
        sceneId = candidate.id;
      }
    }
    if (sceneId != null) {
      return (
        skill: StudySkill.listening,
        reason:
            'В недавнем аудиодиалоге остались ответы с ошибками. Послушаем знакомую ситуацию ещё раз.',
        report: report,
        items: const <SmartItem>[],
        listeningScene: sceneId,
      );
    }
    if (eligible.isEmpty) {
      return (
        skill: null,
        reason:
            'Начни урок: после первых ответов Орби сможет подобрать тренировку.',
        report: report,
        items: const <SmartItem>[],
        listeningScene: null,
      );
    }
    final ranks = eligible.keys.toList()
      ..sort((a, b) {
        final x = report.evidence[a]!, y = report.evidence[b]!;
        final trouble = y.unresolved.compareTo(x.unresolved);
        if (trouble != 0) return trouble;
        if (due.isNotEmpty &&
            (a == StudySkill.words || b == StudySkill.words)) {
          return a == StudySkill.words ? -1 : 1;
        }
        final byTime = (x.last ?? DateTime.utc(2000)).compareTo(
          y.last ?? DateTime.utc(2000),
        );
        return byTime == 0 ? a.index.compareTo(b.index) : byTime;
      });
    final skill = ranks.first;
    final priority = report.difficult[skill]!;
    final candidates = eligible[skill]!;
    if (skill != StudySkill.words) {
      candidates.sort((a, b) {
        final first = (priority.contains(b.exercise.id) ? 1 : 0).compareTo(
          priority.contains(a.exercise.id) ? 1 : 0,
        );
        return first == 0 ? a.exercise.id.compareTo(b.exercise.id) : first;
      });
    }
    final selected = candidates.take(6).toList();
    // Keep the round useful with a small history. Only add known SM-2 items.
    final included = selected.map((i) => i.exercise.id).toSet();
    for (final item in eligible[StudySkill.words] ?? const <SmartItem>[]) {
      if (selected.length >= 4) break;
      if (included.add(item.exercise.id)) selected.add(item);
    }
    final reason = priority.isNotEmpty
        ? 'В этом навыке есть задания, где последний ответ был с ошибкой: ${priority.length}. Вернёмся к знакомому материалу.'
        : skill == StudySkill.words && due.isNotEmpty
        ? 'По расписанию SM-2 пора повторить знакомые слова: ${due.length} в подборке.'
        : report.evidence[skill]!.last == null
        ? 'Для этого навыка пока мало подтверждённых ответов. Начнём со знакомых заданий.'
        : 'Последняя попытка в этом навыке была ${dayKey(report.evidence[skill]!.last!.toLocal())}. Освежим материал.';
    return (
      skill: skill,
      reason: reason,
      report: report,
      items: selected,
      listeningScene: null,
    );
  }

  Future<Map<String, dynamic>?> saved() async {
    final raw = await learning.setting(key);
    return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<bool> hasDraft() async {
    final state = await saved();
    return state != null &&
        (state['index'] as int) < (state['items'] as List).length;
  }

  Future<void> _save(Map<String, dynamic> state) =>
      learning.setSetting(key, jsonEncode(state));

  Future<Map<String, dynamic>?> open({bool restart = false}) =>
      learning.db.transaction(() async {
        if (learning.course.id != courseId) throw StateError('Курс изменился.');
        final prior = await saved();
        if (prior != null &&
            !restart &&
            (prior['index'] as int) < (prior['items'] as List).length) {
          return prior;
        }
        final next = await plan();
        if (next.items.isEmpty) return null;
        final state = <String, dynamic>{
          'run': const Uuid().v4(),
          'skill': next.skill!.name,
          'reason': next.reason,
          'items': [
            for (final item in next.items)
              {
                'id': item.exercise.id,
                'lesson': item.lessonId,
                'word': item.word?.id,
              },
          ],
          'index': 0,
          'score': 0,
          'correct': null,
          'text': '',
          'order': <int>[],
        };
        await _save(state);
        return state;
      });

  Future<List<SmartItem>> material(Map<String, dynamic> state) async {
    final items = List<Map<String, dynamic>>.from(state['items']);
    final exercises = await _exercises(
      items.map((i) => i['lesson']).whereType<String>().toSet(),
    );
    return [
      for (final item in items)
        if (item['word'] != null)
          _word(learning.allVocabulary[item['word']]!)
        else
          exercises[item['id']]!,
    ];
  }

  Future<void> draft(String run, int index, String text, List<int> order) =>
      learning.db.transaction(() async {
        final state = await saved();
        if (state == null ||
            state['run'] != run ||
            state['index'] != index ||
            state['correct'] != null) {
          return;
        }
        state['text'] = text;
        state['order'] = order;
        await _save(state);
      });

  Future<Map<String, dynamic>> answer(
    String run,
    int index,
    SmartItem item,
    String input, {
    bool heard = false,
  }) => learning.db.transaction(() async {
    final state = (await saved())!;
    if (learning.course.id != courseId ||
        state['run'] != run ||
        state['index'] != index ||
        state['correct'] != null ||
        (state['items'] as List)[index]['id'] != item.exercise.id) {
      return state;
    }
    final correct = checkAnswer(item.exercise, input);
    final skill = StudySkill.forExercise(item.exercise)!;
    if (item.word case final word?) {
      await learning.review(word, correct ? word.en : input, credit: false);
    } else if (skill != StudySkill.listening || heard) {
      await learning.recordPractice(
        courseId: courseId,
        sessionId: run,
        itemId: item.exercise.id,
        skill: skill,
        correct: correct,
      );
    }
    state['correct'] = correct;
    state['text'] = input;
    if (correct) state['score'] = (state['score'] as int) + 1;
    await _save(state);
    return state;
  });

  Future<Map<String, dynamic>> advance(String run, int index) =>
      learning.db.transaction(() async {
        final state = (await saved())!;
        if (state['run'] == run &&
            state['index'] == index &&
            state['correct'] != null) {
          state['index'] = index + 1;
          state['correct'] = null;
          state['text'] = '';
          state['order'] = <int>[];
          await _save(state);
        }
        return state;
      });
}
