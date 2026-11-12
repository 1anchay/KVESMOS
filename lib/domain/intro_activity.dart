import 'course.dart';

/// Ungraded, guided actions. Kept separate from scored exercises and their draft.
class IntroActivity {
  final String id, phrase, translation, prompt, answer, explanation, character;
  final String? pronunciation;
  final List<String> options, tokens;
  const IntroActivity({
    required this.id,
    required this.phrase,
    required this.translation,
    required this.prompt,
    required this.answer,
    required this.explanation,
    this.character = 'orbi',
    this.pronunciation,
    this.options = const [],
    this.tokens = const [],
  });
  factory IntroActivity.fromJson(Map<String, dynamic> j) => IntroActivity(
    id: j['id'],
    phrase: j['phrase'],
    translation: j['translation'],
    prompt: j['prompt'],
    answer: j['answer'],
    explanation: j['explanation'],
    character: j['character'] ?? 'orbi',
    pronunciation: j['pronunciation'],
    options: List<String>.from(j['options'] ?? []),
    tokens: List<String>.from(j['tokens'] ?? []),
  );

  /// Old, pinned JSON remains immutable. Teach two examples, then apply them.
  static List<IntroActivity> fromTeaching(List<LessonTeachingStep> steps) {
    return [for (var i = 0; i < steps.length && i < 2; i++) _convert(steps, i)];
  }

  static IntroActivity _convert(List<LessonTeachingStep> steps, int i) {
    final s = steps[i];
    final words = s.phrase.split(RegExp(r'\s+'));
    final assemble = i > 0 && words.length >= 2 && words.length <= 8;
    final meanings = {
      s.translation,
      ...steps.map((s) => s.translation),
    }.take(3).toList();
    // A single legacy example still permits a meaningful reconstruction.
    final tokens = assemble || meanings.length < 2 ? words : <String>[];
    if (tokens.isEmpty && meanings.length > 1) {
      final first = meanings.removeAt(0);
      meanings.insert((i + 1) % (meanings.length + 1), first);
    }
    return IntroActivity(
      id: 'legacy-$i',
      phrase: s.phrase,
      translation: s.translation,
      prompt: tokens.isEmpty
          ? 'Выбери смысл реплики'
          : 'Собери реплику по образцу',
      answer: tokens.isEmpty ? s.translation : s.phrase,
      explanation: s.explanation
          .split('\n')
          .first
          .split(RegExp(r'(?<=[.!?])\s+'))
          .first,
      character: s.character,
      pronunciation: s.pronunciation,
      options: tokens.isEmpty ? meanings : const [],
      tokens: tokens,
    );
  }
}

/// Each action is durable before the UI acknowledges it. No answer events/XP.
class IntroDraft {
  final int index;
  final Map<String, dynamic> actions;
  const IntroDraft({this.index = 0, this.actions = const {}});
  factory IntroDraft.fromJson(Map<String, dynamic> j) => IntroDraft(
    index: j['index'] is int ? j['index'] : 0,
    actions: Map<String, dynamic>.from(j['actions'] ?? {}),
  );
  Map<String, dynamic> toJson() => {'index': index, 'actions': actions};
}
