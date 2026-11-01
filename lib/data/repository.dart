import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../domain/course.dart';
import '../domain/languages.dart';
import '../domain/progress.dart';
import 'database.dart';

class LearningRepository {
  final AppDatabase db;
  final DateTime Function() now;
  final Future<String> Function(String) loadAsset;
  final List<LessonInfo> allCatalog = [];
  final Map<String, Vocabulary> allVocabulary = {};
  StudyCourse course = StudyCourse.english;
  List<LessonInfo> get catalog => allCatalog
      .where((l) => StudyCourse.forContent(l.id).id == course.id)
      .toList();
  Map<String, Vocabulary> get vocabulary => Map.fromEntries(
    allVocabulary.entries.where(
      (e) => StudyCourse.forContent(e.key).id == course.id,
    ),
  );
  static const courseKey = 'kvesmos.course.selected.v1';
  Future<void> selectCourse(String id) async {
    if (!StudyCourse.all.any((c) => c.id == id)) {
      throw ArgumentError('Unknown course');
    }
    await setSetting(courseKey, id);
    course = StudyCourse.byId(id);
  }

  final Map<String, String> updatedMaterials = {};
  final Map<String, String> learningObjectives = {};
  LearningRepository(
    this.db, {
    DateTime Function()? now,
    Future<String> Function(String)? loadAsset,
  }) : now = now ?? DateTime.now,
       loadAsset = loadAsset ?? rootBundle.loadString;
  Future<void> initialize() async {
    course = StudyCourse.byId(await setting(courseKey));
    allCatalog.clear();
    allVocabulary.clear();
    updatedMaterials.clear();
    learningObjectives.clear();
    final legacyInstalled = await setting('installed') != null;
    for (final course in StudyCourse.all) {
      final manifest = jsonDecode(await loadAsset(course.manifest));
      if (manifest['sourceLanguage'] != 'ru' ||
          manifest['targetLanguage'] != course.language) {
        throw const FormatException('Неверный язык каталога');
      }
      for (final section in manifest['sections']) {
        for (final theme in section['themes']) {
          for (final lesson in theme['lessons']) {
            final info = LessonInfo(
              lesson['id'],
              lesson['title'],
              theme['title'],
              section['title'],
              lesson['asset'],
              lesson['order'],
            );
            if (allCatalog.any((l) => l.id == info.id) ||
                StudyCourse.forContent(info.id).id != course.id ||
                !info.asset.startsWith('assets/courses/') ||
                info.asset.contains('..')) {
              throw const FormatException('Неверный идентификатор урока');
            }
            allCatalog.add(info);
            final raw = await loadAsset(info.asset);
            final material = Lesson.fromJson(jsonDecode(raw));
            if (material.id != info.id ||
                material.order != info.order ||
                material.exercises.isEmpty ||
                material.vocabulary.any(
                  (v) => StudyCourse.forContent(v.id).id != course.id,
                )) {
              throw const FormatException('Неверный учебный пакет');
            }
            for (final word in material.vocabulary) {
              allVocabulary[word.id] = word;
            }
            final legacy = RegExp(r'^a1-\d{2}$').hasMatch(info.id);
            final marker = 'kvesmos.pack.seen.v1:${info.id}';
            // Old deleted packs stay deleted. New IDs install exactly once;
            // a later app update never overwrites a pinned session or pack.
            await db.transaction(() async {
              if (await setting(marker) == null) {
                if (!(legacy && legacyInstalled) &&
                    !(await installed()).contains(info.id)) {
                  await installRaw(info.id, raw);
                }
                await setSetting(marker, 'true');
              }
            });
            final current = legacy
                ? await loadAsset('assets/courses/demo/${info.id}.json')
                : raw;
            updatedMaterials[info.id] = current;
            learningObjectives[info.id] =
                jsonDecode(current)['objective'] ?? '';
          }
        }
      }
      final orders = allCatalog
          .where((l) => StudyCourse.forContent(l.id).id == course.id)
          .map((l) => l.order)
          .toList();
      if (orders.asMap().entries.any((e) => e.key != e.value)) {
        throw const FormatException('Нарушен порядок курса');
      }
    }
    await setSetting('installed', 'true');
  }

  Future<void> installRaw(String id, String raw) => db
      .into(db.lessonPacks)
      .insertOnConflictUpdate(
        LessonPacksCompanion.insert(id: id, payload: raw),
      );
  Future<void> install(LessonInfo info) async =>
      installRaw(info.id, await loadAsset(info.asset));
  Future<void> uninstall(String id) =>
      (db.delete(db.lessonPacks)..where((t) => t.id.equals(id))).go();
  Future<Set<String>> installed() async =>
      (await (db.selectOnly(
            db.lessonPacks,
          )..addColumns([db.lessonPacks.id])).get())
          .map((e) => e.read(db.lessonPacks.id)!)
          .toSet();
  Future<Lesson> lesson(String id) async {
    final row = await (db.select(
      db.lessonPacks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    if (row == null) {
      throw StateError('Сначала сохраните урок в разделе «Офлайн».');
    }
    return Lesson.fromJson(jsonDecode(row.payload));
  }

  Future<String?> setting(String key) async => (await (db.select(
    db.settings,
  )..where((t) => t.key.equals(key))).getSingleOrNull())?.value;
  Future<void> setSetting(String key, String value) => db
      .into(db.settings)
      .insertOnConflictUpdate(SettingsCompanion.insert(key: key, value: value));
  Future<Session> start(String lessonId) async {
    final existing = await (db.select(
      db.sessions,
    )..where((t) => t.lessonId.equals(lessonId) & t.done.equals(false))).get();
    for (final pending in existing) {
      if (await setting('kvesmos.session.retired.v1:${pending.id}') != 'true') {
        return pending;
      }
    }
    final id = const Uuid().v4();
    await db
        .into(db.sessions)
        .insert(SessionsCompanion.insert(id: id, lessonId: lessonId));
    return session(id);
  }

  Future<Session> session(String id) =>
      (db.select(db.sessions)..where((t) => t.id.equals(id))).getSingle();

  /// Read-only overview: use exactly the material that continuation would open.
  /// Merely looking at a lesson must not create a session or pin new content.
  Future<({Lesson lesson, Session? session})> previewLesson(String id) async {
    final original = await lesson(id);
    final active = await (db.select(
      db.sessions,
    )..where((s) => s.lessonId.equals(id) & s.done.equals(false))).get();
    for (final session in active) {
      if (await setting('kvesmos.session.retired.v1:${session.id}') == 'true') {
        continue;
      }
      final pinned = await setting('kvesmos.session.material.v1:${session.id}');
      return (
        lesson: pinned == null ? original : Lesson.fromJson(jsonDecode(pinned)),
        session: session,
      );
    }
    final raw = updatedMaterials[id];
    return (
      lesson: raw == null ? original : Lesson.fromJson(jsonDecode(raw)),
      session: null,
    );
  }

  /// Demo material is pinned to its session. An old draft always resumes the
  /// installed lesson; opting into a demo never silently changes its questions.
  Future<({Lesson lesson, Session session})> startLesson(
    String id, {
    bool demo = false,
  }) => db.transaction(() async {
    final original = await lesson(id); // also enforces offline installation
    final active = await (db.select(
      db.sessions,
    )..where((t) => t.lessonId.equals(id) & t.done.equals(false))).get();
    final session = await start(id);
    final key = 'kvesmos.session.material.v1:${session.id}';
    final pinned = await setting(key);
    if (pinned != null) {
      return (lesson: Lesson.fromJson(jsonDecode(pinned)), session: session);
    }
    if (active.every((s) => s.id != session.id) &&
        updatedMaterials.containsKey(id)) {
      final raw = updatedMaterials[id]!;
      final material = Lesson.fromJson(jsonDecode(raw));
      if (material.id != id || material.exercises.length != 10) {
        throw StateError('Демонстрационный пакет повреждён.');
      }
      await setSetting(key, raw);
      return (lesson: material, session: session);
    }
    return (lesson: original, session: session);
  });

  /// Keep the old session and all its events; retire it only from continuation.
  Future<({Lesson lesson, Session session})> restartUpdated(
    String id,
    String previousId,
  ) => db.transaction(() async {
    final previous = await session(previousId);
    if (previous.lessonId != id ||
        previous.done ||
        !updatedMaterials.containsKey(id)) {
      throw StateError('Нельзя переключить этот урок.');
    }
    if (await setting('kvesmos.session.retired.v1:$previousId') == 'true') {
      return startLesson(id);
    }
    final raw = updatedMaterials[id]!;
    final material = Lesson.fromJson(jsonDecode(raw));
    final newId = const Uuid().v4();
    await db
        .into(db.sessions)
        .insert(SessionsCompanion.insert(id: newId, lessonId: id));
    await setSetting('kvesmos.session.material.v1:$newId', raw);
    await setSetting('kvesmos.session.retired.v1:$previousId', 'true');
    return (lesson: material, session: await session(newId));
  });

  /// Marks an explanation as read for one session; does not change XP.
  Future<bool> hasTeachingSeen(String sessionId) async =>
      (await setting('kvesmos.lesson.teaching.v1:$sessionId')) == 'true';

  Future<void> markTeachingSeen(String sessionId) =>
      setSetting('kvesmos.lesson.teaching.v1:$sessionId', 'true');

  Future<int> teachingStep(String sessionId) async =>
      int.tryParse(
        await setting('kvesmos.lesson.teaching.step.v1:$sessionId') ?? '',
      ) ??
      0;

  Future<void> saveTeachingStep(String sessionId, int step) =>
      setSetting('kvesmos.lesson.teaching.step.v1:$sessionId', '$step');

  Future<void> draft(String sessionId, int position, String value) =>
      (db.update(db.sessions)..where(
            (t) =>
                t.id.equals(sessionId) &
                t.position.equals(position) &
                t.done.equals(false),
          ))
          .write(SessionsCompanion(draft: Value(value)));
  LearningEvent event(String kind, Map<String, dynamic> data) {
    final time = now();
    return LearningEvent(
      id: const Uuid().v4(),
      kind: kind,
      occurredAt: time.toUtc().toIso8601String(),
      day: dayKey(time),
      data: {
        ...data,
        'courseId': StudyCourse.forContent(
          '${data['lesson'] ?? (data['words'] as List?)?.firstOrNull ?? ''}',
        ).id,
        'targetLanguage': StudyCourse.forContent(
          '${data['lesson'] ?? (data['words'] as List?)?.firstOrNull ?? ''}',
        ).language,
      },
    );
  }

  Future<void> append(LearningEvent event, {bool synced = false}) => db
      .into(db.events)
      .insert(
        EventsCompanion.insert(
          id: event.id,
          payload: jsonEncode(event.toJson()),
          synced: Value(synced),
        ),
        mode: InsertMode.insertOrIgnore,
      );

  /// Position and events commit atomically; stale/double button presses cannot award twice.
  Future<bool> answer(
    String sessionId,
    int expectedPosition,
    Exercise exercise,
    String input, {
    required int total,
  }) => db.transaction(() async {
    final current = await session(sessionId);
    if (current.done || current.position != expectedPosition) {
      throw StateError('Ответ уже сохранён.');
    }
    final correct = checkAnswer(exercise, input);
    await append(
      event('answer', {
        'session': sessionId,
        'exercise': exercise.id,
        'lesson': current.lessonId,
        'correct': correct,
        'words': exercise.wordIds,
      }),
    );
    if (correct) {
      final done = current.position + 1 >= total;
      await (db.update(
        db.sessions,
      )..where((t) => t.id.equals(sessionId))).write(
        SessionsCompanion(
          position: Value(current.position + 1),
          draft: const Value(''),
          done: Value(done),
        ),
      );
      if (done) {
        await append(
          event('complete', {'session': sessionId, 'lesson': current.lessonId}),
        );
      }
    }
    return correct;
  });
  Future<void> review(
    Vocabulary word,
    String input,
  ) => db.transaction(() async {
    final day = dayKey(now());
    final previous = (await allEvents())
        .where(
          (e) =>
              e.kind == 'answer' &&
              e.day == day &&
              e.data['exercise'] == 'review:${word.id}' &&
              e.data['correct'] == true,
        )
        .firstOrNull;
    await append(
      event('answer', {
        // One credit per known word per local study day, including retries and
        // voluntary practice. Historical events retain their original scoring.
        'session': previous?.data['session'] ?? 'review:v2:$day:${word.id}',
        'exercise': 'review:${word.id}',
        'correct': normalizeAnswer(input) == normalizeAnswer(word.en),
        'words': [word.id],
      }),
    );
  });

  Future<List<LearningEvent>> allEvents() async =>
      (await db.select(db.events).get())
          .map((e) => LearningEvent.fromJson(jsonDecode(e.payload)))
          .toList();

  /// Recover explanations from the material actually used in a failed session.
  /// This is a read-only view of existing events and pinned lesson snapshots.
  Future<Map<String, Exercise>> mistakeExamples() async {
    final result = <String, Exercise>{};
    final events =
        (await allEvents())
            .where(
              (e) =>
                  e.kind == 'answer' &&
                  e.data['correct'] == false &&
                  e.data['lesson'] is String,
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final cache = <String, Lesson>{};
    for (final event in events) {
      final words = List<String>.from(
        event.data['words'] ?? [],
      ).where((w) => !result.containsKey(w)).toList();
      if (words.isEmpty) continue;
      final sessionId = '${event.data['session']}';
      try {
        var material = cache[sessionId];
        if (material == null) {
          final pinned = await setting(
            'kvesmos.session.material.v1:$sessionId',
          );
          material = pinned == null
              ? await lesson(event.data['lesson'])
              : Lesson.fromJson(jsonDecode(pinned));
          cache[sessionId] = material;
        }
        final exercise = material.exercises
            .where((e) => e.id == event.data['exercise'])
            .firstOrNull;
        if (exercise != null) {
          for (final word in words) {
            result[word] = exercise;
          }
        }
      } catch (_) {
        /* Removed offline packs do not block review of known words. */
      }
    }
    return result;
  }

  Future<ProgressSnapshot> progress() async => ProgressSnapshot.fromEvents(
    (await allEvents()).where((e) => e.courseId == course.id),
  );
  Future<ProgressSnapshot> globalProgress() async =>
      ProgressSnapshot.fromEvents(await allEvents());
  Future<List<LearningEvent>> pending() async =>
      (await (db.select(db.events)..where((t) => t.synced.equals(false))).get())
          .map((e) => LearningEvent.fromJson(jsonDecode(e.payload)))
          .toList();
  Future<void> acknowledge(List<String> ids) async {
    if (ids.isEmpty) {
      return;
    }
    await (db.update(db.events)..where((t) => t.id.isIn(ids))).write(
      const EventsCompanion(synced: Value(true)),
    );
  }

  Future<void> reset() => db.transaction(() async {
    await db.delete(db.events).go();
    await db.delete(db.sessions).go();
    await db.delete(db.settings).go();
  });
}
