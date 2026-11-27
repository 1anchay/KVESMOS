import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/first_flight_repository.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/first_flight.dart';
import 'package:orbitwords/domain/flight_story.dart';
import 'package:orbitwords/domain/knowledge.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/domain/story_dialogue.dart';

import 'support.dart';

class Radio {
  Radio(this.repository, this.scene, this.view);
  final StoryRepository repository;
  final StoryScene scene;
  StoryView view;
  StoryRun get run => view.run;
  StoryTask get task =>
      (scene.nodes[run.cursor] as StoryPractice).tasks[run.variant];

  static Future<Radio> open(
    StoryRepository repository,
    StoryScene scene,
  ) async => Radio(repository, scene, await repository.open(scene));

  Future<void> move(StoryMove move, [Object? input]) async {
    view = await repository.move(scene, run.revision, move, input);
  }

  Future<void> answer(String answer, {bool guided = false}) async {
    if (guided) await move(StoryMove.help);
    if (task.format == StoryFormat.order) {
      for (final token in answer.split(' ')) {
        await move(
          StoryMove.token,
          task.tokens.indexWhere(
            (value) => normalizeAnswer(value) == normalizeAnswer(token),
          ),
        );
      }
      await move(StoryMove.submit);
    } else {
      await move(StoryMove.submit, answer);
    }
    expect(view.verdict, StoryVerdict.accepted, reason: answer);
  }
}

Future<void> unlockScenes(LearningRepository repo) => repo.setSetting(
  FirstFlightRepository.key,
  jsonEncode(
    (FirstFlight()
          ..room = FlightRoom.bridge
          ..milestones.addAll([
            'unlocked',
            'charged',
            'wired',
            'powered',
            'requested',
            'locker',
            'navigable',
            'complete',
          ]))
        .toJson(),
  ),
);

Future<void> repair(
  StoryRepository repository, {
  bool guided = false,
  bool team = true,
}) async {
  final radio = await Radio.open(repository, FlightStory.repair);
  await radio.move(StoryMove.next);
  await radio.answer('I need a battery.', guided: guided);
  await radio.answer('I need a cable', guided: guided);
  await radio.answer('an', guided: guided);
  await radio.move(StoryMove.choice, team ? 'team' : 'solo');
  await radio.move(StoryMove.next);
  expect(radio.run.finished, isTrue);
}

Future<void> battery(StoryRepository repository, {bool guided = false}) async {
  final radio = await Radio.open(repository, FlightStory.found);
  await radio.move(StoryMove.next);
  await radio.answer('I have a battery.', guided: guided);
  await radio.answer('I need a battery', guided: guided);
  await radio.move(StoryMove.next);
}

Future<Radio> debrief(StoryRepository repository) async {
  final radio = await Radio.open(repository, FlightStory.debrief);
  await radio.move(StoryMove.next);
  await radio.move(StoryMove.next);
  expect(radio.run.cursor, 'message');
  return radio;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  final need = KnowledgeCatalog.skills['en:grammar:i-need']!;
  final request = KnowledgeCatalog.skills['en:phrase:need-battery']!;

  test('content resolves all five formats, valid references, and endings', () {
    KnowledgeCatalog.validate(KnowledgeCatalog.skills);
    final formats = <StoryFormat>{};
    for (final scene in FlightStory.scenes) {
      scene.validate();
      formats.addAll(
        scene.nodes.values.whereType<StoryPractice>().expand(
          (n) => n.tasks.map((t) => t.format),
        ),
      );
    }
    expect(formats, StoryFormat.values.toSet());
    final task =
        (FlightStory.power.nodes['not-ready'] as StoryPractice).tasks.single;
    expect(task.evaluate("ISN'T READY!"), StoryVerdict.accepted);
    expect(task.evaluate('I will check it'), StoryVerdict.unsupported);
    expect(
      () => const StoryScene(
        'broken',
        'Broken',
        StoryCue.beforeRepair,
        'start',
        {'start': StoryLine(StorySpeaker.orbi, 'Сигнал', next: 'missing')},
      ).validate(),
      throwsFormatException,
    );
  });

  for (final (name, days, guided, expected) in [
    ('new', 0, false, StoryFormat.answer),
    ('same-day', 0, false, StoryFormat.order),
    ('spaced', 1, false, StoryFormat.phrase),
    ('always-helped', 1, true, StoryFormat.answer),
  ]) {
    test('$name profile adapts from actual dialogue answers', () async {
      var now = DateTime.utc(2026, 11, 23);
      final learning = memoryRepository(now: () => now);
      addTearDown(learning.db.close);
      final repository = StoryRepository(learning);
      await expectLater(repository.open(FlightStory.debrief), throwsStateError);
      await unlockScenes(learning);
      if (name != 'new') {
        await repair(repository, guided: guided);
        now = now.add(Duration(days: days, seconds: 1));
        await battery(repository, guided: guided);
      }
      final conversation = await debrief(repository);
      expect(conversation.task.format, expected);
      final knowledge = await repository.knowledge.read();
      expect(knowledge.canUseEnglishSentence([request]), isFalse);
      expect(
        knowledge.canUseEnglishSentence([need, request]),
        name == 'spaced',
      );
      expect((await learning.progress()).xp, 0);
      if (guided) expect(knowledge.of(need).assisted, 3);
    });
  }

  test(
    'grammar error explains the rule and does not touch trust or another skill',
    () async {
      var now = DateTime.utc(2026, 11, 23);
      final learning = memoryRepository(now: () => now);
      addTearDown(learning.db.close);
      await unlockScenes(learning);
      final repository = StoryRepository(learning);
      await repair(repository);
      now = now.add(const Duration(days: 1, seconds: 1));
      await battery(repository);
      final conversation = await debrief(repository);
      expect(conversation.task.format, StoryFormat.phrase);
      await conversation.move(StoryMove.submit, 'needs a battery');
      expect(conversation.run.wrong, isTrue);
      expect(conversation.run.assisted, isTrue);
      await conversation.move(StoryMove.submit, 'needs a battery');
      final state = await repository.knowledge.read();
      expect(state.of(need).difficult, isTrue);
      expect(state.of(need).errors[KnowledgeError.grammar], 1);
      expect(state.of(request).stage(), KnowledgeStage.applied);
      expect(
        (FlightStory.debrief.nodes['message'] as StoryPractice).variant(state),
        0,
      );
      expect(conversation.view.save.trust(StorySpeaker.miko), 1);
      await conversation.move(StoryMove.example);
      expect(conversation.run.cursor, 'send');
      await conversation.move(StoryMove.choice, 'send-log');
      expect(conversation.run.cursor, 'log');
      expect(conversation.view.save.trust(StorySpeaker.pixie), 1);
    },
  );

  test(
    'restore keeps an unfinished draft, branch and exactly one credit',
    () async {
      final learning = memoryRepository();
      final target = memoryRepository();
      addTearDown(learning.db.close);
      addTearDown(target.db.close);
      await learning.initialize();
      await target.initialize();
      await unlockScenes(learning);
      final repository = StoryRepository(learning);
      await repair(repository, team: false);
      final radio = await Radio.open(repository, FlightStory.found);
      await radio.move(StoryMove.next);
      await radio.answer('I have a battery.');
      await radio.move(StoryMove.token, 1);
      await radio.move(StoryMove.help);
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final importer = ProgressTransfer(target, catalog);
      final file = await importer.validate(
        await ProgressTransfer(learning, catalog).export(),
      );
      await importer.restore(file);
      await importer.restore(file);
      final restored = StoryRepository(target);
      final resumed = await Radio.open(restored, FlightStory.found);
      expect(resumed.run.cursor, 'radio');
      expect(resumed.run.draft, [1]);
      expect(resumed.run.assisted, isTrue);
      final revision = resumed.run.revision;
      await Future.wait(
        List.generate(
          2,
          (_) => restored.move(FlightStory.found, revision, StoryMove.example),
        ),
      );
      expect((await restored.knowledge.read()).of(need).assisted, 1);
      final ending = await debrief(restored);
      expect(ending.run.path, ['memory', 'direct', 'message']);
      await ending.answer('I need a battery.', guided: true);
      await ending.move(StoryMove.choice, 'send-log');
      expect(ending.run.cursor, 'send');
      expect(ending.view.save.trust(StorySpeaker.miko), 0);
      await importer.restore(file);
      expect((await restored.read()).runs['battery']!.cursor, 'confirmed');
      expect((await restored.knowledge.read()).of(need).assisted, 2);
    },
  );

  test(
    'a cold SQLite reopen resumes the same cursor and token draft',
    () async {
      final folder = await Directory.systemTemp.createTemp(
        'kvesmos-story-test-',
      );
      addTearDown(() => folder.delete(recursive: true));
      final file = File(
        '${folder.path}${Platform.pathSeparator}profile.sqlite',
      );
      LearningRepository open() =>
          LearningRepository(AppDatabase(NativeDatabase(file)));
      final first = open();
      await unlockScenes(first);
      final radio = await Radio.open(
        StoryRepository(first),
        FlightStory.repair,
      );
      await radio.move(StoryMove.next);
      await radio.answer('I need a battery.');
      await radio.move(StoryMove.token, 2);
      await radio.move(StoryMove.token, 4);
      await first.db.close();
      final second = open();
      addTearDown(second.db.close);
      final resumed = await Radio.open(
        StoryRepository(second),
        FlightStory.repair,
      );
      expect(resumed.run.cursor, 'cable');
      expect(resumed.run.draft, [2, 4]);
      expect(
        (await resumed.repository.knowledge.read()).of(request).independent,
        1,
      );
    },
  );

  test(
    'merging a different repair decision cannot import its trust-only ending',
    () async {
      final mine = memoryRepository();
      final theirs = memoryRepository();
      addTearDown(mine.db.close);
      addTearDown(theirs.db.close);
      await unlockScenes(mine);
      await unlockScenes(theirs);
      final local = StoryRepository(mine), remote = StoryRepository(theirs);
      await repair(local, team: false);
      await repair(remote);
      final ending = await debrief(remote);
      await ending.answer('I need a battery.');
      await ending.move(StoryMove.choice, 'send-log');
      final incoming = await remote.read();
      expect(incoming.trust(StorySpeaker.pixie), 1);
      final merged = (await local.read())..merge(incoming);
      expect(merged.trust(StorySpeaker.miko), 0);
      expect(merged.trust(StorySpeaker.pixie), 0);
      expect(StorySave.decode(merged.encode()).runs['debrief'], isNull);
    },
  );
}
