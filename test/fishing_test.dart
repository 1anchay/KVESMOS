import 'dart:io';
import 'dart:math' as math;

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/fishing_repository.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/fishing.dart';
import 'package:orbitwords/domain/fishing_story.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/domain/story_dialogue.dart';
import 'package:uuid/uuid.dart';

import 'fishing_fixture.dart';
import 'support.dart';

void advanceTo(FishingGame game, FishingPhase phase) {
  for (var i = 0; i < 450 && game.phase != phase; i++) {
    game.advance(const Duration(milliseconds: 25));
  }
  expect(game.phase, phase);
}

void cast(FishingGame game, {double bearing = .18, int milliseconds = 670}) {
  game.aim();
  game.point(bearing);
  game.charge();
  game.advance(Duration(milliseconds: milliseconds));
  game.cast();
}

class _TailRandom implements math.Random {
  @override
  double nextDouble() => .99999;
  @override
  bool nextBool() => true;
  @override
  int nextInt(int max) => max - 1;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);

  test('cast, pause, flight, missed bite and a controlled catch', () {
    final game = FishingGame(random: math.Random(18));
    game.strike();
    expect(game.phase, FishingPhase.preparation);
    cast(game);
    expect(game.phase, FishingPhase.casting);
    advanceTo(game, FishingPhase.flight);
    expect(game.hasLure, true);
    advanceTo(game, FishingPhase.waiting);
    advanceTo(game, FishingPhase.bite);
    final before = game.elapsed;
    game.pause();
    game.advance(const Duration(minutes: 2));
    game.strike();
    expect(game.phase, FishingPhase.bite);
    expect(game.elapsed, before);
    game.resume();
    game.advance(const Duration(seconds: 3));
    expect(game.result?.escape, FishingEscape.missed);

    cast(game);
    advanceTo(game, FishingPhase.bite);
    game.strike();
    expect(game.phase, FishingPhase.hooked);
    advanceTo(game, FishingPhase.fighting);
    for (var i = 0; i < 400 && game.phase == FishingPhase.fighting; i++) {
      game.reel((.54 - .08 - game.resistance * .53) / .71);
      game.advance(const Duration(milliseconds: 25));
    }
    expect(game.phase, FishingPhase.caught);
    final landed = game.result!;
    expect(
      landed.grams,
      inInclusiveRange(landed.fish!.minGrams, landed.fish!.maxGrams),
    );
    game.strike();
    game.cast();
    expect(game.result, same(landed));
    game.finish();
    expect(game.phase, FishingPhase.finished);
    expect(game.result, same(landed));
  });

  test(
    'comfort extends a bite and precision gear unlocks the deep encounter',
    () {
      final standard = FishingGame(random: math.Random(32));
      final comfort = FishingGame(random: math.Random(32))..comfort = true;
      cast(standard);
      cast(comfort, milliseconds: 1018);
      advanceTo(standard, FishingPhase.bite);
      advanceTo(comfort, FishingPhase.bite);
      expect(comfort.reactionWindow, greaterThan(standard.reactionWindow));
      final delay = Duration(
        milliseconds: (standard.reactionWindow * 1000).round() + 100,
      );
      standard.advance(delay);
      comfort.advance(delay);
      expect(standard.phase, FishingPhase.escaped);
      expect(comfort.phase, FishingPhase.bite);

      final scout = FishingGame(random: _TailRandom())
        ..bait = FishingBait.prism;
      final compass = FishingGame(random: _TailRandom())
        ..bait = FishingBait.prism
        ..rod = FishingRod.compass;
      cast(scout, bearing: .86, milliseconds: 1000);
      cast(compass, bearing: .86, milliseconds: 1000);
      expect(scout.depth, lessThan(.84));
      expect(compass.depth, greaterThan(.84));
      advanceTo(compass, FishingPhase.bite);
      compass.strike();
      advanceTo(compass, FishingPhase.fighting);
      compass.reel(1);
      advanceTo(compass, FishingPhase.escaped);
      expect(compass.result!.escape, FishingEscape.snapped);

      final anchor = FishingGame(random: _TailRandom())
        ..bait = FishingBait.prism
        ..rod = FishingRod.anchor;
      cast(anchor, bearing: .86, milliseconds: 1210);
      advanceTo(anchor, FishingPhase.bite);
      anchor.strike();
      advanceTo(anchor, FishingPhase.fighting);
      for (var i = 0; i < 440 && anchor.phase == FishingPhase.fighting; i++) {
        anchor.reel((.58 - .08 - anchor.resistance * .53) / .71);
        anchor.advance(const Duration(milliseconds: 25));
      }
      expect(anchor.result?.fish, SpaceFish.leviathan);
      expect(anchor.result!.grams, greaterThan(scout.result?.grams ?? 0));
    },
  );

  test(
    'a trip commits each fish once and backup merges collections and gear',
    () async {
      final source = memoryRepository(), destination = memoryRepository();
      addTearDown(source.db.close);
      addTearDown(destination.db.close);
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final fishing = FishingRepository(source);
      const ids = Uuid();
      final trip = ids.v4(), catchId = ids.v4();
      await expectLater(fishing.depart(trip), throwsStateError);
      await saveCompletedFirstFlight(source);
      await fishing.depart(trip);
      const result = FishingResult.caught(
        SpaceFish.leviathan,
        9800,
        151,
        FishingZone.trench,
      );
      final records = await Future.wait([
        fishing.land(trip, catchId, result),
        fishing.land(trip, catchId, result),
      ]);
      expect(records.last.entry.id, records.first.entry.id);
      expect(records.last.save.catches.length, 1);
      expect(records.first.entry.discovery && records.first.entry.record, true);
      expect((await fishing.equipment(buy: FishingUpgrade.spool)).samples, 2);
      expect(
        (await fishing.equipment(rod: FishingRod.compass)).rod,
        FishingRod.scout,
      );
      await fishing.equipment(comfort: true, bait: FishingBait.prism);
      await fishing.finish(trip);
      await fishing.finish(trip);
      expect((await FishingRepository(source).read()).lastReport, trip);
      final stories = StoryRepository(source);
      const scene = FishingStory.report;
      var report = await stories.open(scene);
      report = await stories.move(scene, report.run.revision, StoryMove.next);
      report = await stories.move(
        scene,
        report.run.revision,
        StoryMove.submit,
        'I have a fish.',
      );
      report = await stories.move(
        scene,
        report.run.revision,
        StoryMove.choice,
        'share',
      );
      await stories.move(scene, report.run.revision, StoryMove.next);
      final backup = await ProgressTransfer(source, catalog).export();
      final restore = ProgressTransfer(destination, catalog);
      final file = await restore.validate(backup);
      await restore.restore(file);
      await restore.restore(file);
      final saved = await FishingRepository(destination).read();
      expect(saved.forSpecies(SpaceFish.leviathan).length, 1);
      expect(saved.earned, 5);
      expect(saved.samples, 2);
      expect(saved.record, 9800);
      expect(saved.comfort, true);
      expect(saved.bait, FishingBait.prism);
      final restoredStory = await StoryRepository(destination).read();
      expect(restoredStory.runs[scene.id]!.finished, true);
      expect(restoredStory.trust(StorySpeaker.pixie), 1);
    },
  );

  test(
    'story gates, beginner help and independent trust survive repeated use',
    () async {
      final learning = memoryRepository();
      addTearDown(learning.db.close);
      final stories = StoryRepository(learning),
          fishing = FishingRepository(learning);
      for (final scene in FishingStory.scenes) {
        scene.validate();
      }
      await expectLater(stories.open(FishingStory.briefing), throwsStateError);
      await saveCompletedFirstFlight(learning);
      final intro = await stories.open(FishingStory.briefing);
      final practice = await stories.move(
        FishingStory.briefing,
        intro.run.revision,
        StoryMove.next,
      );
      expect(practice.run.variant, 0);
      final wrong = await stories.move(
        FishingStory.briefing,
        practice.run.revision,
        StoryMove.submit,
        'I have a rod.',
      );
      expect(wrong.verdict, StoryVerdict.incorrect);
      expect(wrong.run.assisted, true);
      expect(wrong.save.trust(StorySpeaker.pixie), 0);
      await expectLater(stories.open(FishingStory.report), throwsStateError);
      await expectLater(
        stories.open(FishingStory.emptyReport),
        throwsStateError,
      );
      final trip = const Uuid().v4();
      await fishing.depart(trip);
      await fishing.finish(trip);
      final report = await stories.open(FishingStory.emptyReport);
      final choice = await stories.move(
        FishingStory.emptyReport,
        report.run.revision,
        StoryMove.next,
      );
      await stories.move(
        FishingStory.emptyReport,
        choice.run.revision,
        StoryMove.choice,
        'together',
      );
      final stale = await stories.move(
        FishingStory.emptyReport,
        choice.run.revision,
        StoryMove.choice,
        'together',
      );
      expect(stale.save.trust(StorySpeaker.pixie), 1);
      final grammar = await stories.knowledge.read();
      expect(
        grammar.of(KnowledgeCatalog.skills['en:grammar:i-need']!).stage(),
        KnowledgeStage.introduced,
      );
    },
  );

  test(
    'known grammar transfers only after the player builds a new sentence',
    () async {
      var clock = DateTime.utc(2026, 11, 22);
      final learning = memoryRepository(now: () => clock);
      addTearDown(learning.db.close);
      final stories = StoryRepository(learning);
      final skill = KnowledgeCatalog.skills['en:grammar:i-have']!;
      for (final context in ['battery', 'ship-recall']) {
        await stories.knowledge.check(
          skill,
          context: context,
          check: KnowledgeCheck.recall,
          correct: true,
        );
        clock = clock.add(const Duration(days: 1));
      }
      expect(
        (await stories.knowledge.read()).of(skill).stage(),
        KnowledgeStage.recalled,
      );
      final initial = (await learning.allEvents()).length;
      await saveCompletedFirstFlight(learning);
      final fishing = FishingRepository(learning);
      final trip = const Uuid().v4();
      await fishing.depart(trip);
      await fishing.land(
        trip,
        const Uuid().v4(),
        const FishingResult.caught(
          SpaceFish.goldenfin,
          400,
          28,
          FishingZone.reeds,
        ),
      );
      await fishing.finish(trip);
      expect((await learning.allEvents()).length, initial);
      const scene = FishingStory.report;
      final opened = await stories.open(scene);
      var view = await stories.move(scene, opened.run.revision, StoryMove.next);
      expect(view.run.variant, 1);
      for (final index in [2, 4, 3, 0]) {
        view = await stories.move(
          scene,
          view.run.revision,
          StoryMove.token,
          index,
        );
      }
      final outcome = await stories.move(
        scene,
        view.run.revision,
        StoryMove.submit,
      );
      expect(outcome.verdict, StoryVerdict.accepted);
      expect(
        (await stories.knowledge.read()).of(skill).stage(),
        KnowledgeStage.applied,
      );
      expect(outcome.save.trust(StorySpeaker.pixie), 0);
    },
  );

  test(
    'reopening SQLite keeps the landed fish and unfinished expedition',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kvesmos-fishing-',
      );
      final path = File('${directory.path}/profile.sqlite');
      addTearDown(() async {
        if (await path.exists()) await path.delete();
        await directory.delete();
      });
      final trip = const Uuid().v4();
      final first = LearningRepository(AppDatabase(NativeDatabase(path)));
      try {
        await saveCompletedFirstFlight(first);
        final fishing = FishingRepository(first);
        await fishing.depart(trip);
        await fishing.land(
          trip,
          const Uuid().v4(),
          const FishingResult.caught(
            SpaceFish.mossfin,
            580,
            31,
            FishingZone.reeds,
          ),
        );
      } finally {
        await first.db.close();
      }
      final reopened = LearningRepository(AppDatabase(NativeDatabase(path)));
      try {
        final save = await FishingRepository(reopened).read();
        expect(save.activeTrip, trip);
        expect(save.forTrip(trip).single.fish, SpaceFish.mossfin);
        expect(save.record, 580);
      } finally {
        await reopened.db.close();
      }
    },
  );
}
