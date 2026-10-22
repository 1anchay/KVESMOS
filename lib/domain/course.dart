class Vocabulary {
  final String id, en, ru;
  const Vocabulary(this.id, this.en, this.ru);
  factory Vocabulary.fromJson(Map<String, dynamic> j) =>
      Vocabulary(j['id'], j['en'], j['ru']);
}

enum ExerciseType {
  translate,
  choice,
  order,
  gap,
  listen,
  pairs,
  speak,
  correct,
  review,
  dialogue,
}

class Exercise {
  final String id, prompt, explanation;
  final ExerciseType type;
  final List<String> answers, options, tokens, wordIds;
  final List<Vocabulary> pairs;
  final String? audio;
  final String? scene, visual, introduction;
  final String character, phase;
  const Exercise({
    required this.id,
    required this.type,
    required this.prompt,
    required this.answers,
    required this.explanation,
    this.options = const [],
    this.tokens = const [],
    this.wordIds = const [],
    this.pairs = const [],
    this.audio,
    this.scene,
    this.visual,
    this.introduction,
    this.character = 'orbi',
    this.phase = '',
  });
  factory Exercise.fromJson(Map<String, dynamic> j) => Exercise(
    id: j['id'],
    type: ExerciseType.values.byName(j['type']),
    prompt: j['prompt'],
    answers: List<String>.from(j['answers']),
    explanation: j['explanation'],
    options: List<String>.from(j['options'] ?? []),
    tokens: List<String>.from(j['tokens'] ?? []),
    wordIds: List<String>.from(j['wordIds'] ?? []),
    audio: j['audio'],
    scene: j['scene'],
    visual: j['visual'],
    introduction: j['introduction'],
    character: j['character'] ?? 'orbi',
    phase: j['phase'] ?? '',
    pairs: (j['pairs'] as List? ?? [])
        .map((e) => Vocabulary.fromJson(e))
        .toList(),
  );
}

class Lesson {
  final String id, title, topic, guide;
  final int order;
  final List<Exercise> exercises;
  final List<Vocabulary> vocabulary;
  const Lesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.guide,
    required this.order,
    required this.exercises,
    required this.vocabulary,
  });
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'],
    title: j['title'],
    topic: j['topic'],
    guide: j['guide'],
    order: j['order'],
    exercises: (j['exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList(),
    vocabulary: (j['vocabulary'] as List)
        .map((e) => Vocabulary.fromJson(e))
        .toList(),
  );
}

class LessonInfo {
  final String id, title, topic, section, asset;
  final int order;
  const LessonInfo(
    this.id,
    this.title,
    this.topic,
    this.section,
    this.asset,
    this.order,
  );
}

String normalizeAnswer(String value) {
  var s = value.toLowerCase().replaceAll('’', "'").replaceAll('ё', 'е');
  for (final entry in {
    "i'm": "i am",
    "it's": "it is",
    "that's": "that is",
    "he's": "he is",
    "she's": "she is",
    "we're": "we are",
    "you're": "you are",
  }.entries) {
    s = s.replaceAll(RegExp('\\b${entry.key}\\b'), entry.value);
  }
  return s
      .replaceAll(RegExp(r'''[.,!?;:«»"—–]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool checkAnswer(Exercise exercise, String input) => exercise.answers.any(
  (answer) =>
      normalizeAnswer(input).isNotEmpty &&
      normalizeAnswer(input) == normalizeAnswer(answer),
);
