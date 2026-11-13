import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/listening_repository.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/data/smart_practice_repository.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/domain/space_adventures.dart';
import 'package:orbitwords/domain/study_skills.dart';
import 'package:orbitwords/services/recorded_speech.dart';

import 'support.dart';

Future<void> finish(LearningRepository repo, String id) async {
  final run = await repo.startLesson(id);
  for (final (index, item) in run.lesson.exercises.indexed) {
    await repo.answer(
      run.session.id,
      index,
      item,
      item.answers.first,
      total: run.lesson.exercises.length,
    );
  }
}

Uint8List rewrite(Uint8List bytes, void Function(Map<String, dynamic>) edit) {
  final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
  final payload = jsonDecode(manifest['payload']) as Map<String, dynamic>;
  edit(payload);
  manifest['payload'] = jsonEncode(payload);
  manifest['sha256'] = sha256
      .convert(utf8.encode(manifest['payload']))
      .toString();
  return Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  final date = DateTime(2026, 11, 13, 12);
  final rewards = RewardCatalog(
    File('assets/kvesmos/catalog.json').readAsStringSync(),
  );

  Future<LearningRepository> profile() async {
    final repo = memoryRepository(now: () => date);
    addTearDown(repo.db.close);
    await repo.initialize();
    return repo;
  }

  test('smart practice retrieves old pinned questions by exact ID', () async {
    final repo = await profile();
    final id = repo.catalog.first.id;
    final old = await repo.lesson(id);
    final exercise = old.exercises.firstWhere(
      (e) => StudySkill.forExercise(e) == StudySkill.grammar,
    );
    final session = await repo.start(id);
    await repo.append(
      repo.event('answer', {
        'session': session.id,
        'exercise': exercise.id,
        'lesson': id,
        'correct': false,
        'words': exercise.wordIds,
      }),
    );
    final practice = SmartPracticeRepository(repo);
    final plan = await practice.plan();
    expect(plan.items.first.exercise.id, exercise.id);
    final state = (await practice.open())!;
    final restored = (await practice.material(state)).first;
    expect(restored.exercise.id, exercise.id);
    final transfer = ProgressTransfer(repo, rewards);
    await transfer.validate(await transfer.export());
    await practice.answer(state['run'], 0, restored, exercise.answers.first);
    expect(
      (await practice.plan()).report.evidence[StudySkill.grammar]!.unresolved,
      0,
    );
  });

  test(
    'two profiles merge all five courses, drafts, station states and consumed rewards',
    () async {
      final source = await profile();
      final target = await profile();
      await source.setSetting('name', 'Орбита');
      await source.setSetting('theme', 'dark');
      await source.setSetting('owner', 'private-identity');
      await source.setSetting('lastSync', 'private-sync');
      await source.setSetting('kvesmos.auth.token', 'private-token');
      final drafts = <String, String>{};
      for (final course in StudyCourse.all) {
        await source.selectCourse(course.id);
        await finish(source, source.catalog.first.id);
        final run = await source.startLesson(source.catalog[1].id);
        await source.draft(run.session.id, 0, jsonEncode({'text': course.id}));
        drafts[run.session.id] = course.id;
      }
      for (final adventure in SpaceAdventure.all) {
        await source.setSetting(
          'kvesmos.adventure.v1:${adventure.id}',
          AdventureState().encode(),
        );
      }
      final earned = await RewardsRepository(source, rewards).reconcile();
      final grant = earned.pending.first;
      final open = await RewardsRepository(source, rewards).openOnce(grant.id);
      expect(open.fresh, true);
      final bytes = await ProgressTransfer(source, rewards).export();
      expect(utf8.decode(bytes), isNot(contains('private-')));
      final transfer = ProgressTransfer(target, rewards);
      final file = await transfer.validate(bytes);
      final preview = await transfer.preview(file);
      expect(preview.freshProfile, true);
      expect(preview.drafts, 5);
      expect(preview.fileLessons, 5);
      expect(preview.opened, 1);
      await transfer.restore(file);
      expect(await target.setting('name'), 'Орбита');
      expect(await target.setting(LearningRepository.courseKey), 'ru-zh');
      expect(await target.installed(), hasLength(236));
      for (final row in drafts.entries) {
        expect(
          (await target.session(row.key)).draft,
          jsonEncode({'text': row.value}),
        );
        expect(
          await target.setting('kvesmos.session.material.v1:${row.key}'),
          isNotNull,
        );
      }
      expect(
        await target.settingsWithPrefix('kvesmos.adventure.v1:'),
        hasLength(3),
      );
      final targetRewards = RewardsRepository(target, rewards);
      expect((await targetRewards.openOnce(grant.id)).fresh, false);
      expect((await targetRewards.read()).owned, contains(open.item!.id));
      final before = await target.allEvents();
      await target.setSetting('name', 'Локальное имя');
      await transfer.restore(file);
      expect((await transfer.preview(file)).newEvents, 0);
      expect((await target.allEvents()).length, before.length);
      expect((await target.globalProgress()).xp, preview.mergedXp);
      expect(await target.setting('name'), 'Локальное имя');
      expect((await targetRewards.openOnce(grant.id)).fresh, false);
    },
  );

  test(
    'invalid, truncated, oversize and incompatible documents leave the DB untouched',
    () async {
      final repo = await profile();
      await finish(repo, repo.catalog.first.id);
      final run = await repo.start(repo.catalog[1].id);
      final transfer = ProgressTransfer(repo, rewards);
      final bytes = await transfer.export();
      final manifest = jsonDecode(utf8.decode(bytes)) as Map;
      manifest['version'] = 2;
      final incompatible = Uint8List.fromList(
        utf8.encode(jsonEncode(manifest)),
      );
      manifest['version'] = 1;
      manifest['sha256'] = 'broken';
      final checksum = Uint8List.fromList(utf8.encode(jsonEncode(manifest)));
      for (final invalid in [
        bytes.sublist(0, bytes.length ~/ 2),
        Uint8List(progressTransferMaxBytes + 1),
        incompatible,
        checksum,
        rewrite(bytes, (p) => (p['packs'] as Map).remove(run.lessonId)),
        rewrite(bytes, (p) => (p['events'] as List).first['id'] = 'broken'),
        rewrite(
          bytes,
          (p) => (p['settings'] as Map)['kvesmos.course.selected.v1'] = 'ru-xx',
        ),
        rewrite(bytes, (p) => (p['settings'] as Map)['owner'] = 'secret'),
      ]) {
        await expectLater(transfer.validate(invalid), throwsFormatException);
      }
      expect(await repo.setting('owner'), isNull);
      expect((await repo.globalProgress()).completed, {repo.catalog.first.id});
      expect((await repo.session(run.id)).done, false);
    },
  );

  test(
    'merge rollback preserves existing local draft and unions already owned cosmetics',
    () async {
      final source = await profile();
      final target = await profile();
      final first = source.catalog.first.id;
      final session = await source.startLesson(first);
      final repo = ProgressTransfer(target, rewards);
      final owned = rewards.items.take(2).toList();
      final milestone = rewards.milestones.first;
      final id = milestone['id'] as String;
      final kind = milestone['chest_id'] as String;
      await source.setSetting(
        RewardsRepository.storageKey,
        Inventory(grants: {id: ChestGrant(id, kind, owned.first.id)}).encode(),
      );
      await target.setSetting(
        RewardsRepository.storageKey,
        Inventory(grants: {id: ChestGrant(id, kind, owned.last.id)}).encode(),
      );
      final bytes = await ProgressTransfer(source, rewards).export();
      await repo.restore(await repo.validate(bytes));
      await target.draft(session.session.id, 0, '{"text":"local"}');
      final conflicting = rewrite(bytes, (p) {
        final row = (p['sessions'] as List).first as Map;
        final second = source.catalog[1].id;
        row['lessonId'] = second;
        (p['settings']
                as Map)['kvesmos.session.material.v1:${session.session.id}'] =
            (p['packs'] as Map)[second];
      });
      await expectLater(
        repo.restore(await repo.validate(conflicting)),
        throwsFormatException,
      );
      await repo.restore(await repo.validate(bytes));
      expect(
        (await target.session(session.session.id)).draft,
        '{"text":"local"}',
      );
      final inventory = await RewardsRepository(target, rewards).read();
      expect(inventory.owned, owned.map((i) => i.id).toSet());
      expect(inventory.grants, hasLength(1));
      expect(
        (await RewardsRepository(target, rewards).openOnce(id)).fresh,
        false,
      );
    },
  );

  test(
    'real errors change the plan while retries award no XP or extra skill observations',
    () async {
      final repo = await profile();
      final smart = SmartPracticeRepository(repo);
      expect((await smart.plan()).skill, isNull);
      final run = await repo.startLesson(repo.catalog.first.id);
      final item = run.lesson.exercises.firstWhere(
        (e) => StudySkill.forExercise(e) == StudySkill.grammar,
      );
      final index = run.lesson.exercises.indexOf(item);
      for (var i = 0; i < index; i++) {
        final exercise = run.lesson.exercises[i];
        await repo.answer(
          run.session.id,
          i,
          exercise,
          exercise.answers.first,
          total: run.lesson.exercises.length,
        );
      }
      for (var i = 0; i < 2; i++) {
        await repo.answer(
          run.session.id,
          index,
          item,
          'wrong',
          total: run.lesson.exercises.length,
        );
      }
      final before = await smart.plan();
      expect(before.skill, StudySkill.grammar);
      expect(before.report.evidence[StudySkill.grammar]!.errors, 1);
      expect(before.items.first.exercise.id, item.id);
      final xp = (await repo.progress()).xp;
      final draft = (await smart.open())!;
      await smart.draft(draft['run'], 0, 'local', []);
      expect((await smart.open())!['text'], 'local');
      await smart.answer(
        draft['run'],
        0,
        before.items.first,
        item.answers.first,
      );
      await smart.answer(draft['run'], 0, before.items.first, 'wrong');
      final after = await smart.plan();
      expect(after.report.evidence[StudySkill.grammar]!.unresolved, 0);
      expect(after.report.evidence[StudySkill.grammar]!.errors, 1);
      expect((await repo.progress()).xp, xp);
      await repo.selectCourse('ru-de');
      expect((await SmartPracticeRepository(repo).plan()).skill, isNull);
    },
  );

  test(
    'all five courses have two scenes and only completed audio supplies evidence',
    () async {
      final repo = await profile();
      final scenes = ListeningScene.parse(
        File('assets/learning/listening.txt').readAsStringSync(),
      );
      final clips = RecordedSpeechCatalog.decode(
        File('assets/audio/voices/manifest.json').readAsStringSync(),
      );
      for (final course in StudyCourse.all) {
        await repo.selectCourse(course.id);
        final cases = scenes
            .where((s) => s.language == course.language)
            .toList();
        expect(cases, hasLength(2));
        for (final line in cases.expand((s) => s.lines)) {
          if (course.language == 'zh') {
            expect(line.line.pronunciation, isNotEmpty);
          } else {
            expect(
              clips.find(line.character, course.locale, line.line.text),
              isNotNull,
            );
          }
        }
        final read = ListeningRepository(repo, cases.first);
        final q = cases.first.questions.first;
        await read.open();
        expect((await read.answer(0, q.correct))['checked'], false);
        await read.source(reading: true);
        await read.answer(0, q.correct);
        await read.advance(0);
        expect((await read.open())['index'], 1);
        final listen = ListeningRepository(repo, cases.last);
        final question = cases.last.questions.first;
        await listen.source(heard: true);
        expect(
          (await listen.answer(
            0,
            question.options.firstWhere((a) => a != question.correct),
          ))['correct'],
          false,
        );
        await listen.advance(0, retry: true);
        expect((await listen.answer(0, question.correct))['correct'], true);
        final progress = await repo.progress();
        expect(progress.xp, 0);
        final report = (await SmartPracticeRepository(repo).plan()).report;
        expect(report.evidence[StudySkill.listening]!.errors, 1);
        expect(report.evidence[StudySkill.listening]!.correct, 0);
      }
    },
  );
}
