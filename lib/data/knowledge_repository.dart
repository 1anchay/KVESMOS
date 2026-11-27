import '../domain/knowledge.dart';
import '../domain/progress.dart';
import 'repository.dart';

class KnowledgeRepository {
  KnowledgeRepository(this.learning, {this.course = 'ru-en'});
  final LearningRepository learning;
  final String course;
  static const modePrefix = 'kvesmos.immersion.mode.v1:';
  String get modeKey => '$modePrefix$course';

  Future<ImmersionMode> mode() async {
    final saved = await learning.setting(modeKey);
    return ImmersionMode.values.where((m) => saved == m.name).firstOrNull ??
        ImmersionMode.adaptive;
  }

  Future<void> setMode(ImmersionMode mode) =>
      learning.setSetting(modeKey, mode.name);

  Future<KnowledgeSnapshot> read() async =>
      KnowledgeSnapshot.fromEvents(await learning.allEvents(), course);

  /// Old episode saves prove exposure only. They contain no independent answers.
  Future<void> restoreEncounters(
    Iterable<KnowledgeSkill> skills,
    String context,
  ) => learning.db.transaction(() async {
    if (skills.isEmpty) return;
    final current = await read();
    for (final skill in skills) {
      if (current.of(skill).firstSeen == null) {
        await _append(skill, 'encounter', {'context': context});
      }
    }
  });

  /// At most one encounter per context and UTC day. Entering a screen never grants mastery.
  Future<void> encounter(
    KnowledgeSkill skill,
    String context, {
    bool onlyIfNew = false,
  }) => learning.db.transaction(() async {
    final current = await learning.allEvents();
    if (onlyIfNew &&
        KnowledgeSnapshot.fromEvents(current, course).of(skill).firstSeen !=
            null) {
      return;
    }
    final day = dayKey(learning.now().toUtc());
    if (current.any(
      (e) =>
          e.courseId == course &&
          e.kind == 'knowledge' &&
          e.data['knowledgeId'] == skill.id &&
          e.data['context'] == context &&
          e.data['observation'] == 'encounter' &&
          dayKey(DateTime.parse(e.occurredAt).toUtc()) == day,
    )) {
      return;
    }
    await _append(skill, 'encounter', {'context': context});
  });

  Future<void> favorite(KnowledgeSkill skill, bool enabled) =>
      _append(skill, 'favorite', {'favorite': enabled});

  Future<void> check(
    KnowledgeSkill skill, {
    required String context,
    required KnowledgeCheck check,
    required bool correct,
    bool assisted = false,
    KnowledgeError? error,
  }) => _append(skill, 'check', {
    'context': context,
    'check': check.name,
    'correct': correct,
    'assisted': assisted,
    if (error != null) 'error': error.name,
  });

  Future<void> _append(
    KnowledgeSkill skill,
    String observation,
    Map<String, Object> fields,
  ) {
    final event = learning.event('knowledge', {
      'courseId': course,
      'targetLanguage': 'en',
      'knowledgeId': skill.id,
      'observation': observation,
      ...fields,
    });
    if (!valid(event)) {
      throw ArgumentError('Некорректное наблюдение: ${skill.id}');
    }
    return learning.append(event);
  }

  static final _context = RegExp(r'^[a-z0-9][a-z0-9:.-]{0,95}$');

  static bool valid(LearningEvent e) {
    final d = e.data;
    if (e.kind != 'knowledge' ||
        d['courseId'] != 'ru-en' ||
        d['targetLanguage'] != 'en' ||
        KnowledgeCatalog.skills[d['knowledgeId']]?.course != e.courseId) {
      return false;
    }
    final type = d['observation'];
    final context = d['context'];
    final validContext = context is String && _context.hasMatch(context);
    const shared = {'courseId', 'targetLanguage', 'knowledgeId', 'observation'};
    return switch (type) {
      'encounter' =>
        validContext && d.keys.every({...shared, 'context'}.contains),
      'favorite' =>
        d['favorite'] is bool && d.keys.every({...shared, 'favorite'}.contains),
      'check' =>
        validContext &&
            d['correct'] is bool &&
            d['assisted'] is bool &&
            KnowledgeCheck.values.any((v) => v.name == d['check']) &&
            (d['correct'] == true
                ? !d.containsKey('error')
                : KnowledgeError.values.any((v) => v.name == d['error'])) &&
            d.keys.every(
              {
                ...shared,
                'context',
                'check',
                'correct',
                'assisted',
                'error',
              }.contains,
            ),
      _ => false,
    };
  }
}
