import 'dart:convert';
import '../domain/course.dart';
import '../domain/journey.dart';
import '../domain/progress.dart';
import 'repository.dart';

/// A small resumable practice presentation over the original word event ledger.
/// State and the graded answer commit together; retrying a button cannot replay it.
class PracticeRepository {
  static const key = 'kvesmos.practice.v1';
  String get storageKey =>
      learning.course.id == 'ru-en' ? key : '$key:${learning.course.id}';
  final LearningRepository learning;
  PracticeRepository(this.learning);
  Future<Map<String, dynamic>> open({bool restart = false}) =>
      learning.db.transaction(() async {
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
        final picks = personalPractice(
          learning.vocabulary.values,
          await learning.progress(),
          learning.now(),
        );
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
      await learning.review(word, input);
      state['credited'] =
          (state['credited'] as int) + (await learning.progress()).xp - before;
      state['correct'] = normalizeAnswer(input) == normalizeAnswer(word.en);
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
