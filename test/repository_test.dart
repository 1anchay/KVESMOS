import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test('offline initialization installs the whole bundled course', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    expect(await r.installed(), hasLength(20));
    expect(r.catalog, hasLength(20));
    expect(r.vocabulary, hasLength(60));
  });
  test(
    'failed answer persists without advancing; correct commits XP and position',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      final l = await r.lesson('a1-01');
      final s = await r.start(l.id);
      expect(
        await r.answer(s.id, 0, l.exercises.first, 'wrong', total: 10),
        isFalse,
      );
      expect((await r.session(s.id)).position, 0);
      expect((await r.progress()).xp, 0);
      expect(
        await r.answer(
          s.id,
          0,
          l.exercises.first,
          l.exercises.first.answers.first,
          total: 10,
        ),
        isTrue,
      );
      expect((await r.session(s.id)).position, 1);
      expect((await r.progress()).xp, 10);
      expect((await r.progress()).errors, 1);
      expect(await r.pending(), hasLength(2));
    },
  );
  test('stale submission rolls back without extra XP or event', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    final l = await r.lesson('a1-01');
    final s = await r.start(l.id);
    await r.answer(
      s.id,
      0,
      l.exercises.first,
      l.exercises.first.answers.first,
      total: 10,
    );
    await expectLater(
      r.answer(
        s.id,
        0,
        l.exercises.first,
        l.exercises.first.answers.first,
        total: 10,
      ),
      throwsStateError,
    );
    expect(await r.allEvents(), hasLength(1));
  });
  test(
    'disk database reopens with draft, position and XP; stale draft cannot overwrite next exercise',
    () async {
      final folder = await Directory.systemTemp.createTemp('orbitwords-test-');
      final file = File('${folder.path}/test.sqlite');
      var r = LearningRepository(
        AppDatabase(NativeDatabase(file)),
        loadAsset: (p) => File(p).readAsString(),
      );
      await r.initialize();
      final l = await r.lesson('a1-01');
      final s = await r.start(l.id);
      await r.answer(
        s.id,
        0,
        l.exercises.first,
        l.exercises.first.answers.first,
        total: 10,
      );
      await r.draft(s.id, 1, 'saved draft');
      await r.draft(s.id, 0, 'stale');
      await r.db.close();
      r = LearningRepository(
        AppDatabase(NativeDatabase(file)),
        loadAsset: (p) => File(p).readAsString(),
      );
      await r.initialize();
      final resumed = await r.start(l.id);
      expect(resumed.id, s.id);
      expect(resumed.position, 1);
      expect(resumed.draft, 'saved draft');
      expect((await r.progress()).xp, 10);
      await r.db.close();
      await folder.delete(recursive: true);
    },
  );
  test(
    'all 20 lessons complete offline; replay creates new session and retains mastery',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      for (final info in r.catalog) {
        final l = await r.lesson(info.id);
        final s = await r.start(l.id);
        for (var i = 0; i < l.exercises.length; i++) {
          expect(
            await r.answer(
              s.id,
              i,
              l.exercises[i],
              l.exercises[i].answers.first,
              total: l.exercises.length,
            ),
            isTrue,
          );
        }
        expect((await r.session(s.id)).done, isTrue);
      }
      final p = await r.progress();
      expect(p.xp, 2400);
      expect(p.completed, hasLength(20));
      expect(p.words, hasLength(60));
      expect(p.achievements, contains('Созвездие A1'));
      final replay = await r.start('a1-01');
      expect(replay.position, 0);
      expect(replay.done, isFalse);
    },
  );
  test(
    'removing a pack preserves progress, reinstall works without network',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await r.setSetting('name', 'Anna');
      await r.uninstall('a1-01');
      await r.initialize();
      expect(await r.installed(), hasLength(19));
      await expectLater(r.lesson('a1-01'), throwsStateError);
      await r.install(r.catalog.first);
      expect((await r.lesson('a1-01')).id, 'a1-01');
      expect(await r.setting('name'), 'Anna');
    },
  );
  test('reset removes private events sessions and account binding', () async {
    final r = memoryRepository();
    addTearDown(r.db.close);
    await r.initialize();
    await r.start('a1-01');
    await r.setSetting('owner', 'user');
    await r.review(r.vocabulary.values.first, 'hello');
    await r.reset();
    expect(await r.allEvents(), isEmpty);
    expect(await r.setting('owner'), isNull);
    expect(await r.db.select(r.db.sessions).get(), isEmpty);
  });
}
