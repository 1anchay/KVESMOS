/// A tiny teaching beat before the learner is asked to recall the phrase.
class LessonTeachingStep {
  final String character, title, phrase, translation, explanation;
  final String? pronunciation;
  const LessonTeachingStep({
    required this.character,
    required this.title,
    required this.phrase,
    required this.translation,
    required this.explanation,
    this.pronunciation,
  });

  factory LessonTeachingStep.fromJson(Map<String, dynamic> json) =>
      LessonTeachingStep(
        character: json['character'],
        title: json['title'],
        phrase: json['phrase'],
        translation: json['translation'],
        explanation: json['explanation'],
        pronunciation: json['pronunciation'],
      );
}

class Vocabulary {
  final String id, en, ru;
  final String? pronunciation;
  const Vocabulary(this.id, this.en, this.ru, [this.pronunciation]);
  factory Vocabulary.fromJson(Map<String, dynamic> j) =>
      Vocabulary(j['id'], j['en'], j['ru'], j['pronunciation']);
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

/// A short narrative spans normal exercise steps; the existing session/draft
/// owns persistence and scoring, so stories cannot award XP a second time.
class StoryBeat {
  final String id, title;
  final String success, support, recovered;
  final int step, total;
  const StoryBeat(
    this.id,
    this.title,
    this.step,
    this.total, {
    this.success = 'We are ready for the next step!',
    this.support = 'Take your time. I am here to help.',
    this.recovered = 'We found the answer together!',
  });
  factory StoryBeat.fromJson(Map<String, dynamic> j) => StoryBeat(
    j['id'],
    j['title'],
    j['step'],
    j['total'],
    success: j['success'] ?? 'We are ready for the next step!',
    support: j['support'] ?? 'Take your time. I am here to help.',
    recovered: j['recovered'] ?? 'We found the answer together!',
  );
}

class Exercise {
  final String id, prompt, explanation;
  final ExerciseType type;
  final List<String> answers, options, tokens, wordIds;
  final List<Vocabulary> pairs;
  final String? audio, hint;
  final String? pronunciation;
  final String? scene, scenePronunciation, visual, introduction;
  final String character, phase;
  final StoryBeat? story;
  final Map<String, String>? recall;
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
    this.hint,
    this.pronunciation,
    this.scene,
    this.scenePronunciation,
    this.visual,
    this.introduction,
    this.character = 'orbi',
    this.phase = '',
    this.story,
    this.recall,
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
    hint: j['hint'],
    pronunciation: j['pronunciation'],
    scene: j['scene'],
    scenePronunciation: j['scenePronunciation'],
    visual: j['visual'],
    introduction: j['introduction'],
    character: j['character'] ?? 'orbi',
    phase: j['phase'] ?? '',
    story: j['story'] == null ? null : StoryBeat.fromJson(j['story']),
    recall: j['recall'] == null ? null : Map<String, String>.from(j['recall']),
    pairs: (j['pairs'] as List? ?? [])
        .map((e) => Vocabulary.fromJson(e))
        .toList(),
  );
}

class Lesson {
  final String id, title, topic, guide;
  final String? objective;
  final int order;
  final List<Exercise> exercises;
  final List<Vocabulary> vocabulary;
  final List<LessonTeachingStep> teachingSteps;
  const Lesson({
    required this.id,
    required this.title,
    required this.topic,
    required this.guide,
    required this.order,
    required this.exercises,
    required this.vocabulary,
    this.teachingSteps = const [],
    this.objective,
  });
  factory Lesson.fromJson(Map<String, dynamic> j) => Lesson(
    id: j['id'],
    title: j['title'],
    topic: j['topic'],
    guide: j['guide'],
    objective: j['objective'],
    order: j['order'],
    exercises: (j['exercises'] as List)
        .map((e) => Exercise.fromJson(e))
        .toList(),
    vocabulary: (j['vocabulary'] as List)
        .map((e) => Vocabulary.fromJson(e))
        .toList(),
    teachingSteps: (j['teachingSteps'] as List? ?? [])
        .map((e) => LessonTeachingStep.fromJson(Map<String, dynamic>.from(e)))
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
  s = s
      .replaceAll(RegExp(r'''[.,!?¿¡;:«»"—–。！？，、：；“”]'''), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  // Hanzi has no word-space requirement. Tone marks and French accents stay
  // meaningful; apostrophes remain part of the word.
  if (RegExp(r'[\u3400-\u9fff]').hasMatch(s) && !RegExp(r'[a-z]').hasMatch(s)) {
    s = s.replaceAll(' ', '');
  }
  return s;
}

bool checkAnswer(Exercise exercise, String input) => exercise.answers.any(
  (answer) =>
      normalizeAnswer(input).isNotEmpty &&
      normalizeAnswer(input) == normalizeAnswer(answer),
);
