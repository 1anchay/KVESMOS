import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../domain/course.dart';
import '../domain/intro_activity.dart';
import '../domain/languages.dart';
import '../domain/missions.dart';
import '../domain/progress.dart';
import '../domain/rewards.dart';
import '../domain/space_adventures.dart';
import 'database.dart';
import 'conversation_repository.dart';
import 'listening_repository.dart';
import 'repository.dart';
import 'smart_placement_repository.dart';
import 'rewards_repository.dart';

const progressTransferMaxBytes = 32 * 1024 * 1024;

class ProgressFile {
  final DateTime created;
  final Map<String, String> settings, packs;
  final Map<String, Session> sessions;
  final Map<String, LearningEvent> events;
  const ProgressFile._(
    this.created,
    this.settings,
    this.packs,
    this.sessions,
    this.events,
  );
}

typedef TransferPreview = ({
  int currentXp,
  int fileXp,
  int mergedXp,
  int newEvents,
  int fileLessons,
  int drafts,
  int items,
  int opened,
  bool freshProfile,
});

class ProgressTransfer {
  final LearningRepository learning;
  final RewardCatalog rewards;
  ProgressTransfer(this.learning, this.rewards);
  AppDatabase get _db => learning.db;

  static const _format = 'dev.orbitwords.progress';
  static const _material = 'kvesmos.session.material.v1:';
  static const _retired = 'kvesmos.session.retired.v1:';
  static const _inventory = RewardsRepository.storageKey;
  static final _uuid = RegExp(
    r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
  );
  static final _id = RegExp(r'^[a-zA-Z0-9_.:,/\-]{1,1000}$');
  static final _day = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  static final _courses = StudyCourse.all.map((c) => c.id).toSet();
  static const _plain = {
    'name',
    'goal',
    'level',
    'theme',
    'onboarded',
    'kvesmos.smartStart.invite.v1',
    LearningRepository.courseKey,
    'kvesmos.audio.preferences.v1',
    'kvesmos.reminders.v1',
    'kvesmos.profile.showcase.v1',
    'kvesmos.learning.showAdventures.v1',
    'kvesmos.expeditions.optin.v1',
    'kvesmos.expeditions.since.v1',
    'kvesmos.missions.since.v1',
    _inventory,
  };
  static const _prefixes = [
    _material,
    _retired,
    'kvesmos.session.rehearsal.v1:',
    'kvesmos.lesson.teaching.v1:',
    'kvesmos.lesson.teaching.step.v1:',
    'kvesmos.lesson.intro.v2:',
    'kvesmos.stage.seen.v1:',
    'kvesmos.alive.seen.v1:',
    'kvesmos.pack.seen.v1:',
    'kvesmos.adventure.v1:',
    'kvesmos.mastery.v1:',
    'kvesmos.placement.v1:',
    SmartPlacementRepository.prefix,
    'kvesmos.course.start.v1:',
    'kvesmos.picture.v1:',
    'kvesmos.conversation.v1:',
    'kvesmos.listening.v1:',
    'kvesmos.smart.v1:',
  ];
  static bool _allowed(String key) =>
      _plain.contains(key) ||
      key == 'kvesmos.practice.v1' ||
      key.startsWith('kvesmos.practice.v1:') ||
      _prefixes.any(key.startsWith);

  Future<Uint8List> export() => _db.transaction(() async {
    final payload = jsonEncode({
      'created': learning.now().toUtc().toIso8601String(),
      'settings': {
        for (final row in await _db.select(_db.settings).get())
          if (_allowed(row.key)) row.key: row.value,
      },
      'packs': {
        for (final row in await _db.select(_db.lessonPacks).get())
          row.id: row.payload,
      },
      'sessions': [
        for (final row in await _db.select(_db.sessions).get()) row.toJson(),
      ],
      'events': [
        for (final event in await learning.allEvents()) event.toJson(),
      ],
    });
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': _format,
          'version': 1,
          'schema': _db.schemaVersion,
          'sha256': sha256.convert(utf8.encode(payload)).toString(),
          'payload': payload,
        }),
      ),
    );
    _require(bytes.length <= progressTransferMaxBytes, 'Файл превышает 32 МБ.');
    return bytes;
  });

  Future<ProgressFile> validate(Uint8List bytes) async {
    try {
      _require(
        bytes.length <= progressTransferMaxBytes,
        'Файл превышает 32 МБ.',
      );
      final manifest = _object(jsonDecode(utf8.decode(bytes)));
      _require(manifest['format'] == _format, 'Это не файл прогресса KVESMOS.');
      _require(
        manifest['version'] == 1 && manifest['schema'] == _db.schemaVersion,
        'Версия файла несовместима. Проверьте версию KVESMOS.',
      );
      final payload = manifest['payload'] as String;
      _require(
        manifest['sha256'] == sha256.convert(utf8.encode(payload)).toString(),
        'Контрольная сумма не совпала. Файл повреждён.',
      );
      final data = _object(jsonDecode(payload));
      final created = DateTime.parse(data['created'] as String);
      final settings = Map<String, String>.from(_object(data['settings']));
      final packs = Map<String, String>.from(_object(data['packs']));
      final rows = data['sessions'] as List;
      final ledger = data['events'] as List;
      _require(
        settings.length <= 50000 &&
            rows.length <= 50000 &&
            ledger.length <= 200000 &&
            packs.length <= learning.allCatalog.length,
      );
      final catalog = {
        for (final lesson in learning.allCatalog) lesson.id: lesson,
      };
      final listening = {
        for (final scene in ListeningScene.parse(
          await learning.loadAsset('assets/learning/listening.txt'),
        ))
          scene.id: scene.language,
      };
      final pictures = {
        for (final card
            in jsonDecode(
                  await learning.loadAsset('assets/learning/pictures.json'),
                )
                as List)
          card['id'] as String,
      };
      final conversations = {
        for (final scene in Conversation.parse(
          await learning.loadAsset('assets/learning/conversations.txt'),
        ))
          '${scene.language}:${scene.id}',
      };
      final materials = {
        for (final e in packs.entries) e.key: _lesson(e.key, e.value, catalog),
      };
      final sessions = <String, Session>{};
      for (final json in rows) {
        final row = Session.fromJson(_object(json));
        _require(
          _uuid.hasMatch(row.id) &&
              !sessions.containsKey(row.id) &&
              catalog.containsKey(row.lessonId) &&
              row.draft.length <= 16000,
        );
        final pinned = settings['$_material${row.id}'];
        final material = pinned == null
            ? materials[row.lessonId]
            : _lesson(row.lessonId, pinned, catalog);
        final dormant = row.done || settings['$_retired${row.id}'] == 'true';
        _require(
          material != null || dormant,
          'В файле отсутствует пакет начатого урока.',
        );
        _require(
          row.position >= 0 &&
              row.position <= 100 &&
              (dormant || row.position < material!.exercises.length),
        );
        if (!dormant && row.draft.isNotEmpty) {
          // Very old builds stored plain text. Newer drafts have token indices
          // that must be validated against their exact pinned exercise.
          if (row.draft.trimLeft().startsWith('{')) {
            final draft = _object(jsonDecode(row.draft));
            final tokens = material!.exercises[row.position].tokens;
            _require(draft['text'] == null || draft['text'] is String);
            _require(
              List<int>.from(
                draft['order'] ?? [],
              ).every((i) => i >= 0 && i < tokens.length),
            );
            Map<String, String>.from(draft['pairs'] ?? {});
          }
        }
        final intro = settings['kvesmos.lesson.intro.v2:${row.id}'];
        if (intro != null && material != null) {
          final draft = IntroDraft.fromJson(_object(jsonDecode(intro)));
          for (final activity in material.guidedIntroduction) {
            final rawAction = draft.actions[activity.id];
            if (rawAction == null) continue;
            final action = _object(rawAction);
            _require(
              List<int>.from(
                action['tokens'] ?? [],
              ).every((i) => i >= 0 && i < activity.tokens.length),
            );
            _require(action['answer'] == null || action['answer'] is String);
          }
        }
        sessions[row.id] = row;
      }
      for (final entry in settings.entries) {
        _validateSetting(
          entry.key,
          entry.value,
          sessions,
          catalog,
          listening,
          pictures,
          conversations,
          settings,
          materials,
        );
      }
      final events = <String, LearningEvent>{};
      for (final json in ledger) {
        final event = _event(_object(json), catalog);
        _require(!events.containsKey(event.id));
        final session = sessions[event.data['session']];
        _require(session == null || event.data['lesson'] == session.lessonId);
        events[event.id] = event;
      }
      return ProgressFile._(created, settings, packs, sessions, events);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Данные файла неполные или повреждены.');
    }
  }

  LearningEvent _event(
    Map<String, dynamic> json,
    Map<String, LessonInfo> catalog,
  ) {
    final event = LearningEvent.fromJson(json);
    final data = event.data;
    final session = data['session'];
    final exercise = data['exercise'];
    final adventure = data['adventure'];
    final lesson = data['lesson'];
    final wordIds = List<String>.from(data['words'] ?? const []);
    final stableAdventureId =
        adventure is String &&
        (event.id == 'adventure:v1:$adventure:complete' ||
            event.id == 'adventure:v1:$adventure:$exercise:correct');
    _require(
      (_uuid.hasMatch(event.id) || stableAdventureId) &&
          _validDay(event.day) &&
          DateTime.tryParse(event.occurredAt) != null &&
          _courses.contains(event.courseId),
    );
    _require(
      data.keys.every(
        {
          'session',
          'exercise',
          'lesson',
          'adventure',
          'correct',
          'words',
          'rehearsal',
          'courseId',
          'targetLanguage',
          'skill',
          'evidence',
        }.contains,
      ),
    );
    final language = StudyCourse.byId(event.courseId).language;
    _require(
      data['targetLanguage'] == null || data['targetLanguage'] == language,
    );
    _require(
      lesson == null ||
          catalog.containsKey(lesson) &&
              StudyCourse.forContent(lesson as String).id == event.courseId,
    );
    _require(data['rehearsal'] == null || data['rehearsal'] is bool);
    _require(
      data['skill'] == null ||
          {
            'words',
            'grammar',
            'sentences',
            'listening',
            'dialogue',
          }.contains(data['skill']),
    );
    _require(data['evidence'] == null || data['evidence'] is bool);
    _require(
      wordIds.length <= 100 &&
          wordIds.every(
            (word) =>
                _id.hasMatch(word) &&
                StudyCourse.forContent(word).id == event.courseId,
          ),
    );
    if (adventure != null) {
      _require(
        event.courseId == StudyCourse.english.id &&
            SpaceAdventure.all.any(
              (a) =>
                  a.id == adventure &&
                  (event.kind == 'adventure_complete' ||
                      a.steps.any((s) => s.id == exercise)),
            ),
      );
    }
    switch (event.kind) {
      case 'answer':
        _require(
          session is String &&
              _id.hasMatch(session) &&
              exercise is String &&
              _id.hasMatch(exercise) &&
              data['correct'] is bool,
        );
        _require(
          !stableAdventureId ||
              data['correct'] == true &&
                  event.id.endsWith(':$exercise:correct'),
        );
      case 'complete':
        _require(
          session is String && _uuid.hasMatch(session) && lesson is String,
        );
      case 'adventure_complete':
        _require(
          adventure is String && event.id == 'adventure:v1:$adventure:complete',
        );
      default:
        throw const FormatException('Неизвестный тип учебного события.');
    }
    return event;
  }

  Lesson _lesson(String id, String raw, Map<String, LessonInfo> catalog) {
    _require(catalog.containsKey(id) && raw.length <= 200000);
    final lesson = Lesson.fromJson(_object(jsonDecode(raw)));
    final course = StudyCourse.forContent(id).id;
    _require(
      lesson.id == id &&
          lesson.order == catalog[id]!.order &&
          lesson.exercises.isNotEmpty &&
          lesson.exercises.length <= 100 &&
          lesson.exercises.map((e) => e.id).toSet().length ==
              lesson.exercises.length &&
          lesson.exercises.every((e) => _id.hasMatch(e.id)) &&
          lesson.vocabulary.every(
            (v) => StudyCourse.forContent(v.id).id == course,
          ),
    );
    return lesson;
  }

  void _validateSetting(
    String key,
    String value,
    Map<String, Session> sessions,
    Map<String, LessonInfo> catalog,
    Map<String, String> listening,
    Set<String> pictures,
    Set<String> conversations,
    Map<String, String> settings,
    Map<String, Lesson> materials,
  ) {
    _require(_allowed(key) && _id.hasMatch(key) && value.length <= 200000);
    final parts = key.split(':');
    final suffix = parts.length > 1 ? parts[1] : '';
    if (key.startsWith(_material) ||
        key.startsWith(_retired) ||
        key.startsWith('kvesmos.session.rehearsal.v1:') ||
        key.startsWith('kvesmos.lesson.') ||
        key.startsWith('kvesmos.stage.seen.v1:')) {
      _require(sessions.containsKey(suffix));
      if (key.startsWith(_material)) return;
      if (key.startsWith('kvesmos.lesson.intro.v2:')) {
        final draft = IntroDraft.fromJson(_object(jsonDecode(value)));
        _require(draft.index >= 0 && draft.index <= 100);
      } else if (key.startsWith('kvesmos.lesson.teaching.step.v1:')) {
        _require(
          (int.tryParse(value) ?? -1) >= 0 &&
              (int.tryParse(value) ?? 101) <= 100,
        );
      } else {
        _require(value == 'true');
      }
      return;
    }
    if (key.startsWith('kvesmos.pack.seen.v1:')) {
      _require(catalog.containsKey(suffix) && value == 'true');
      return;
    }
    if (key.startsWith('kvesmos.alive.seen.v1:')) {
      _require(value == 'true');
      return;
    }
    switch (parts.first) {
      case _inventory:
        _decodeInventory(value);
      case LearningRepository.courseKey:
        _require(_courses.contains(value));
      case 'theme':
        _require(const {'light', 'dark', 'system'}.contains(value));
      case 'kvesmos.smartStart.invite.v1':
        _require(value == 'seen');
      case 'goal':
        _require(const {'25', '50', '100'}.contains(value));
      case 'name':
      case 'level':
        _require(value.length <= 160);
      case 'onboarded':
      case 'kvesmos.learning.showAdventures.v1':
      case 'kvesmos.expeditions.optin.v1':
        _require(value == 'true' || value == 'false');
      case 'kvesmos.expeditions.since.v1':
      case 'kvesmos.missions.since.v1':
        _require(_validDay(value));
      case 'kvesmos.profile.showcase.v1':
        _require(List<String>.from(jsonDecode(value)).length <= 3);
      case 'kvesmos.reminders.v1':
        final reminder = _object(jsonDecode(value));
        _require(
          _courses.contains(reminder['courseId']) &&
              List<int>.from(
                reminder['weekdays'],
              ).every((d) => d >= 1 && d <= 7),
        );
      case 'kvesmos.audio.preferences.v1':
        _object(jsonDecode(value));
      case 'kvesmos.adventure.v1':
        final state = AdventureState.decode(value);
        final adventure = SpaceAdventure.all
            .where((a) => a.id == suffix)
            .firstOrNull;
        _require(
          adventure != null &&
              state.step >= 0 &&
              state.step <= adventure.steps.length &&
              state.revision >= 0 &&
              (state.step < adventure.steps.length || state.completed),
        );
      case 'kvesmos.practice.v1':
        final state = _object(jsonDecode(value));
        final words = List<String>.from(state['words']);
        final course = _courses.contains(suffix) ? suffix : 'ru-en';
        _require(
          words.length <= 12 &&
              words.every(
                (id) =>
                    learning.allVocabulary.containsKey(id) &&
                    StudyCourse.forContent(id).id == course,
              ),
        );
        _require(
          List<String>.from(state['reasons']).length == words.length &&
              _boundedIndex(state['index'], words.length) &&
              _boundedIndex(state['phase'], 2) &&
              state['credited'] is int &&
              state['text'] is String &&
              state['attempt'] is int,
        );
      case 'kvesmos.mastery.v1':
        _require(_courses.contains(suffix));
        if (key.endsWith(':stamp')) {
          _require(DateTime.tryParse(value) != null);
        } else if (key.endsWith(':difficult')) {
          List<String>.from(jsonDecode(value));
        } else {
          final state = _object(jsonDecode(value));
          final items = state['items'] as List;
          _require(
            items.isNotEmpty &&
                _boundedIndex(state['index'], items.length) &&
                (state['index'] != items.length || state['done'] == true) &&
                state['score'] is int &&
                state['text'] is String,
          );
          for (final item in items) {
            _require(
              item is Map &&
                  item['id'] is String &&
                  item['phrase'] is String &&
                  item['meaning'] is String &&
                  item['explanation'] is String,
            );
          }
        }
      case 'kvesmos.picture.v1':
        _require(_courses.contains(suffix));
        final state = _object(jsonDecode(value));
        final ids = List<String>.from(state['ids']);
        _require(
          ids.length <= 6 &&
              ids.every(pictures.contains) &&
              _boundedIndex(state['index'], ids.length) &&
              state['score'] is int &&
              state['text'] is String &&
              state['checked'] is bool &&
              state['correct'] is bool,
        );
      case 'kvesmos.placement.v1':
        _require(_courses.contains(suffix));
        final state = _object(jsonDecode(value));
        final questions = state['questions'] as List;
        final results = List<bool>.from(state['results']);
        _require(questions.length <= 8 && results.length <= questions.length);
        for (final raw in questions) {
          final question = _object(raw);
          _require(
            _boundedIndex(question['order'], 14) &&
                question['prompt'] is String &&
                List<String>.from(question['options']).length >= 2 &&
                List<String>.from(question['answers']).isNotEmpty,
          );
        }
        _require(
          state['recommendation'] == null ||
              catalog.containsKey(state['recommendation']) &&
                  StudyCourse.forContent(
                        state['recommendation'] as String,
                      ).id ==
                      suffix,
        );
      case 'kvesmos.conversation.v1':
        _require(
          _courses.contains(suffix) &&
              conversations.contains(
                '${StudyCourse.byId(suffix).language}:${parts.elementAtOrNull(2)}',
              ),
        );
        final state = _object(jsonDecode(value));
        _require(
          _boundedIndex(state['step'], 3) &&
              _boundedIndex(state['branch'], 1) &&
              state['error'] is bool &&
              state['text'] is String,
        );
      case 'kvesmos.course.start.v1':
        _require(
          _courses.contains(suffix) &&
              catalog.containsKey(value) &&
              StudyCourse.forContent(value).id == suffix,
        );
      case 'kvesmos.placement.v2':
        _require(
          _courses.contains(suffix) &&
              SmartPlacementRepository.valid(
                _object(jsonDecode(value)),
                catalog.keys
                    .where((id) => StudyCourse.forContent(id).id == suffix)
                    .toSet(),
              ),
        );
      case 'kvesmos.listening.v1':
        final state = _object(jsonDecode(value));
        _require(
          _courses.contains(suffix) &&
              listening[parts.elementAtOrNull(2)] ==
                  StudyCourse.byId(suffix).language &&
              state['run'] is String &&
              _uuid.hasMatch(state['run']) &&
              _boundedIndex(state['index'], 2) &&
              _boundedIndex(state['score'], 2) &&
              [
                'checked',
                'correct',
                'heard',
                'reading',
                'assisted',
              ].every((k) => state[k] is bool),
        );
      case 'kvesmos.smart.v1':
        _require(_courses.contains(suffix));
        final state = _object(jsonDecode(value));
        final items = List<Map<String, dynamic>>.from(state['items']);
        _require(
          state['run'] is String &&
              _uuid.hasMatch(state['run']) &&
              state['reason'] is String &&
              state['text'] is String &&
              {
                'words',
                'grammar',
                'sentences',
                'listening',
              }.contains(state['skill']) &&
              items.isNotEmpty &&
              items.length <= 6 &&
              _boundedIndex(state['index'], items.length) &&
              _boundedIndex(state['score'], items.length) &&
              (state['correct'] == null || state['correct'] is bool),
        );
        final index = state['index'] as int;
        final order = List<int>.from(state['order']);
        for (final (position, item) in items.indexed) {
          final id = item['id'] as String;
          final word = item['word'];
          if (word is String) {
            _require(
              learning.allVocabulary.containsKey(word) &&
                  StudyCourse.forContent(word).id == suffix &&
                  id == 'review:$word',
            );
          } else {
            final lesson = item['lesson'] as String;
            _require(
              catalog.containsKey(lesson) &&
                  StudyCourse.forContent(lesson).id == suffix,
            );
            final source = item['sourceSession'];
            Lesson? content;
            if (source is String) {
              _require(sessions[source]?.lessonId == lesson);
              final pinned = settings['$_material$source'];
              content = pinned == null
                  ? materials[lesson]
                  : _lesson(lesson, pinned, catalog);
            } else {
              final raw = learning.updatedMaterials[lesson];
              content = raw == null
                  ? materials[lesson]
                  : _lesson(lesson, raw, catalog);
            }
            final exercise = content?.exercises
                .where((e) => e.id == id)
                .firstOrNull;
            _require(exercise != null);
            if (position == index) {
              _require(
                order.every((i) => i >= 0 && i < exercise!.tokens.length),
              );
            }
          }
        }
    }
  }

  Inventory _decodeInventory(String raw) {
    final inv = Inventory.decode(raw);
    final grants = _object(jsonDecode(raw))['grants'] as List;
    _require(inv.grants.length == grants.length);
    for (final grant in inv.grants.values) {
      final known =
          rewards.milestones.any(
            (m) => m['id'] == grant.id && m['chest_id'] == grant.kind,
          ) ||
          DailyMission.all.any(
            (m) =>
                grant.kind == m.chest &&
                grant.id.startsWith('daily:v1:') &&
                grant.id.length >= 19 &&
                _validDay(grant.id.substring(9, 19)) &&
                m.grantId(grant.id.substring(9, 19)) == grant.id,
          ) ||
          (grant.kind == 'explorer' &&
              grant.id.startsWith('expedition:v1:week:') &&
              _validDay(grant.id.substring(19))) ||
          (grant.kind == 'nebula' &&
              RegExp(
                r'^expedition:v1:month:\d{4}-(0[1-9]|1[0-2])$',
              ).hasMatch(grant.id));
      _require(known && !(grant.consumedEmpty && grant.itemId != null));
    }
    for (final id in inv.owned) {
      _require(rewards.items.any((i) => i.id == id));
    }
    for (final e in inv.equipped.entries) {
      _require(
        inv.owned.contains(e.value) && rewards.item(e.value).slot == e.key,
      );
    }
    return inv;
  }

  Future<TransferPreview> preview(
    ProgressFile file,
  ) => _db.transaction(() async {
    final local = {
      for (final event in await learning.allEvents()) event.id: event,
    };
    final merged = ProgressSnapshot.fromEvents(
      {...file.events, ...local}.values,
    );
    final progress = ProgressSnapshot.fromEvents(file.events.values);
    final inventory = Inventory.decode(file.settings[_inventory]);
    return (
      currentXp: ProgressSnapshot.fromEvents(local.values).xp,
      fileXp: progress.xp,
      mergedXp: merged.xp,
      newEvents: file.events.keys.where((id) => !local.containsKey(id)).length,
      fileLessons: progress.completed.length,
      drafts: file.sessions.values
          .where((s) => !s.done && file.settings['$_retired${s.id}'] != 'true')
          .length,
      items: inventory.owned.length,
      opened: inventory.grants.values.where((g) => g.claimed).length,
      freshProfile: await _fresh(local.isEmpty),
    );
  });

  Future<bool> _fresh(bool noEvents) async =>
      noEvents &&
      (await _db.select(_db.sessions).get()).isEmpty &&
      (await learning.setting('name')) == null &&
      Inventory.decode(await learning.setting(_inventory)).grants.isEmpty;

  Future<void> restore(ProgressFile file) => _db.transaction(() async {
    final events = {
      for (final row in await _db.select(_db.events).get()) row.id,
    };
    final fresh = await _fresh(events.isEmpty);
    final settings = {
      for (final row in await _db.select(_db.settings).get())
        row.key: row.value,
    };
    final localSessions = {
      for (final row in await _db.select(_db.sessions).get()) row.id: row,
    };
    final packs = await learning.installed();
    final advancing = <String>{};
    // Preserve the exact pack used by an older unpinned draft on either device.
    for (final incoming in file.sessions.values) {
      final existing = localSessions[incoming.id];
      if (existing != null && existing.lessonId != incoming.lessonId) {
        throw const FormatException(
          'Одинаковые идентификаторы разных занятий.',
        );
      }
      final materialKey = '$_material${incoming.id}';
      final source =
          file.settings[materialKey] ?? file.packs[incoming.lessonId];
      final shouldCompareMaterial =
          existing != null && (!existing.done || !incoming.done);
      final local = !shouldCompareMaterial
          ? null
          : settings[materialKey] ??
                (await (_db.select(_db.lessonPacks)
                          ..where((p) => p.id.equals(incoming.lessonId)))
                        .getSingleOrNull())
                    ?.payload;
      if (existing != null &&
          source != null &&
          local != null &&
          source != local) {
        // JSON whitespace from distinct asset pack installers is harmless.
        if (jsonEncode(jsonDecode(source)) != jsonEncode(jsonDecode(local))) {
          throw const FormatException(
            'Версии материала одного занятия различаются.',
          );
        }
      }
      if (existing == null ||
          !existing.done && incoming.position > existing.position) {
        advancing.add(incoming.id);
        await _db.into(_db.sessions).insertOnConflictUpdate(incoming);
        if (source != null &&
            (!incoming.done || file.settings.containsKey(materialKey))) {
          await learning.setSetting(materialKey, source);
        }
      }
    }
    final activeLessons = {
      for (final row in file.sessions.values)
        if (!row.done && file.settings['$_retired${row.id}'] != 'true')
          row.lessonId,
    };
    await _db.batch((batch) {
      batch.insertAll(_db.events, [
        for (final event in file.events.values)
          if (!events.contains(event.id))
            EventsCompanion.insert(
              id: event.id,
              payload: jsonEncode(event.toJson()),
            ),
      ], mode: InsertMode.insertOrIgnore);
      batch.insertAll(_db.lessonPacks, [
        for (final pack in file.packs.entries)
          if (!packs.contains(pack.key))
            LessonPacksCompanion.insert(id: pack.key, payload: pack.value),
      ], mode: InsertMode.insertOrIgnore);
      // Pinned material alone is enough to recover an unfinished lesson.
      batch.insertAll(_db.lessonPacks, [
        for (final row in file.sessions.values)
          if (activeLessons.contains(row.lessonId) &&
              !packs.contains(row.lessonId) &&
              !file.packs.containsKey(row.lessonId) &&
              file.settings['$_material${row.id}'] != null)
            LessonPacksCompanion.insert(
              id: row.lessonId,
              payload: file.settings['$_material${row.id}']!,
            ),
      ], mode: InsertMode.insertOrIgnore);
    });
    for (final e in file.settings.entries) {
      if (e.key == _inventory || e.key.startsWith(_material)) continue;
      final old = settings[e.key];
      final suffix = e.key.split(':').elementAtOrNull(1);
      final sessionMetadata =
          suffix != null && file.sessions.containsKey(suffix);
      if (e.key.startsWith(_retired) && e.value == 'true') {
        if (old != 'true') await learning.setSetting(e.key, e.value);
      } else if (e.key.startsWith('kvesmos.adventure.v1:') && old != null) {
        final current = AdventureState.decode(old);
        final incoming = AdventureState.decode(e.value);
        if (incoming.step > current.step ||
            incoming.step == current.step &&
                incoming.revision > current.revision) {
          await learning.setSetting(e.key, e.value);
        }
      } else if (e.key.endsWith('.since.v1')) {
        if (old == null || e.value.compareTo(old) < 0) {
          await learning.setSetting(e.key, e.value);
        }
      } else if (sessionMetadata &&
          !advancing.contains(suffix) &&
          e.key.startsWith('kvesmos.lesson.')) {
        continue;
      } else if (fresh ||
          old == null ||
          sessionMetadata && advancing.contains(suffix)) {
        await learning.setSetting(e.key, e.value);
      }
    }
    if (file.settings[_inventory] != null) {
      final target = Inventory.decode(settings[_inventory]);
      final source = Inventory.decode(file.settings[_inventory]);
      for (final grant in source.grants.values) {
        final local = target.grants[grant.id];
        if (local == null || !local.claimed && grant.claimed) {
          target.grants[grant.id] = grant;
        }
      }
      target.transferredItems.addAll(source.owned.difference(target.owned));
      if (fresh) target.equipped.addAll(source.equipped);
      await learning.setSetting(_inventory, target.encode());
    }
  });

  static Map<String, dynamic> _object(Object? value) =>
      Map<String, dynamic>.from(value as Map);
  static bool _boundedIndex(Object? value, int max) =>
      value is int && value >= 0 && value <= max;
  static bool _validDay(String s) =>
      _day.hasMatch(s) &&
      DateTime.tryParse(s) != null &&
      dayKey(DateTime.parse(s)) == s;
  static void _require(
    bool valid, [
    String message = 'Неверные данные прогресса.',
  ]) {
    if (!valid) throw FormatException(message);
  }
}
