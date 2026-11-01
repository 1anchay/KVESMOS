import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/practice_repository.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/domain/progress.dart';
import 'package:orbitwords/domain/reminders.dart';
import 'package:orbitwords/services/sync.dart';
import 'support.dart';
import 'sync_test.dart' show FakeRemote;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  test(
    '40 installed lessons: separate catalogs, authored content and full scoring',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      expect(await r.installed(), hasLength(40));
      for (final c in StudyCourse.all) {
        await r.selectCourse(c.id);
        expect(r.catalog, hasLength(c.lessons));
        for (final info in r.catalog) {
          final run = await r.startLesson(info.id), lesson = run.lesson;
          expect(lesson.exercises, hasLength(10));
          expect(lesson.teachingSteps.length, greaterThanOrEqualTo(3));
          expect(lesson.objective, isNotEmpty);
          expect(
            lesson.exercises.map((e) => e.type).toSet().length,
            greaterThanOrEqualTo(7),
          );
          for (var i = 0; i < 10; i++) {
            final e = lesson.exercises[i];
            expect(
              e.wordIds.every((id) => id.startsWith('${c.language}:')),
              true,
            );
            expect(e.answers, isNotEmpty);
            expect(e.explanation, isNotEmpty);
            await r.answer(run.session.id, i, e, e.answers.first, total: 10);
          }
        }
        expect((await r.progress()).xp, c.lessons * 120);
        expect((await r.progress()).completed, hasLength(c.lessons));
      }
      expect((await r.globalProgress()).xp, 4800);
    },
  );
  test(
    '0.10 ledger, deleted pack, pinned draft and preferences survive additive upgrade',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      // Exact old payload shape, no course metadata or version markers.
      await r.setSetting('installed', 'true');
      await r.setSetting('name', 'Старый профиль');
      for (var n = 1; n <= 20; n++) {
        final id = 'a1-${n.toString().padLeft(2, '0')}';
        if (n != 20) {
          await r.installRaw(
            id,
            await File('assets/courses/$id.json').readAsString(),
          );
        }
      }
      final old = await r.start('a1-01');
      await r.draft(old.id, 0, 'saved');
      final event = LearningEvent(
        id: 'legacy-id',
        kind: 'answer',
        occurredAt: '2026-10-28T12:00:00Z',
        day: '2026-10-28',
        data: {
          'session': old.id,
          'exercise': 'old-e1',
          'lesson': 'a1-01',
          'correct': true,
          'words': ['en:hello'],
        },
      );
      await r.append(event);
      final before = jsonEncode((await r.allEvents()).single.toJson());
      await r.initialize();
      await r.initialize();
      expect(await r.installed(), hasLength(39));
      expect(await r.installed(), isNot(contains('a1-20')));
      expect(jsonEncode((await r.allEvents()).single.toJson()), before);
      expect((await r.startLesson('a1-01')).session.id, old.id);
      expect((await r.session(old.id)).draft, 'saved');
      expect((await r.progress()).xp, 10);
      await r.uninstall('es-a1-01');
      await r.initialize();
      expect(await r.installed(), isNot(contains('es-a1-01')));
      await r.selectCourse('ru-es');
      expect((await r.progress()).xp, 0);
    },
  );
  test(
    'switch keeps simultaneous drafts, streaks, practice and global grants; sync deduplicates',
    () async {
      var now = DateTime(2026, 10, 28, 12);
      final r = memoryRepository(now: () => now), app = AppController(r);
      addTearDown(() async {
        app.dispose();
        await r.db.close();
      });
      await app.initialize();
      final drafts = <String, String>{};
      for (final c in StudyCourse.all) {
        await app.selectCourse(c.id);
        final run = await r.startLesson(r.catalog.first.id);
        drafts[c.id] = run.session.id;
        await r.answer(
          run.session.id,
          0,
          run.lesson.exercises.first,
          run.lesson.exercises.first.answers.first,
          total: 10,
        );
        await r.draft(run.session.id, 1, c.id);
        expect((await r.progress()).xp, 10);
        now = now.add(const Duration(days: 1));
      }
      final grants = app.inventory.encode();
      for (final c in StudyCourse.all) {
        await app.selectCourse(c.id);
        expect(
          (await r.startLesson(r.catalog.first.id)).session.id,
          drafts[c.id],
        );
        expect((await r.session(drafts[c.id]!)).draft, c.id);
        final practice = await PracticeRepository(r).open();
        expect(
          (practice['words'] as List).every(
            (w) => '$w'.startsWith('${c.language}:'),
          ),
          true,
        );
        expect(app.progress.xp, 10);
        expect(app.globalProgress.xp, 30);
        expect(app.inventory.encode(), grants);
      }
      expect(app.progress.streak(now), 1); // German studied yesterday.
      await app.selectCourse('ru-en');
      expect(app.progress.streak(now), 0);
      final remote = FakeRemote(), other = memoryRepository();
      addTearDown(other.db.close);
      await other.initialize();
      await SyncService(r, remote).run();
      final copy = SyncService(other, remote);
      await copy.run();
      await copy.run();
      expect((await other.globalProgress()).xp, 30);
      await other.selectCourse('ru-es');
      expect((await other.progress()).xp, 10);
      expect((await r.globalProgress()).xp, 30);
      expect((await r.allEvents()).map((e) => e.courseId).toSet(), {
        'ru-en',
        'ru-es',
        'ru-de',
      });
    },
  );
  test(
    'reminder policy: opt-in, weekdays, quiet boundary, pause and completed course goal',
    () {
      final date = DateTime(2026, 10, 29, 19);
      expect(const ReminderPreferences().eligible(date, 0, 50), false);
      final p = const ReminderPreferences(
        enabled: true,
        weekdays: {4},
        courseId: 'ru-es',
      );
      expect(p.eligible(date, 49, 50), true);
      expect(p.eligible(date, 50, 50), false);
      expect(p.eligible(date.add(const Duration(days: 1)), 0, 50), false);
      expect(p.copyWith(minute: 1320).timeIsQuiet, true);
      expect(p.copyWith(minute: 480).timeIsQuiet, false);
      expect(
        p.copyWith(pausedUntil: '2026-10-30').eligible(date, 0, 50),
        false,
      );
      expect(ReminderPreferences.decode(p.encode()).courseId, 'ru-es');
      expect(ReminderPreferences.decode('{broken').enabled, false);
    },
  );
}
