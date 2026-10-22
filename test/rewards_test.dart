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
  late RewardCatalog catalog;
  setUp(() {
    catalog = RewardCatalog(
      File('assets/kvesmos/catalog.json').readAsStringSync(),
    );
  });
  Future<void> complete(LearningRepository r, int count) async {
    for (var i = 1; i <= count; i++) {
      await r.append(
        r.event('complete', {
          'lesson': 'a1-${i.toString().padLeft(2, '0')}',
          'session': 'session-$i',
        }),
      );
    }
  }

  test(
    'catalog has all approved characters, 20 distinct cosmetics, real bundled assets',
    () {
      expect(catalog.items.map((e) => e.id).toSet(), hasLength(20));
      expect(catalog.characters, hasLength(9));
      for (final item in catalog.items) {
        expect(File(item.asset).existsSync(), isTrue, reason: item.id);
      }
      for (final c in catalog.characters) {
        expect(File(c['asset_path']).existsSync(), isTrue, reason: c['id']);
      }
      for (final slot in [
        'avatar',
        'frame',
        'background',
        'accessory',
        'emote',
      ]) {
        expect(catalog.items.where((e) => e.slot == slot), hasLength(4));
      }
    },
  );
  test(
    'duplicate completions and concurrent reconciliation grant each milestone once',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await complete(r, 20);
      await complete(r, 20);
      final rewards = RewardsRepository(r, catalog);
      await Future.wait([rewards.reconcile(), rewards.reconcile()]);
      final state = await rewards.read();
      expect(state.grants, hasLength(10));
      expect(
        state.grants.values.where((g) => g.kind == 'explorer'),
        hasLength(7),
      );
      expect(
        state.grants.values.where((g) => g.kind == 'nebula'),
        hasLength(2),
      );
      expect(
        state.grants.values.where((g) => g.kind == 'supernova'),
        hasLength(1),
      );
    },
  );
  test(
    'double opening commits one item; replay never consumes another draw',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      await complete(r, 1);
      final rewards = RewardsRepository(r, catalog, random: Random(7));
      final state = await rewards.reconcile();
      final id = state.grants.keys.single;
      final drops = await Future.wait([rewards.open(id), rewards.open(id)]);
      expect(drops[0]!.id, drops[1]!.id);
      expect((await rewards.read()).owned, hasLength(1));
      await expectLater(rewards.open('unearned'), throwsStateError);
    },
  );
  test(
    'exhausted categories are removed and probabilities renormalized; no duplicates',
    () {
      final owned = catalog.items
          .where((e) => e.rarity == 'common')
          .map((e) => e.id)
          .toSet();
      final odds = catalog.odds('explorer', owned);
      expect(odds.keys, ['rare', 'epic']);
      expect(odds['rare'], closeTo(25 / 30, 1e-12));
      expect(odds['epic'], closeTo(5 / 30, 1e-12));
      for (var i = 0; i < 10; i++) {
        final item = catalog.draw('explorer', owned, Random(i))!;
        expect(owned.contains(item.id), isFalse);
        owned.add(item.id);
      }
      expect(catalog.draw('explorer', owned, Random(1)), isNull);
      expect(owned, hasLength(15));
      final all = catalog.items.map((e) => e.id).toSet();
      for (final type in catalog.chests) {
        expect(catalog.odds(type['id'], all), isEmpty);
      }
    },
  );
  test(
    'exhausted chest is kept unopened, and equipment rejects unowned or wrong slots',
    () async {
      final r = memoryRepository();
      addTearDown(r.db.close);
      await r.initialize();
      final state = Inventory(
        grants: {
          for (final item in catalog.items)
            item.id: ChestGrant(item.id, 'explorer', item.id),
          'pending': const ChestGrant('pending', 'supernova'),
        },
      );
      await r.setSetting(RewardsRepository.storageKey, state.encode());
      final rewards = RewardsRepository(r, catalog);
      expect(await rewards.open('pending'), isNull);
      expect((await rewards.read()).unopened, 1);
      final avatar = catalog.items.firstWhere((i) => i.slot == 'avatar');
      await expectLater(rewards.equip('frame', avatar.id), throwsStateError);
      await rewards.equip('avatar', avatar.id);
      expect((await rewards.read()).equipped['avatar'], avatar.id);
      await rewards.equip('avatar', null);
      expect((await rewards.read()).equipped, isEmpty);
      await r.setSetting(RewardsRepository.storageKey, Inventory().encode());
      await expectLater(rewards.equip('avatar', avatar.id), throwsStateError);
    },
  );
  test(
    'old schema v1 reopens preserving XP, draft, preferences and packs; drop survives restart',
    () async {
      final folder = await Directory.systemTemp.createTemp('kvesmos-upgrade-');
      final file = File('${folder.path}/orbitwords.sqlite');
      LearningRepository connect() => LearningRepository(
        AppDatabase(NativeDatabase(file)),
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
      await r.draft(session.id, 1, 'old saved draft');
      await r.setSetting('name', 'Аня');
      await r.setSetting('owner', 'existing-account');
      await complete(r, 1);
      final xp = (await r.progress()).xp;
      final events = (await r.allEvents()).map((e) => e.toJson()).toList();
      await r.db.close();
      r = connect();
      await r.initialize();
      var rewards = RewardsRepository(r, catalog);
      final grant = (await rewards.reconcile()).grants.keys.single;
      final item = (await rewards.open(grant))!;
      await rewards.equip(item.slot, item.id);
      await r.db.close();
      r = connect();
      await r.initialize();
      rewards = RewardsRepository(r, catalog);
      expect((await rewards.open(grant))!.id, item.id);
      expect((await rewards.read()).equipped[item.slot], item.id);
      expect((await r.progress()).xp, xp);
      expect((await r.allEvents()).map((e) => e.toJson()).toList(), events);
      expect((await r.session(session.id)).draft, 'old saved draft');
      expect((await r.session(session.id)).position, 1);
      expect(await r.setting('name'), 'Аня');
      expect(await r.setting('owner'), 'existing-account');
      expect(await r.installed(), hasLength(20));
      expect(
        (await r.db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        1,
      );
      await r.db.close();
      await folder.delete(recursive: true);
    },
  );
}
