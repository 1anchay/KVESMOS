import 'dart:convert';
import 'package:drift/drift.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../domain/course.dart';
import '../domain/progress.dart';
import 'database.dart';

class LearningRepository {
  final AppDatabase db;
  final DateTime Function() now;
  final Future<String> Function(String) loadAsset;
  final List<LessonInfo> catalog = [];
  final Map<String, Vocabulary> vocabulary = {};
  final Map<String, String> updatedMaterials = {};
  LearningRepository(
    this.db, {
    DateTime Function()? now,
    Future<String> Function(String)? loadAsset,
  }) : now = now ?? DateTime.now,
       loadAsset = loadAsset ?? rootBundle.loadString;
  Future<void> initialize() async {
    final manifest = jsonDecode(
      await loadAsset('assets/courses/manifest.json'),
    );
    catalog.clear();
    for (final section in manifest['sections']) {
      for (final theme in section['themes']) {
        for (final lesson in theme['lessons']) {
          catalog.add(
            LessonInfo(
              lesson['id'],
              lesson['title'],
              theme['title'],
              section['title'],
              lesson['asset'],
              lesson['order'],
            ),
          );
        }
      }
    }
    // Assets are read sequentially, and lessons remain in SQLite, not in RAM.
    for (final info in catalog) {
      final raw = await loadAsset(info.asset);
      final lesson = Lesson.fromJson(jsonDecode(raw));
      for (final v in lesson.vocabulary) {
        vocabulary[v.id] = v;
      }
      if (await setting('installed') == null) {
        await installRaw(info.id, raw);
      }
    }
    await setSetting('installed', 'true');
    for (final id in ['a1-01', 'a1-02', 'a1-03']) {
      updatedMaterials[id] = await loadAsset('assets/courses/demo/$id.json');
    }
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
      data: data,
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
  Future<void> review(Vocabulary word, String input) async {
    await append(
      event('answer', {
        'session': const Uuid().v4(),
        'exercise': 'review:${word.id}',
        'correct': normalizeAnswer(input) == normalizeAnswer(word.en),
        'words': [word.id],
      }),
    );
  }

  Future<List<LearningEvent>> allEvents() async =>
      (await db.select(db.events).get())
          .map((e) => LearningEvent.fromJson(jsonDecode(e.payload)))
          .toList();
  Future<ProgressSnapshot> progress() async =>
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
