import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/knowledge_repository.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/domain/rewards.dart';

import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  final door = KnowledgeCatalog.flight[FlightWord.door]!;
  final key = KnowledgeCatalog.flight[FlightWord.key]!;

  test('skill graph rejects missing and cyclic prerequisites', () {
    KnowledgeCatalog.validate(KnowledgeCatalog.skills);
    expect(
      () => KnowledgeCatalog.validate({
        'a': const KnowledgeSkill(
          'a',
          KnowledgeKind.grammar,
          'A',
          requires: ['b'],
        ),
      }),
      throwsFormatException,
    );
    expect(
      () => KnowledgeCatalog.validate({
        'a': const KnowledgeSkill(
          'a',
          KnowledgeKind.grammar,
          'A',
          requires: ['b'],
        ),
        'b': const KnowledgeSkill(
          'b',
          KnowledgeKind.grammar,
          'B',
          requires: ['a'],
        ),
      }),
      throwsFormatException,
    );
    expect(
      KnowledgeSnapshot(const {}).canUseEnglishSentence([door.skill]),
      isFalse,
    );
  });

  test(
    'exposure, assisted answers, same-day retries, recall and transfer stay distinct',
    () async {
      var now = DateTime.utc(2026, 11, 26, 11);
      final learning = memoryRepository(now: () => now);
      addTearDown(learning.db.close);
      final repo = KnowledgeRepository(learning);
      Future<KnowledgeState> current() async =>
          (await repo.read()).of(door.skill);
      Future<void> record(
        KnowledgeCheck check, {
        bool helped = false,
        bool correct = true,
        String context = 'airlock',
      }) {
        now = now.add(const Duration(milliseconds: 20));
        return repo.check(
          door.skill,
          context: context,
          check: check,
          correct: correct,
          assisted: helped,
          error: correct ? null : KnowledgeError.meaning,
        );
      }

      expect((await current()).firstSeen, isNull);
      expect((await current()).label(door, ImmersionMode.extended), 'дверь');
      await repo.encounter(door.skill, 'airlock');
      await repo.encounter(door.skill, 'airlock');
      await repo.favorite(door.skill, true);
      expect((await learning.allEvents()).length, 2);
      expect((await current()).attempts, 0);
      expect(
        (await current()).label(door, ImmersionMode.adaptive),
        'дверь · Door',
      );
      await record(KnowledgeCheck.recall, helped: true);
      expect((await current()).stage(), KnowledgeStage.introduced);
      expect((await current()).nextReview, isNull);
      await record(KnowledgeCheck.recognition);
      await record(KnowledgeCheck.recall);
      expect((await current()).stage(), KnowledgeStage.recognized);
      expect((await current()).review.repetitions, 1);
      expect(
        (await current()).label(door, ImmersionMode.adaptive),
        'Door · дверь',
      );

      now = now.add(const Duration(days: 1));
      await record(KnowledgeCheck.recall);
      expect((await current()).stage(), KnowledgeStage.recalled);
      expect((await current()).label(door, ImmersionMode.adaptive), 'Door');
      expect(
        (await current()).label(door, ImmersionMode.beginner),
        'дверь · Door',
      );
      expect((await current()).review.interval, 6);
      expect(
        (await current()).stage(const ImmersionPolicy(recallDays: 3)),
        KnowledgeStage.recognized,
      );
      await record(KnowledgeCheck.transfer, context: 'bridge');
      expect((await current()).stage(), KnowledgeStage.applied);
      expect((await current()).confidence, closeTo(2 / 3, .001));
      now = now.add(const Duration(seconds: 1));
      await record(KnowledgeCheck.recognition, correct: false);
      expect((await current()).difficult, isTrue);
      expect(
        (await current()).label(door, ImmersionMode.extended),
        'дверь · Door',
      );
      expect((await current()).review.interval, 1);
      expect((await current()).errors[KnowledgeError.meaning], 1);
      expect((await repo.read()).practice(now).first.skill.id, door.skill.id);
      expect((await repo.read()).of(key.skill).firstSeen, isNull);
      expect(
        (await KnowledgeRepository(learning, course: 'ru-fr').read()).states,
        isEmpty,
      );
      expect((await learning.progress()).xp, 0);
      expect(await learning.pending(), isEmpty);
    },
  );

  test('a known single-word lesson review uses the same schedule', () async {
    final repo = memoryRepository();
    addTearDown(repo.db.close);
    await repo.append(
      repo.event('answer', {
        'session': 'practice',
        'exercise': 'review:en:door',
        'correct': true,
        'words': ['en:door'],
        'rehearsal': true,
      }),
    );
    final knowledge = (await KnowledgeRepository(repo).read()).of(door.skill);
    expect(knowledge.stage(), KnowledgeStage.recognized);
    expect(
      knowledge.nextReview,
      (await repo.progress()).words['en:door']!.next,
    );
  });

  test(
    'backup restores learned entries and favorites without re-crediting',
    () async {
      final source = memoryRepository();
      final target = memoryRepository();
      addTearDown(source.db.close);
      addTearDown(target.db.close);
      await source.initialize();
      await target.initialize();
      final knowledge = KnowledgeRepository(source);
      await knowledge.restoreEncounters([
        door.skill,
        key.skill,
      ], 'first-flight:legacy');
      await knowledge.restoreEncounters([
        door.skill,
        key.skill,
      ], 'first-flight:legacy');
      expect((await knowledge.read()).of(key.skill).attempts, 0);
      await knowledge.favorite(key.skill, true);
      await knowledge.setMode(ImmersionMode.extended);
      await knowledge.check(
        door.skill,
        context: 'journal-recall',
        check: KnowledgeCheck.recall,
        correct: true,
      );
      final firstFlight = FirstFlight()
        ..revision = 2
        ..learned.addAll([FlightWord.door, FlightWord.key]);
      await source.setSetting(
        FirstFlightRepository.key,
        jsonEncode(firstFlight.toJson()),
      );
      final inventory = Inventory()
        ..grants[FirstFlight.reward] = const ChestGrant(
          FirstFlight.reward,
          'explorer',
        );
      await source.setSetting(RewardsRepository.storageKey, inventory.encode());
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final importer = ProgressTransfer(target, catalog);
      final bytes = await ProgressTransfer(source, catalog).export();
      final file = await importer.validate(bytes);
      expect((await KnowledgeRepository(target).read()).states, isEmpty);
      await importer.restore(file);
      await importer.restore(file);
      final restored = KnowledgeRepository(target);
      expect(await restored.mode(), ImmersionMode.extended);
      expect((await restored.read()).of(key.skill).favorite, isTrue);
      expect((await restored.read()).of(door.skill).independent, 1);
      expect((await FirstFlightRepository(target).read()).learned, {
        FlightWord.door,
        FlightWord.key,
      });
      expect(
        Inventory.decode(
          await target.setting(RewardsRepository.storageKey),
        ).grants.keys,
        [FirstFlight.reward],
      );
      expect((await target.progress()).xp, 0);
      expect(await target.pending(), isEmpty);
    },
  );
}
