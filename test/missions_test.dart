import 'dart:convert';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/missions_repository.dart';
import 'package:orbitwords/domain/missions.dart';
import 'package:orbitwords/domain/progress.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test(
    'lesson and ten successful questions count once; errors do not undo work',
    () async {
      final r = memoryRepository(now: () => DateTime(2026, 10, 21, 12));
      addTearDown(r.db.close);
      final missions = MissionsRepository(r);
      await missions.reconcile();
      for (var i = 0; i < 9; i++) {
        await r.append(
          r.event('answer', {
            'session': 's',
            'exercise': 'e$i',
            'correct': true,
            'words': [],
          }),
        );
      }
      await r.append(
        r.event('answer', {
          'session': 's',
          'exercise': 'e0',
          'correct': true,
          'words': [],
        }),
      );
      await r.append(
        r.event('answer', {
          'session': 's',
          'exercise': 'wrong',
          'correct': false,
          'words': [],
        }),
      );
      await r.append(r.event('complete', {'session': 's', 'lesson': 'l'}));
      await r.append(r.event('complete', {'session': 's', 'lesson': 'l'}));
      var state = await missions.reconcile();
      expect(state.progress.answers, 9);
      expect(state.progress.lessons, 1);
      expect(state.awarded(DailyMission.all[0]), isTrue);
      expect(state.awarded(DailyMission.all[1]), isFalse);
      await r.append(
        r.event('answer', {
          'session': 's',
          'exercise': 'e9',
          'correct': true,
          'words': [],
        }),
      );
      state = await missions.reconcile();
      expect(state.progress.answers, 10);
      expect(state.inventory.grants, hasLength(2));
      final events = await r.allEvents();
      final xp = (await r.progress()).xp;
      await Future.wait([
        missions.reconcile(),
        missions.reconcile(),
        missions.reconcile(),
      ]);
      expect((await missions.reconcile()).inventory.grants, hasLength(2));
      expect(await r.allEvents(), hasLength(events.length));
      expect((await r.progress()).xp, xp);
    },
  );
  test(
    'review requires five distinct previously seen words; mistakes count as practice',
    () async {
      var clock = DateTime(2026, 10, 21, 10);
      final r = memoryRepository(now: () => clock);
      addTearDown(r.db.close);
      await r.initialize();
      final missions = MissionsRepository(r);
      await missions.reconcile();
      final words = r.vocabulary.values.take(6).toList();
      await r.append(
        r.event('answer', {
          'session': 'lesson',
          'exercise': 'intro',
          'correct': true,
          'words': words.take(5).map((w) => w.id).toList(),
        }),
      );
      clock = clock.add(const Duration(seconds: 1));
      for (var i = 0; i < 5; i++) {
        await r.review(words[0], 'wrong');
      }
      var state = await missions.reconcile();
      expect(state.progress.reviewed, hasLength(1));
      await r.review(words[5], 'wrong');
      state = await missions.reconcile();
      expect(state.progress.reviewed, hasLength(1));
      for (final word in words.skip(1).take(4)) {
        await r.review(word, 'wrong');
      }
      state = await missions.reconcile();
      expect(state.progress.reviewed, hasLength(5));
      expect(state.awarded(DailyMission.all[2]), isTrue);
      expect(state.inventory.grants.values.single.kind, 'nebula');
    },
  );
  test(
    'first activation includes today but not previous days; midnight resets counters, not rewards',
    () async {
      var clock = DateTime(2026, 10, 20, 23, 59);
      final r = memoryRepository(now: () => clock);
      addTearDown(r.db.close);
      await r.append(r.event('complete', {'session': 'old', 'lesson': 'l'}));
      clock = DateTime(2026, 10, 21, 23, 59);
      await r.append(r.event('complete', {'session': 'today', 'lesson': 'l'}));
      final missions = MissionsRepository(r);
      var state = await missions.reconcile();
      expect(state.inventory.grants, hasLength(1));
      expect(state.progress.lessons, 1);
      clock = DateTime(2026, 10, 22);
      state = await missions.reconcile();
      expect(state.day, '2026-10-22');
      expect(state.progress.lessons, 0);
      expect(state.progress.answers, 0);
      expect(state.inventory.grants, hasLength(1));
      await r.append(
        r.event('complete', {'session': 'new-day', 'lesson': 'l'}),
      );
      state = await missions.reconcile();
      expect(state.inventory.grants, hasLength(2));
      clock = DateTime(2026, 10, 21, 23, 59);
      expect((await missions.reconcile()).inventory.grants, hasLength(2));
    },
  );
  test(
    'crash before reward reconciliation is recovered the next day after disk reopen',
    () async {
      final folder = await Directory.systemTemp.createTemp('kvesmos-missions-');
      var clock = DateTime(2026, 10, 21, 23, 59);
      LearningRepository connect() => LearningRepository(
        AppDatabase(NativeDatabase(File('${folder.path}/orbitwords.sqlite'))),
        now: () => clock,
        loadAsset: (p) => File(p).readAsString(),
      );
      var r = connect();
      await r.initialize();
      final lesson = await r.lesson('a1-01');
      final session = await r.start(lesson.id);
      await r.answer(
        session.id,
        0,
        lesson.exercises.first,
        lesson.exercises.first.answers.first,
        total: 10,
      );
      await r.draft(session.id, 1, 'draft from 0.2.0');
      await r.setSetting('owner', 'existing');
      final eventsBefore = jsonEncode(
        (await r.allEvents()).map((e) => e.toJson()).toList(),
      );
      await MissionsRepository(r).reconcile();
      // The lesson event is durable, but the process closes before granting its mission.
      await r.append(
        r.event('complete', {'session': 'finished', 'lesson': 'l'}),
      );
      final xp = (await r.progress()).xp;
      await r.db.close();
      clock = DateTime(2026, 10, 22, 8);
      r = connect();
      await r.initialize();
      final state = await MissionsRepository(r).reconcile();
      expect(state.progress.lessons, 0);
      expect(state.inventory.grants, hasLength(1));
      expect(
        state.inventory.grants.keys.single,
        DailyMission.all[0].grantId('2026-10-21'),
      );
      expect((await r.progress()).xp, xp);
      expect(
        jsonEncode(
          (await r.allEvents())
              .where((e) => e.kind == 'answer')
              .map((e) => e.toJson())
              .toList(),
        ),
        eventsBefore,
      );
      expect((await r.session(session.id)).draft, 'draft from 0.2.0');
      expect(await r.setting('owner'), 'existing');
      expect(await r.installed(), hasLength(20));
      expect(
        (await MissionsRepository(r).reconcile()).inventory.grants,
        hasLength(1),
      );
      await r.db.close();
      await folder.delete(recursive: true);
    },
  );
  test(
    'recorded event day is stable and duplicate questions do not count on a second date',
    () {
      final r = memoryRepository();
      final a = r.event('answer', {
        'session': 's',
        'exercise': 'e',
        'correct': true,
        'words': [],
      });
      final json = a.toJson()
        ..['day'] = '2026-10-21'
        ..['occurred_at'] = '2026-10-21T23:30:00-03:00';
      final b = Map<String, dynamic>.from(json)
        ..['id'] = 'second'
        ..['day'] = '2026-10-22'
        ..['occurred_at'] = '2026-10-22T03:00:00Z';
      final history = missionHistory(
        [LearningEvent.fromJson(json), LearningEvent.fromJson(b)],
        since: '2026-10-21',
        through: '2026-10-22',
      );
      expect(history['2026-10-21']!.answers, 1);
      expect(history['2026-10-22']!.answers, 0);
      addTearDown(r.db.close);
    },
  );
}
