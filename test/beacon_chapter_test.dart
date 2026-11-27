import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/data/beacon_repository.dart';
import 'package:orbitwords/data/progress_transfer.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'support.dart';
import 'smart_learning_test.dart' show finish;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(setupSqlite);
  test(
    'beacon requires its bound attempt and survives duplicate restore',
    () async {
      final repo = memoryRepository();
      final other = memoryRepository();
      addTearDown(repo.db.close);
      addTearDown(other.db.close);
      await repo.initialize();
      await other.initialize();
      final id = repo.catalog.first.id;
      await finish(repo, id);
      final initialXp = (await repo.progress()).xp;
      final beacon = BeaconRepository(repo);
      await repo.setSetting('beacon_chapter_v1_en', '3|$id');
      expect((await beacon.read(id)).stage, 3);
      final session = await repo.startLesson(id);
      await beacon.bind(id, session.session.id);
      expect((await beacon.read(id)).stage, 3);
      final catalog = RewardCatalog(
        File('assets/kvesmos/catalog.json').readAsStringSync(),
      );
      final transfer = ProgressTransfer(repo, catalog);
      final restore = ProgressTransfer(other, catalog);
      final sourceRewards = RewardsRepository(repo, catalog);
      await sourceRewards.reconcile();
      final draft = await restore.validate(await transfer.export());
      final restored = BeaconRepository(other);
      await other.setSetting(restored.key, BeaconState(3, id).encode());
      await restore.restore(draft);
      expect((await restored.read(id)).session, session.session.id);
      final targetRewards = RewardsRepository(other, catalog);
      final transferredInventory = (await targetRewards.read()).encode();
      await finish(other, id);
      expect((await restored.read(id)).stage, 4);
      await restored.advance(await restored.read(id));
      await restore.restore(draft);
      await restore.restore(draft);
      expect((await restored.read(id)).stage, 5);
      expect((await other.progress()).xp, initialXp);
      expect((await targetRewards.reconcile()).encode(), transferredInventory);
    },
  );
}
