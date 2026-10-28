import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/adventures_repository.dart';
import 'package:orbitwords/domain/space_adventures.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test('authoring schema validates stable steps and taught vocabulary', () {
    for (final adventure in SpaceAdventure.all) {
      adventure.validate();
    }
    expect(SpaceAdventure.all.map((a) => a.id).toSet().length, 3);
  });
  for (final adventure in SpaceAdventure.all) {
    test(
      '${adventure.id}: durable actions, errors, concurrency, replay and old drafts',
      () async {
        var now = DateTime(2026, 10, 28, 12);
        final r = memoryRepository(now: () => now);
        addTearDown(r.db.close);
        await r.initialize();
        final game = AdventuresRepository(r);
        await expectLater(game.act(adventure, 0, 'move'), throwsStateError);
        for (final id in adventure.prerequisites) {
          final lesson = await r.startLesson(id);
          for (var i = 0; i < lesson.lesson.exercises.length; i++) {
            final e = lesson.lesson.exercises[i];
            await r.answer(
              lesson.session.id,
              i,
              e,
              e.answers.first,
              total: lesson.lesson.exercises.length,
            );
          }
        }
        final draft = await r.start('a1-20');
        await r.draft(draft.id, 0, 'unchanged draft');
        await r.setSetting(
          'kvesmos.inventory.v1',
          '{"version":1,"grants":{},"equipped":{}}',
        );
        final oldEvents = (await r.allEvents())
            .map((e) => jsonEncode(e.toJson()))
            .toList();
        final before = (await r.progress()).xp;
        var state = await game.read(adventure.id);
        for (var run = 0; run < 2; run++) {
          for (final step in adventure.steps) {
            state = await game.act(
              adventure,
              state.revision,
              'move',
              value: step.target,
              x: .25,
              y: .63,
            );
            state = await game.act(adventure, state.revision, 'hint');
            expect(
              (await AdventuresRepository(r).read(adventure.id)).encode(),
              state.encode(),
            );
            if (step.assessed) {
              state = await game.act(
                adventure,
                state.revision,
                'submit',
                value: 'wrong',
              );
              expect(state.errors[step.id], 1);
            }
            if (step.action == AdventureAction.assemble) {
              for (final tile in step.answer.split(' ')) {
                state = await game.act(
                  adventure,
                  state.revision,
                  'tile',
                  value: tile,
                );
              }
            }
            final results = await Future.wait([
              game.act(adventure, state.revision, 'submit', value: step.answer),
              game.act(adventure, state.revision, 'submit', value: step.answer),
            ]);
            expect(results[0].encode(), results[1].encode());
            state = results.last;
          }
          expect(state.completed, true);
          expect((await r.progress()).xp, before + adventure.xp);
          expect((await r.session(draft.id)).draft, 'unchanged draft');
          expect(
            await r.setting('kvesmos.inventory.v1'),
            '{"version":1,"grants":{},"equipped":{}}',
          );
          expect(
            (await r.allEvents()).map((e) => jsonEncode(e.toJson())),
            containsAll(oldEvents),
          );
          if (run == 0) {
            now = now.add(const Duration(days: 1));
            state = await game.act(adventure, state.revision, 'replay');
          }
        }
        expect(
          (await r.allEvents()).where((e) => e.kind == 'adventure_complete'),
          hasLength(1),
        );
        expect((await r.progress()).dailyXp.containsKey('2026-10-29'), false);
      },
    );
  }
  test(
    'failed transaction rolls back state and credit; unknown version is preserved',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await r.append(
        r.event('complete', {'session': 'fixture', 'lesson': 'a1-01'}),
      );
      final game = AdventuresRepository(r), a = SpaceAdventure.all.first;
      var s = await game.act(a, 0, 'move', value: 'guide');
      s = await game.act(a, s.revision, 'submit');
      s = await game.act(a, s.revision, 'move', value: 'guide');
      final before = s.encode(), xp = (await r.progress()).xp;
      await r.db.customStatement(
        "CREATE TRIGGER fail_adventure BEFORE UPDATE ON settings WHEN NEW.key LIKE 'kvesmos.adventure.%' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(
        game.act(a, s.revision, 'submit', value: 'Hello!'),
        throwsA(anything),
      );
      expect((await game.read(a.id)).encode(), before);
      expect((await r.progress()).xp, xp);
      await r.db.customStatement('DROP TRIGGER fail_adventure');
      await r.setSetting(AdventuresRepository.key(a.id), '{"version":99}');
      await expectLater(game.read(a.id), throwsStateError);
      expect(await r.setting(AdventuresRepository.key(a.id)), '{"version":99}');
    },
  );
}
