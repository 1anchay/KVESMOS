import 'dart:io';
import 'dart:math';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  test(
    'schema-1 file reopens with XP, old draft, owned reward and equipment intact',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'kvesmos-upgrade-',
      );
      final file = File('${directory.path}/orbitwords.sqlite');
      LearningRepository open() => LearningRepository(
        AppDatabase(NativeDatabase(file)),
        loadAsset: (path) => File(path).readAsString(),
      );
      final repo = open();
      await repo.initialize();
      await repo.setSetting('onboarded', 'true');
      final first = await repo.lesson('a1-01');
      final completed = await repo.start(first.id);
      for (var i = 0; i < first.exercises.length; i++) {
        await repo.answer(
          completed.id,
          i,
          first.exercises[i],
          first.exercises[i].answers.first,
          total: first.exercises.length,
        );
      }
      final second = await repo.lesson('a1-02');
      final active = await repo.start(second.id);
      await repo.answer(
        active.id,
        0,
        second.exercises.first,
        'wrong',
        total: 10,
      );
      await repo.answer(
        active.id,
        0,
        second.exercises.first,
        second.exercises.first.answers.first,
        total: 10,
      );
      await repo.draft(active.id, 1, '{"text":"unfinished answer"}');
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final rewards = RewardsRepository(repo, catalog, random: Random(7));
      final inventory = await rewards.reconcile();
      final item = await rewards.open(inventory.grants.keys.first);
      await rewards.equip(item!.slot, item.id);
      final events = (await repo.allEvents()).map((e) => e.id).toSet();
      await repo.db.close();
      if (Platform.environment['UPGRADE_FIXTURE'] == '1') {
        await Directory('.tools/qa-upgrade').create(recursive: true);
        await file.copy(
          '.tools/qa-upgrade/synthetic-${DateTime.now().millisecondsSinceEpoch}.sqlite',
        );
      }
      final reopened = open();
      await reopened.initialize();
      final resumed = await reopened.startLesson('a1-02');
      expect(resumed.session.id, active.id);
      expect(resumed.session.draft, '{"text":"unfinished answer"}');
      expect(resumed.lesson.exercises.first.id, second.exercises.first.id);
      expect(resumed.session.position, 1);
      expect((await reopened.progress()).xp, 130);
      expect((await reopened.progress()).errors, 1);
      expect((await reopened.allEvents()).map((e) => e.id).toSet(), events);
      final restored = await RewardsRepository(reopened, catalog).read();
      expect(restored.owned, contains(item.id));
      expect(restored.equipped[item.slot], item.id);
      expect(await reopened.setting('onboarded'), 'true');
      await reopened.db.close();
      // Remove only the private temporary directory created by this test.
      final tempRoot = Directory.systemTemp.absolute.path;
      expect(
        directory.absolute.path.startsWith(
          '$tempRoot${Platform.pathSeparator}kvesmos-upgrade-',
        ),
        true,
      );
      await directory.delete(recursive: true);
    },
  );
}
