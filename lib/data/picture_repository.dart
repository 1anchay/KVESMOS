import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/course.dart';
import 'repository.dart';

class PictureWord {
  final String id, meaning;
  final String? prerequisite;
  final List<String> forms, pinyin;
  final Vocabulary word;
  PictureWord(Map<String, dynamic> json, String language)
    : this._(
        json,
        Map<String, dynamic>.from(json['languages'][language]),
        language,
      );
  PictureWord._(
    Map<String, dynamic> json,
    Map<String, dynamic> local,
    String language,
  ) : id = json['id'],
      meaning = json['meaning'],
      prerequisite = local['lesson'],
      forms = List<String>.from(local['forms']),
      pinyin = List<String>.from(local['pinyin'] ?? []),
      word = Vocabulary(
        local['wordId'] ?? '$language:picture:${json['id']}',
        (local['forms'] as List).first,
        json['meaning'],
        (local['pinyin'] as List?)?.first,
      );

  String bare(String text) => normalizeAnswer(
    text,
  ).replaceFirst(RegExp(r"^(el |la |der |die |das |le |l')"), '');
  bool accepts(String input) {
    final text = normalizeAnswer(input);
    return text.isNotEmpty &&
        (forms.any(
              (form) => normalizeAnswer(form) == text || bare(form) == text,
            ) ||
            pinyin.any(
              (form) =>
                  normalizeAnswer(form).replaceAll(' ', '') ==
                  text.replaceAll(' ', ''),
            ));
  }
}

class PictureRepository {
  final LearningRepository learning;
  final String courseId, language;
  PictureRepository(this.learning)
    : courseId = learning.course.id,
      language = learning.course.language;
  String get key => 'kvesmos.picture.v1:$courseId';
  late final Future<Map<String, PictureWord>> cards = _load();
  Future<Map<String, PictureWord>> _load() async => {
    for (final json
        in jsonDecode(
              await rootBundle.loadString('assets/learning/pictures.json'),
            )
            as List)
      json['id'] as String: PictureWord(
        Map<String, dynamic>.from(json),
        language,
      ),
  };

  Future<Map<String, dynamic>> open({bool restart = false}) async {
    final words = await cards;
    return learning.db.transaction(() async {
      if (learning.course.id != courseId) throw StateError('Курс изменился');
      final saved = await learning.setting(key);
      if (saved != null && !restart) {
        final state = Map<String, dynamic>.from(jsonDecode(saved));
        if ((state['ids'] as List).isNotEmpty) return state;
      }
      final progress = await learning.progress();
      final now = learning.now().toUtc();
      final known =
          words.values
              .where((w) => progress.completed.contains(w.prerequisite))
              .toList()
            ..sort((a, b) {
              final x = progress.words[a.word.id]?.next,
                  y = progress.words[b.word.id]?.next;
              final rank = (x == null || !x.isAfter(now) ? 0 : 1).compareTo(
                y == null || !y.isAfter(now) ? 0 : 1,
              );
              if (rank != 0) return rank;
              return (x ?? DateTime.utc(2000)).compareTo(
                y ?? DateTime.utc(2000),
              );
            });
      final state = <String, dynamic>{
        'ids': known.take(6).map((w) => w.id).toList(),
        'index': 0,
        'text': '',
        'checked': false,
        'correct': false,
        'score': 0,
      };
      await _save(state);
      return state;
    });
  }

  Future<void> _save(Map<String, dynamic> state) =>
      learning.setSetting(key, jsonEncode(state));
  Future<void> draft(int index, String text) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] == index && state['checked'] == false) {
          state['text'] = text;
          await _save(state);
        }
      });

  Future<Map<String, dynamic>> advance(int index, bool checked, String text) =>
      learning.db.transaction(() async {
        final state = await open();
        final ids = List<String>.from(state['ids']);
        if (state['index'] != index ||
            state['checked'] != checked ||
            index >= ids.length) {
          return state;
        }
        if (checked) {
          state['index'] = index + 1;
          state['checked'] = false;
          state['text'] = '';
        } else if (text.trim().isNotEmpty) {
          final word = (await cards)[ids[index]]!;
          final correct = word.accepts(text);
          await learning.review(
            word.word,
            correct ? word.word.en : text,
            credit: false,
          );
          state['correct'] = correct;
          state['checked'] = true;
          state['text'] = text;
          if (correct) state['score'] = (state['score'] as int) + 1;
        }
        await _save(state);
        return state;
      });
}
