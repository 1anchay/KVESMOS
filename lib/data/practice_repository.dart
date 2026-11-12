import 'dart:convert';
import '../domain/course.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import 'repository.dart';

enum PracticeMode { warmup, words, listen, speak, mistakes, dialogue }

/// A small resumable practice presentation over the original word event ledger.
/// State and the graded answer commit together; retrying a button cannot replay it.
class PracticeRepository {
  static const key = 'kvesmos.practice.v1';
  final PracticeMode mode;
  final String courseId;
  final List<String> lessonIds;
  String get storageKey {
    final base = courseId == 'ru-en' ? key : '$key:$courseId';
    final modeKey = mode == PracticeMode.warmup ? base : '$base:${mode.name}';
    return lessonIds.isEmpty ? modeKey : '$modeKey:unit:${lessonIds.join(',')}';
  }

  final LearningRepository learning;
  PracticeRepository(
    this.learning, {
    this.mode = PracticeMode.warmup,
    this.lessonIds = const [],
  }) : courseId = learning.course.id;

  Future<Map<String, String>> dialogueContexts() async {
    final progress = await learning.progress();
    final result = <String, String>{};
    for (final info in learning.catalog.where(
      (l) => progress.completed.contains(l.id),
    )) {
      if (!(await learning.installed()).contains(info.id)) continue;
      final lesson = (await learning.previewLesson(info.id)).lesson;
      for (final e in lesson.exercises.where((e) => e.scene != null)) {
        for (final word in lesson.vocabulary.where(
          (w) => progress.words.containsKey(w.id),
        )) {
          if (e.scene!.contains(word.en)) result[word.id] = e.scene!;
        }
      }
    }
    return result;
  }

  Future<Map<String, dynamic>> open({bool restart = false}) =>
      learning.db.transaction(() async {
        if (learning.course.id != courseId) throw StateError('Course changed');
        final saved = await learning.setting(storageKey);
        if (saved != null && !restart) {
          final state = Map<String, dynamic>.from(jsonDecode(saved));
          final words = List<String>.from(state['words']);
          // Keep unfinished practice across dates. Refresh an empty queue when
          // learning creates due words, and a completed queue on a new day.
          if ((state['index'] as int) < words.length ||
              words.isNotEmpty && state['day'] == dayKey(learning.now())) {
            return state;
          }
        }
        final progress = await learning.progress();
        final allowed = <String>{};
        for (final id in lessonIds.where(progress.completed.contains)) {
          final lesson = (await learning.previewLesson(id)).lesson;
          allowed.addAll(lesson.vocabulary.map((w) => w.id));
        }
        final masteryWords = <String>{};
        final masterySettings = await learning.settingsWithPrefix(
          'kvesmos.mastery.v1:$courseId:',
        );
        for (final entry in masterySettings.entries.where(
          (e) => e.key.endsWith(':difficult'),
        )) {
          masteryWords.addAll(List<String>.from(jsonDecode(entry.value)));
        }
        var picks = personalPractice(
          learning.vocabulary.values,
          progress,
          learning.now(),
          limit: mode == PracticeMode.warmup ? 3 : learning.vocabulary.length,
        );
        if (mode != PracticeMode.warmup) {
          final contexts = mode == PracticeMode.dialogue
              ? await dialogueContexts()
              : <String, String>{};
          final due = {for (final p in picks) p.word.id: p};
          final known =
              learning.vocabulary.values
                  .where(
                    (w) =>
                        progress.words.containsKey(w.id) &&
                        (lessonIds.isEmpty || allowed.contains(w.id)),
                  )
                  .toList()
                ..sort((a, b) {
                  final first = (due.containsKey(b.id) ? 1 : 0).compareTo(
                    due.containsKey(a.id) ? 1 : 0,
                  );
                  if (first != 0) return first;
                  final weak = (masteryWords.contains(b.id) ? 1 : 0).compareTo(
                    masteryWords.contains(a.id) ? 1 : 0,
                  );
                  if (weak != 0) return weak;
                  final oldest = (progress.words[a.id]!.last ?? DateTime(2000))
                      .compareTo(progress.words[b.id]!.last ?? DateTime(2000));
                  return oldest != 0 ? oldest : a.id.compareTo(b.id);
                });
          picks = known
              .where(
                (w) =>
                    (mode != PracticeMode.mistakes ||
                        (masteryWords.contains(w.id) ||
                            progress.words[w.id]!.errors > 0 &&
                                progress.words[w.id]!.repetitions == 0)) &&
                    (mode != PracticeMode.dialogue ||
                        contexts.containsKey(w.id)),
              )
              .take(lessonIds.isEmpty ? 6 : 12)
              .map(
                (w) =>
                    due[w.id] ??
                    PracticePick(
                      w,
                      masteryWords.contains(w.id)
                          ? 'Эта реплика вызвала трудность в проверке темы.'
                          : 'Давно не возвращались к этой знакомой реплике.',
                    ),
              )
              .toList();
        }
        final state = <String, dynamic>{
          'day': dayKey(learning.now()),
          'words': [for (final p in picks) p.word.id],
          'reasons': [for (final p in picks) p.reason],
          'index': 0,
          'phase': 0,
          'attempt': 0,
          'correct': null,
          'credited': 0,
          'text': '',
        };
        await save(state);
        return state;
      });
  Future<void> save(Map<String, dynamic> state) =>
      learning.setSetting(storageKey, jsonEncode(state));
  Future<void> draft(int index, String text) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] == index && state['phase'] == 1) {
          state['text'] = text;
          await save(state);
        }
      });
  Future<Map<String, dynamic>> advance(
    int expectedIndex,
    int expectedPhase,
    String input,
  ) => learning.db.transaction(() async {
    final state = await open();
    if (state['index'] != expectedIndex || state['phase'] != expectedPhase) {
      return state;
    }
    final ids = List<String>.from(state['words']);
    if (expectedIndex >= ids.length) return state;
    final word = learning.vocabulary[ids[expectedIndex]]!;
    if (expectedPhase == 0) {
      state['phase'] = 1;
    } else if (expectedPhase == 1) {
      final before = (await learning.progress()).xp;
      final canonical =
          word.pronunciation != null &&
              normalizeAnswer(input) == normalizeAnswer(word.pronunciation!)
          ? word.en
          : input;
      await learning.review(word, canonical);
      state['credited'] =
          (state['credited'] as int) + (await learning.progress()).xp - before;
      state['correct'] = normalizeAnswer(canonical) == normalizeAnswer(word.en);
      if (state['correct'] == true) {
        final entries = await learning.settingsWithPrefix(
          'kvesmos.mastery.v1:$courseId:',
        );
        for (final entry in entries.entries.where(
          (e) => e.key.endsWith(':difficult'),
        )) {
          final difficult = List<String>.from(jsonDecode(entry.value));
          if (difficult.remove(word.id)) {
            await learning.setSetting(entry.key, jsonEncode(difficult));
          }
        }
      }
      state['phase'] = 2;
      state['text'] = input;
      state['attempt'] = (state['attempt'] as int) + 1;
    } else if (state['correct'] == true) {
      state['index'] = expectedIndex + 1;
      state['phase'] = 0;
      state['attempt'] = 0;
      state['text'] = '';
    } else {
      state['phase'] = 1;
      state['text'] = '';
    }
    await save(state);
    return state;
  });
}
