import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/practice_repository.dart';
import 'package:orbitwords/domain/journey.dart';
import 'package:orbitwords/domain/progress.dart';
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  test(
    'five regions cover the unchanged course; checkpoints do not rescore',
    () async {
      final repo = memoryRepository();
      await repo.initialize();
      final ids = [
        for (final r in JourneyRegion.all)
          ...r.lessons(repo.catalog).map((l) => l.id),
      ];
      expect(ids, repo.catalog.map((l) => l.id));
      expect(ids.toSet(), hasLength(20));
      final lesson = await repo.startLesson('a1-01');
      for (var i = 0; i < 5; i++) {
        await repo.answer(
          lesson.session.id,
          i,
          lesson.lesson.exercises[i],
          lesson.lesson.exercises[i].answers.first,
          total: 10,
        );
      }
      final resumed = await repo.startLesson('a1-01');
      expect(resumed.session.id, lesson.session.id);
      expect(resumed.session.position, 5);
      expect((await repo.progress()).xp, 50);
      await repo.setSetting(
        'kvesmos.stage.seen.v1:${lesson.session.id}:5',
        'true',
      );
      expect((await repo.progress()).xp, 50);
      expect(
        resumed.lesson.exercises.map((e) => e.id),
        lesson.lesson.exercises.map((e) => e.id),
      );
      await repo.db.close();
    },
  );
  test(
    'day 0, 1, 7, 30: voluntary expeditions preserve rewards and never duplicate',
    () async {
      var now = DateTime(2026, 10, 26, 12);
      final repo = memoryRepository(now: () => now);
      final app = AppController(repo);
      await app.initialize();
      Future<void> study(int day) async {
        now = DateTime(2026, 10, 26, 12).add(Duration(days: day));
        await repo.append(
          repo.event('answer', {
            'session': 's$day',
            'exercise': 'e$day',
            'correct': true,
            'words': [],
          }),
        );
        await app.refresh();
      }

      await study(0);
      await study(1);
      await study(3);
      expect(
        app.inventory.grants.keys.where((k) => k.startsWith('expedition:')),
        isEmpty,
      );
      final xp = app.progress.xp;
      await repo.setSetting('kvesmos.expeditions.optin.v1', 'true');
      await app.refresh();
      final first = 'expedition:v1:week:2026-10-26';
      expect(app.inventory.grants.containsKey(first), true);
      await Future.wait([app.rewards.reconcile(), app.rewards.reconcile()]);
      await app.refresh();
      expect(app.inventory.grants.keys.where((k) => k == first), hasLength(1));
      expect(app.progress.xp, xp);
      await study(7);
      expect(Expedition.fromEvents(await repo.allEvents(), now).first.count, 1);
      await study(30);
      expect(app.inventory.grants.containsKey(first), true);
      now = DateTime(2026, 10, 29, 12);
      await app.refresh();
      expect(app.inventory.grants.keys.where((k) => k == first), hasLength(1));
      expect(await repo.setting('reminders'), isNull);
      app.dispose();
      await repo.db.close();
    },
  );
  test(
    'a closed month and week recover once after a missed reconciliation',
    () async {
      var now = DateTime(2026, 10, 26, 12);
      final repo = memoryRepository(now: () => now);
      final app = AppController(repo);
      await app.initialize();
      await repo.setSetting('kvesmos.expeditions.optin.v1', 'true');
      await app.refresh();
      for (var i = 0; i < 8; i++) {
        now = DateTime(2026, 10, 27 + i % 3, 12);
        await repo.append(
          repo.event('answer', {
            'session': 'closed-$i',
            'exercise': 'q',
            'correct': true,
            'words': [],
          }),
        );
        await repo.append(
          repo.event('complete', {
            'session': 'closed-$i',
            'lesson': repo.catalog[i].id,
          }),
        );
      }
      // The process dies before rewards are reconciled, and reopens next month.
      now = DateTime(2026, 11, 3, 12);
      await app.refresh();
      final ids = app.inventory.grants.keys
          .where((k) => k.startsWith('expedition:'))
          .toSet();
      expect(ids, {
        'expedition:v1:week:2026-10-26',
        'expedition:v1:month:2026-10',
      });
      final xp = app.progress.xp;
      await app.refresh();
      expect(
        app.inventory.grants.keys.where((k) => ids.contains(k)),
        hasLength(2),
      );
      expect(app.progress.xp, xp);
      expect(Expedition.fromEvents(await repo.allEvents(), now).last.count, 0);
      app.dispose();
      await repo.db.close();
    },
  );
  test(
    'practice restores queue and feedback, retries and a legacy review cannot farm XP',
    () async {
      var now = DateTime(2026, 10, 26, 12);
      final repo = memoryRepository(now: () => now);
      await repo.initialize();
      final word = repo.vocabulary.values.first;
      await repo.append(
        repo.event('answer', {
          'session': 'old',
          'exercise': 'q',
          'correct': false,
          'words': [word.id],
        }),
      );
      final p = PracticeRepository(repo);
      final state = await p.open();
      expect(state['words'], [word.id]);
      expect((state['reasons'] as List).single, contains('ошибок 1'));
      await p.advance(0, 0, '');
      await p.advance(0, 1, 'wrong');
      expect((await PracticeRepository(repo).open())['correct'], false);
      await p.advance(0, 2, '');
      await Future.wait([p.advance(0, 1, word.en), p.advance(0, 1, word.en)]);
      expect((await repo.progress()).xp, 10);
      expect((await p.open())['credited'], 10);
      await p.advance(0, 2, '');
      expect((await p.open())['index'], 1);
      await repo.review(word, word.en);
      expect((await repo.progress()).xp, 10);
      now = now.add(const Duration(days: 1));
      expect(
        (await p.open())['index'],
        0,
        reason: 'a new day must not reopen yesterday\'s completed practice',
      );
      await repo.review(word, word.en);
      expect((await repo.progress()).xp, 20);
      final before = (await repo.progress()).xp;
      await repo.append(
        LearningEvent(
          id: 'legacy',
          kind: 'answer',
          occurredAt: now.toUtc().toIso8601String(),
          day: dayKey(now),
          data: {
            'session': 'legacy-v06',
            'exercise': 'review:${word.id}',
            'correct': true,
            'words': [word.id],
          },
        ),
      );
      final existing = (await repo.progress()).xp;
      expect(existing, before + 10);
      await repo.review(word, word.en);
      expect((await repo.progress()).xp, existing);
      await repo.db.close();
    },
  );
}
