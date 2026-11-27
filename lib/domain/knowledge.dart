import 'dart:math' as math;

import 'first_flight.dart';
import 'progress.dart';

enum KnowledgeKind { word, phrase, grammar, ability }

class KnowledgeSkill {
  const KnowledgeSkill(
    this.id,
    this.kind,
    this.title, {
    this.requires = const [],
    this.course = 'ru-en',
  });

  final String id, title, course;
  final KnowledgeKind kind;
  final List<String> requires;
}

class LexiconEntry {
  const LexiconEntry(
    this.skill,
    this.english,
    this.russian,
    this.ipa,
    this.example,
    this.exampleRu, {
    this.voice = 'orbi',
    this.legacyReview,
  });

  final KnowledgeSkill skill;
  final String english, russian, ipa, example, exampleRu, voice;
  final String? legacyReview;

  bool matches(String answer) => normalize(answer) == normalize(english);

  static String normalize(String text) => text
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[.!?]+$'), '')
      .replaceAll(RegExp(r'\s+'), ' ');
}

/// IDs identify a meaning, not a spelling. A future musical key needs its own ID.
abstract final class KnowledgeCatalog {
  static const flight = <FlightWord, LexiconEntry>{
    FlightWord.door: LexiconEntry(
      KnowledgeSkill('en:word:door:entrance', KnowledgeKind.word, 'Дверь'),
      'Door',
      'дверь',
      '/dɔɹ/',
      'Open the door.',
      'Открой дверь.',
      legacyReview: 'en:door',
    ),
    FlightWord.key: LexiconEntry(
      KnowledgeSkill('en:word:key:lock', KnowledgeKind.word, 'Ключ от замка'),
      'Key',
      'ключ',
      '/kiː/',
      'Use the key.',
      'Воспользуйся ключом.',
    ),
    FlightWord.battery: LexiconEntry(
      KnowledgeSkill('en:word:battery:power', KnowledgeKind.word, 'Батарея'),
      'Battery',
      'батарея',
      '/ˈbætəri/',
      'The battery is in the box.',
      'Батарея в ящике.',
    ),
    FlightWord.cable: LexiconEntry(
      KnowledgeSkill(
        'en:word:cable:power',
        KnowledgeKind.word,
        'Кабель питания',
      ),
      'Cable',
      'кабель',
      '/ˈkeɪbəl/',
      'Connect the cable.',
      'Подключи кабель.',
    ),
    FlightWord.light: LexiconEntry(
      KnowledgeSkill('en:word:light:illumination', KnowledgeKind.word, 'Свет'),
      'Light',
      'свет',
      '/laɪt/',
      'The light is on.',
      'Свет горит.',
    ),
    FlightWord.button: LexiconEntry(
      KnowledgeSkill(
        'en:word:button:control',
        KnowledgeKind.word,
        'Кнопка управления',
      ),
      'Button',
      'кнопка',
      '/ˈbʌtən/',
      'The button is green.',
      'Кнопка зелёная.',
    ),
    FlightWord.need: LexiconEntry(
      KnowledgeSkill(
        'en:phrase:need-battery',
        KnowledgeKind.phrase,
        'Просьба о батарее',
        requires: ['en:word:battery:power'],
      ),
      'I need a battery.',
      'Мне нужна батарея.',
      '/aɪ niːd ə ˈbætəri/',
      'I need a battery for the radio.',
      'Мне нужна батарея для рации.',
    ),
    FlightWord.press: LexiconEntry(
      KnowledgeSkill(
        'en:phrase:press-button',
        KnowledgeKind.phrase,
        'Команда нажать кнопку',
        requires: ['en:word:button:control'],
      ),
      'Press the button.',
      'Нажми на кнопку.',
      '/pɹɛs ðə ˈbʌtən/',
      'Press the button to call Orbi.',
      'Нажми на кнопку, чтобы позвать Орби.',
    ),
  };

  static const foundations = <KnowledgeSkill>[
    KnowledgeSkill(
      'en:grammar:i-need',
      KnowledgeKind.grammar,
      'I need + предмет',
      requires: ['en:grammar:word-order', 'en:grammar:articles'],
    ),
    KnowledgeSkill(
      'en:grammar:i-have',
      KnowledgeKind.grammar,
      'I have + предмет',
      requires: ['en:grammar:word-order', 'en:grammar:articles'],
    ),
    KnowledgeSkill(
      'en:grammar:pronouns',
      KnowledgeKind.grammar,
      'Личные местоимения',
    ),
    KnowledgeSkill(
      'en:grammar:word-order',
      KnowledgeKind.grammar,
      'Подлежащее, глагол и дополнение',
      requires: ['en:grammar:pronouns'],
    ),
    KnowledgeSkill(
      'en:grammar:be',
      KnowledgeKind.grammar,
      'Формы am, is и are',
      requires: ['en:grammar:pronouns'],
    ),
    KnowledgeSkill(
      'en:grammar:plural',
      KnowledgeKind.grammar,
      'Единственное и множественное число',
    ),
    KnowledgeSkill(
      'en:grammar:articles',
      KnowledgeKind.grammar,
      'Артикли a, an и the',
      requires: ['en:grammar:plural'],
    ),
    KnowledgeSkill(
      'en:grammar:adjectives',
      KnowledgeKind.grammar,
      'Прилагательные в описаниях',
      requires: ['en:grammar:be', 'en:grammar:word-order'],
    ),
    KnowledgeSkill(
      'en:grammar:prepositions',
      KnowledgeKind.grammar,
      'Предлоги места',
      requires: ['en:grammar:be', 'en:grammar:articles'],
    ),
    KnowledgeSkill(
      'en:grammar:have',
      KnowledgeKind.grammar,
      'Have и has',
      requires: ['en:grammar:word-order'],
    ),
    KnowledgeSkill(
      'en:grammar:there-is',
      KnowledgeKind.grammar,
      'There is и there are',
      requires: ['en:grammar:be', 'en:grammar:plural'],
    ),
    KnowledgeSkill(
      'en:grammar:present-simple',
      KnowledgeKind.grammar,
      'Present Simple',
      requires: ['en:grammar:word-order'],
    ),
    KnowledgeSkill(
      'en:grammar:questions',
      KnowledgeKind.grammar,
      'Простые вопросы',
      requires: ['en:grammar:be', 'en:grammar:present-simple'],
    ),
    KnowledgeSkill(
      'en:grammar:negation',
      KnowledgeKind.grammar,
      'Простые отрицания',
      requires: ['en:grammar:be', 'en:grammar:present-simple'],
    ),
    KnowledgeSkill(
      'en:grammar:present-continuous',
      KnowledgeKind.grammar,
      'Present Continuous',
      requires: ['en:grammar:be', 'en:grammar:word-order'],
    ),
    KnowledgeSkill('en:ability:reading', KnowledgeKind.ability, 'Чтение'),
    KnowledgeSkill(
      'en:ability:listening',
      KnowledgeKind.ability,
      'Аудирование',
    ),
    KnowledgeSkill('en:ability:writing', KnowledgeKind.ability, 'Письмо'),
    KnowledgeSkill('en:ability:speaking', KnowledgeKind.ability, 'Устная речь'),
  ];

  static const radio = <LexiconEntry>[
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:have-battery',
        KnowledgeKind.phrase,
        'Батарея у меня',
        requires: ['en:word:battery:power'],
      ),
      'I have a battery.',
      'У меня есть батарея.',
      '/aɪ hæv ə ˈbætəri/',
      'I have a battery for the receiver.',
      'У меня есть батарея для приёмника.',
      voice: 'miko',
    ),
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:is-ready',
        KnowledgeKind.phrase,
        'Готовность прибора',
      ),
      'It is ready.',
      'Он готов.',
      '/ɪt ɪz ˈɹɛdi/',
      'The receiver is ready.',
      'Приёмник готов.',
      voice: 'pixie',
    ),
  ];

  static const fishing = <LexiconEntry>[
    LexiconEntry(
      KnowledgeSkill('en:word:fish:animal', KnowledgeKind.word, 'Рыба'),
      'Fish',
      'рыба',
      '/fɪʃ/',
      'This is a fish.',
      'Это рыба.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:water:liquid', KnowledgeKind.word, 'Вода'),
      'Water',
      'вода',
      '/ˈwɔtər/',
      'The fish is in the water.',
      'Рыба в воде.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:rod:fishing', KnowledgeKind.word, 'Удочка'),
      'Rod',
      'удочка',
      '/rɑd/',
      'I need a rod.',
      'Мне нужна удочка.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:hook:fishing', KnowledgeKind.word, 'Крючок'),
      'Hook',
      'крючок',
      '/hʊk/',
      'I have a hook.',
      'У меня есть крючок.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:bait:fishing', KnowledgeKind.word, 'Приманка'),
      'Bait',
      'приманка',
      '/beɪt/',
      'Put bait on the hook.',
      'Насади приманку на крючок.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:line:fishing', KnowledgeKind.word, 'Леска'),
      'Line',
      'леска',
      '/laɪn/',
      'The line is tight.',
      'Леска натянута.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:catch:fishing', KnowledgeKind.word, 'Поймать'),
      'Catch',
      'поймать',
      '/kætʃ/',
      'Catch a fish.',
      'Поймай рыбу.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:wait:pause', KnowledgeKind.word, 'Ждать'),
      'Wait',
      'ждать',
      '/weɪt/',
      'Wait for the fish.',
      'Дождись рыбы.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:pull:draw', KnowledgeKind.word, 'Тянуть'),
      'Pull',
      'тянуть',
      '/pʊl/',
      'Pull the line.',
      'Потяни леску.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:small:size', KnowledgeKind.word, 'Маленький'),
      'Small',
      'маленький',
      '/smɔl/',
      'The fish is small.',
      'Рыба маленькая.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:big:size', KnowledgeKind.word, 'Большой'),
      'Big',
      'большой',
      '/bɪɡ/',
      'The fish is big.',
      'Рыба большая.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:river:waterway', KnowledgeKind.word, 'Река'),
      'River',
      'река',
      '/ˈrɪvər/',
      'The river is shallow.',
      'Река мелкая.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill('en:word:lake:waterbody', KnowledgeKind.word, 'Озеро'),
      'Lake',
      'озеро',
      '/leɪk/',
      'The lake is deep.',
      'Озеро глубокое.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:need-rod',
        KnowledgeKind.phrase,
        'Просьба об удочке',
        requires: ['en:word:rod:fishing'],
      ),
      'I need a rod.',
      'Мне нужна удочка.',
      '/aɪ nid ə rɑd/',
      'I need a rod.',
      'Мне нужна удочка.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:have-hook',
        KnowledgeKind.phrase,
        'Крючок у меня',
        requires: ['en:word:hook:fishing'],
      ),
      'I have a hook.',
      'У меня есть крючок.',
      '/aɪ hæv ə hʊk/',
      'I have a hook.',
      'У меня есть крючок.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:have-fish',
        KnowledgeKind.phrase,
        'У меня есть рыба',
        requires: ['en:word:fish:animal'],
      ),
      'I have a fish.',
      'У меня есть рыба.',
      '/aɪ hæv ə fɪʃ/',
      'I have a fish.',
      'У меня есть рыба.',
      voice: 'pixie',
    ),
    LexiconEntry(
      KnowledgeSkill(
        'en:phrase:this-is-fish',
        KnowledgeKind.phrase,
        'Это рыба',
        requires: ['en:word:fish:animal'],
      ),
      'This is a fish.',
      'Это рыба.',
      '/ðɪs ɪz ə fɪʃ/',
      'This is a fish.',
      'Это рыба.',
      voice: 'pixie',
    ),
  ];

  static final skills = Map<String, KnowledgeSkill>.unmodifiable({
    for (final entry in flight.values) entry.skill.id: entry.skill,
    for (final entry in radio) entry.skill.id: entry.skill,
    for (final entry in fishing) entry.skill.id: entry.skill,
    for (final skill in foundations) skill.id: skill,
  });

  static final lexicon = Map<String, LexiconEntry>.unmodifiable({
    for (final entry in flight.values) entry.skill.id: entry,
    for (final entry in radio) entry.skill.id: entry,
    for (final entry in fishing) entry.skill.id: entry,
  });

  static void validate(Map<String, KnowledgeSkill> graph) {
    final visited = <String>{};
    final path = <String>{};
    void visit(String id, String course) {
      if (path.contains(id)) throw FormatException('Цикл навыков: $id');
      final skill = graph[id];
      if (skill == null || skill.id != id || skill.course != course) {
        throw FormatException('Неизвестная зависимость: $id');
      }
      if (!visited.add(id)) return;
      path.add(id);
      for (final dependency in skill.requires) {
        visit(dependency, course);
      }
      path.remove(id);
    }

    for (final entry in graph.entries) {
      visit(entry.key, entry.value.course);
    }
  }
}

enum ImmersionMode {
  beginner('Начальный'),
  adaptive('Адаптивный'),
  extended('Расширенный');

  const ImmersionMode(this.label);
  final String label;
}

enum KnowledgeStage {
  introduced('Знакомство'),
  recognized('Узнаю'),
  recalled('Вспоминаю'),
  applied('Применяю');

  const KnowledgeStage(this.label);
  final String label;
}

enum KnowledgeCheck { recognition, recall, transfer }

enum KnowledgeError { meaning, spelling, grammar, form }

class ImmersionPolicy {
  const ImmersionPolicy({
    this.spacing = const Duration(days: 1),
    this.recallDays = 2,
    this.transferContexts = 2,
  });
  final Duration spacing;
  final int recallDays, transferContexts;
}

class KnowledgeState {
  KnowledgeState(this.skill);
  final KnowledgeSkill skill;
  DateTime? firstSeen, lastSeen, lastPractice;
  int attempts = 0, independent = 0, assisted = 0;
  final errors = <KnowledgeError, int>{};
  final contexts = <String>{};
  final review = WordProgress();
  bool favorite = false, difficult = false;
  final _passes = <(DateTime, KnowledgeCheck, String)>[];
  bool _neededHelp = false;

  double get confidence =>
      math.min(1, _passes.map((p) => dayKey(p.$1)).toSet().length / 3);
  DateTime? get nextReview => review.next;

  bool _isSpaced(ImmersionPolicy policy) =>
      _passes.isNotEmpty &&
      _passes.last.$1.difference(_passes.first.$1) >= policy.spacing &&
      _passes.map((p) => dayKey(p.$1)).toSet().length >= policy.recallDays;

  KnowledgeStage stage([ImmersionPolicy policy = const ImmersionPolicy()]) {
    if (_passes.isEmpty || difficult) return KnowledgeStage.introduced;
    if (_neededHelp) return KnowledgeStage.recognized;
    final production = _passes.any((p) => p.$2 != KnowledgeCheck.recognition);
    if (!production || !_isSpaced(policy)) return KnowledgeStage.recognized;
    final contexts = _passes.map((p) => p.$3).toSet();
    return contexts.length >= policy.transferContexts &&
            _passes.any((p) => p.$2 == KnowledgeCheck.transfer)
        ? KnowledgeStage.applied
        : KnowledgeStage.recalled;
  }

  String label(LexiconEntry entry, ImmersionMode mode, {String? translation}) {
    final ru = translation ?? entry.russian;
    if (firstSeen == null) return ru;
    final level = stage();
    if (mode == ImmersionMode.beginner ||
        level == KnowledgeStage.introduced ||
        _neededHelp) {
      return '$ru · ${entry.english}';
    }
    if (level == KnowledgeStage.recognized &&
        (mode != ImmersionMode.extended ||
            !_isSpaced(const ImmersionPolicy()))) {
      return '${entry.english} · $ru';
    }
    return entry.english;
  }

  void _meet(DateTime at) {
    firstSeen ??= at;
    lastSeen = at;
  }

  void _check(
    DateTime at,
    KnowledgeCheck check,
    String context,
    bool success,
    bool help,
    KnowledgeError? error,
    ReviewHistory history,
  ) {
    _meet(at);
    attempts++;
    lastPractice = at;
    contexts.add(context);
    _neededHelp = help;
    if (!success) {
      errors.update(error!, (n) => n + 1, ifAbsent: () => 1);
      _passes.clear();
      difficult = true;
      history.add(false, at);
    } else if (help) {
      assisted++;
    } else {
      independent++;
      difficult = false;
      _passes.add((at, check, context));
      history.add(true, at);
    }
  }
}

class KnowledgeSnapshot {
  KnowledgeSnapshot(this.states);
  final Map<String, KnowledgeState> states;
  KnowledgeState of(KnowledgeSkill skill) =>
      states[skill.id] ?? KnowledgeState(skill);

  factory KnowledgeSnapshot.fromEvents(
    Iterable<LearningEvent> input,
    String course,
  ) {
    final events =
        {
          for (final e in input.where((e) => e.courseId == course)) e.id: e,
        }.values.toList()..sort((a, b) {
          final byTime = DateTime.parse(
            a.occurredAt,
          ).compareTo(DateTime.parse(b.occurredAt));
          if (byTime != 0) return byTime;
          // If two observations share a timestamp, process the error last.
          final byOutcome = (a.data['correct'] == false ? 1 : 0).compareTo(
            b.data['correct'] == false ? 1 : 0,
          );
          return byOutcome == 0 ? a.id.compareTo(b.id) : byOutcome;
        });
    final states = <String, KnowledgeState>{};
    final reviews = <String, ReviewHistory>{};
    for (final e in events) {
      final d = e.data;
      // Existing single-word reviews with a confirmed sense are usable evidence.
      final legacy = e.kind == 'answer' && d['evidence'] != false
          ? KnowledgeCatalog.flight.values
                .where(
                  (entry) =>
                      entry.legacyReview != null &&
                      d['exercise'] == 'review:${entry.legacyReview}' &&
                      d['words'] is List &&
                      (d['words'] as List).length == 1 &&
                      (d['words'] as List).single == entry.legacyReview,
                )
                .firstOrNull
          : null;
      if (e.kind != 'knowledge' && legacy == null) continue;
      final id = legacy?.skill.id ?? d['knowledgeId'];
      final skill = KnowledgeCatalog.skills[id];
      if (skill == null || skill.course != course) continue;
      final at = DateTime.parse(e.occurredAt).toUtc();
      final s = states.putIfAbsent(skill.id, () => KnowledgeState(skill));
      if (legacy != null || d['observation'] == 'check') {
        final correct = d['correct'] == true;
        s._check(
          at,
          legacy != null
              ? KnowledgeCheck.recognition
              : KnowledgeCheck.values.byName(d['check'] as String),
          legacy != null ? 'course-review' : d['context'] as String,
          correct,
          d['assisted'] == true,
          correct
              ? null
              : legacy != null
              ? KnowledgeError.meaning
              : KnowledgeError.values.byName(d['error'] as String),
          reviews.putIfAbsent(skill.id, ReviewHistory.new),
        );
      } else if (d['observation'] == 'encounter') {
        s._meet(at);
      } else if (d['observation'] == 'favorite') {
        s.favorite = d['favorite'] == true;
      }
    }
    for (final e in reviews.entries) {
      e.value.apply(states[e.key]!.review);
    }
    return KnowledgeSnapshot(Map.unmodifiable(states));
  }

  List<KnowledgeState> practice(DateTime now) {
    final seen = states.values
        .where(
          (s) =>
              s.firstSeen != null &&
              KnowledgeCatalog.lexicon.containsKey(s.skill.id),
        )
        .toList();
    seen.sort((a, b) {
      int priority(KnowledgeState s) => s.difficult
          ? 0
          : s.nextReview?.isAfter(now) == false
          ? 1
          : s.nextReview == null
          ? 2
          : 3;
      final rank = priority(a).compareTo(priority(b));
      if (rank != 0) return rank;
      final due = (a.nextReview ?? a.firstSeen!).compareTo(
        b.nextReview ?? b.firstSeen!,
      );
      return due != 0 ? due : a.skill.id.compareTo(b.skill.id);
    });
    return seen;
  }

  /// English-only lines require evidence for the construction itself.
  bool canUseEnglishSentence(Iterable<KnowledgeSkill> skills) {
    final required = skills.toList();
    return required.any((s) => s.kind == KnowledgeKind.grammar) &&
        required.every(
          (s) => of(s).stage().index >= KnowledgeStage.recalled.index,
        );
  }
}
