import 'dart:convert';
import 'package:flutter/services.dart';
import '../domain/course.dart';
import 'repository.dart';

typedef DialogueLine = ({String text, String meaning, String? pronunciation});
typedef DialoguePath = ({
  DialogueLine request,
  DialogueLine reply,
  DialogueLine confirmation,
  DialogueLine farewell,
  DialogueLine closing,
});

class Conversation {
  final String language, id, title, goal, prerequisite;
  final DialogueLine opening;
  final List<DialoguePath> paths;
  const Conversation(
    this.language,
    this.id,
    this.title,
    this.goal,
    this.prerequisite,
    this.opening,
    this.paths,
  );

  static Future<List<Conversation>> load() async {
    final source = await rootBundle.loadString(
      'assets/learning/conversations.txt',
    );
    return source.split('##').skip(1).map((block) {
      final lines = block.trim().split(RegExp(r'\r?\n'));
      final meta = lines.first.split('|');
      if (meta.length != 5 || lines.length != 12) {
        throw const FormatException('Invalid conversation asset');
      }
      DialogueLine line(int i) {
        final parts = lines[i].split('|');
        return (
          text: parts[0],
          meaning: parts[1],
          pronunciation: parts.length > 2 ? parts[2] : null,
        );
      }

      return Conversation(
        meta[0],
        meta[1],
        meta[2],
        meta[3],
        meta[4],
        line(1),
        [
          for (final i in [2, 7])
            (
              request: line(i),
              reply: line(i + 1),
              confirmation: line(i + 2),
              farewell: line(i + 3),
              closing: line(i + 4),
            ),
        ],
      );
    }).toList();
  }
}

class ConversationRepository {
  final LearningRepository learning;
  final Conversation scene;
  final String courseId;
  ConversationRepository(this.learning, this.scene)
    : courseId = learning.course.id;
  String get key => 'kvesmos.conversation.v1:$courseId:${scene.id}';

  Future<Map<String, dynamic>> open() async {
    if (learning.course.id != courseId ||
        learning.course.language != scene.language ||
        !(await learning.progress()).completed.contains(scene.prerequisite)) {
      throw StateError('Сначала заверши связанный урок.');
    }
    final raw = await learning.setting(key);
    return raw == null
        ? {'step': 0, 'branch': 0, 'error': false, 'text': ''}
        : Map<String, dynamic>.from(jsonDecode(raw));
  }

  Future<void> draft(String text) => learning.db.transaction(() async {
    final state = await open();
    if (state['step'] != 2) return;
    state['text'] = text;
    await learning.setSetting(key, jsonEncode(state));
  });

  Future<Map<String, dynamic>> advance(
    int expectedStep,
    String answer,
  ) => learning.db.transaction(() async {
    final state = await open();
    if (state['step'] != expectedStep ||
        expectedStep > 2 ||
        answer.trim().isEmpty) {
      return state;
    }
    if (expectedStep == 0) {
      final branch = scene.paths.indexWhere((p) => p.request.text == answer);
      if (branch < 0) return state;
      state['branch'] = branch;
      state['step'] = 1;
    } else {
      final path = scene.paths[state['branch']];
      final target = expectedStep == 1 ? path.confirmation : path.farewell;
      final typed = normalizeAnswer(answer);
      final correct =
          typed == normalizeAnswer(target.text) ||
          target.pronunciation != null &&
              typed.replaceAll(' ', '') ==
                  normalizeAnswer(target.pronunciation!).replaceAll(' ', '');
      state['error'] = !correct;
      if (correct) {
        state['step'] = expectedStep + 1;
        state['text'] = '';
      } else if (expectedStep == 2) {
        state['text'] = answer;
      }
    }
    await learning.setSetting(key, jsonEncode(state));
    return state;
  });

  Future<void> restart() => learning.db.transaction(() async {
    final state = await open();
    if (state['step'] == 3) {
      await learning.setSetting(
        key,
        jsonEncode({'step': 0, 'branch': 0, 'error': false, 'text': ''}),
      );
    }
  });
}
