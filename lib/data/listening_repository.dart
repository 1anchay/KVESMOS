import 'dart:convert';
import 'package:uuid/uuid.dart';

import '../domain/study_skills.dart';
import 'conversation_repository.dart';
import 'repository.dart';

typedef ListeningLine = ({String character, DialogueLine line});
typedef ListeningQuestion = ({
  String prompt,
  String correct,
  List<String> options,
  String explanation,
});

class ListeningScene {
  final String language, id, title;
  final List<ListeningLine> lines;
  final List<ListeningQuestion> questions;
  const ListeningScene(
    this.language,
    this.id,
    this.title,
    this.lines,
    this.questions,
  );

  static List<ListeningScene> parse(String source) =>
      source.split('##').skip(1).map((block) {
        final rows = block.trim().split(RegExp(r'\r?\n'));
        final [language, id, title] = rows.first.split('|');
        final lines = <ListeningLine>[];
        final questions = <ListeningQuestion>[];
        for (final row in rows.skip(1)) {
          final fields = row.split('|');
          if (fields.length == 5) {
            final options = fields.sublist(1, 4);
            final shift = (id.length + questions.length) % options.length;
            questions.add((
              prompt: fields[0],
              correct: fields[1],
              options: [...options.skip(shift), ...options.take(shift)],
              explanation: fields[4],
            ));
          } else {
            lines.add((
              character: fields[0],
              line: (
                text: fields[1],
                meaning: fields[2],
                pronunciation: fields.length == 4 ? fields[3] : null,
              ),
            ));
          }
        }
        if (lines.isEmpty || lines.length > 3 || questions.length != 2) {
          throw const FormatException('Invalid listening scene');
        }
        return ListeningScene(language, id, title, lines, questions);
      }).toList();
}

class ListeningRepository {
  final LearningRepository learning;
  final String courseId;
  final ListeningScene scene;
  ListeningRepository(this.learning, this.scene)
    : courseId = learning.course.id;
  String get key => 'kvesmos.listening.v1:$courseId:${scene.id}';

  Future<Map<String, dynamic>> open({bool restart = false}) async {
    if (learning.course.id != courseId ||
        scene.language != learning.course.language) {
      throw StateError('Курс изменился.');
    }
    final raw = await learning.setting(key);
    if (raw != null && !restart) {
      return Map<String, dynamic>.from(jsonDecode(raw));
    }
    final state = <String, dynamic>{
      'run': const Uuid().v4(),
      'index': 0,
      'score': 0,
      'checked': false,
      'correct': false,
      'heard': false,
      'reading': false,
      'assisted': false,
    };
    await _save(state);
    return state;
  }

  Future<void> _save(Map<String, dynamic> state) =>
      learning.setSetting(key, jsonEncode(state));

  Future<Map<String, dynamic>> source({
    bool heard = false,
    bool reading = false,
  }) => learning.db.transaction(() async {
    final state = await open();
    if (reading) state['reading'] = true;
    if (heard && !reading) state['heard'] = true;
    await _save(state);
    return state;
  });

  Future<Map<String, dynamic>> answer(int index, String option) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] != index ||
            state['checked'] == true ||
            state['heard'] != true && state['reading'] != true) {
          return state;
        }
        final question = scene.questions[index];
        if (!question.options.contains(option)) return state;
        final correct = option == question.correct;
        final evidence =
            state['heard'] == true &&
            state['reading'] != true &&
            state['assisted'] != true;
        if (evidence) {
          await learning.recordPractice(
            courseId: courseId,
            sessionId: state['run'],
            itemId: '${scene.id}:$index',
            skill: StudySkill.listening,
            correct: correct,
          );
        }
        if (correct && state['assisted'] != true) {
          state['score'] = (state['score'] as int) + 1;
        }
        state['checked'] = true;
        state['correct'] = correct;
        if (!correct) state['assisted'] = true;
        await _save(state);
        return state;
      });

  Future<Map<String, dynamic>> advance(int index, {bool retry = false}) =>
      learning.db.transaction(() async {
        final state = await open();
        if (state['index'] != index || state['checked'] != true) return state;
        if (!retry || state['correct'] == true) {
          state['index'] = index + 1;
          state['assisted'] = false;
        }
        state['checked'] = false;
        state['correct'] = false;
        await _save(state);
        return state;
      });
}
