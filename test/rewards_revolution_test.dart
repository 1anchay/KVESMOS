import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/ui/collection_components.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'package:orbitwords/ui/explorer_profile.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'activity range controls wrap at 200% with wide fallback glyphs',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = memoryRepository();
      final app = AppController(repo);
      await tester.runAsync(app.initialize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: ThemeData(fontFamily: 'Ahem'),
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 760),
                textScaler: TextScaler.linear(2),
              ),
              child: const Scaffold(
                body: SingleChildScrollView(child: ExplorerActivity()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('30 дней'));
      await tester.pumpAndSettle();
      expect(find.text('За этот период занятий пока нет.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.db.close);
    },
  );
  testWidgets(
    'closing while transaction is blocked still commits one durable find; reopen is quiet',
    (tester) async {
      final repo = memoryRepository();
      final app = AppController(repo);
      await tester.runAsync(() async {
        await app.initialize();
        await repo.append(
          repo.event('complete', {'session': 'one', 'lesson': 'a1-01'}),
        );
        await app.refresh();
      });
      final grant = app.inventory.grants.values.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => OpenChestDialog(grant: grant),
                  ),
                  child: const Text('Show'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      late Completer<void> entered, release;
      late Future<void> lock;
      await tester.runAsync(() async {
        entered = Completer<void>();
        release = Completer<void>();
        lock = repo.db.transaction(() async {
          entered.complete();
          await release.future;
        });
        await entered.future;
      });
      await tester.tap(find.text('Открыть'));
      await tester.pump();
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        release.complete();
        await lock;
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      await flushDb(tester);
      expect(app.inventory.owned, hasLength(1));
      final saved = app.inventory.owned.single;
      await tester.tap(find.text('Show'));
      await tester.pumpAndSettle();
      expect(find.text('Твоя сохранённая находка'), findsOneWidget);
      expect(app.inventory.owned.single, saved);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.db.close);
    },
  );
  testWidgets(
    'failed storage reveals no item; retry and parallel open publish only one fresh result',
    (tester) async {
      final repo = memoryRepository();
      final app = AppController(repo);
      await tester.runAsync(() async {
        await app.initialize();
        await repo.append(
          repo.event('complete', {'session': 's', 'lesson': 'a1-01'}),
        );
        await app.refresh();
        await repo.db.customStatement(
          "CREATE TRIGGER fail_inventory BEFORE UPDATE ON settings WHEN NEW.key = 'kvesmos.inventory.v1' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
        );
      });
      final grant = app.inventory.grants.values.first;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(home: OpenChestDialog(grant: grant)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Без анимации'));
      await flushDb(tester);
      expect(app.inventory.owned, isEmpty);
      expect(find.textContaining('Не удалось обновить'), findsOneWidget);
      expect(find.text('Уже сохранено в вашей коллекции'), findsNothing);
      await tester.runAsync(() async {
        await repo.db.customStatement('DROP TRIGGER fail_inventory');
        final results = await Future.wait([
          app.rewards.openOnce(grant.id),
          app.rewards.openOnce(grant.id),
        ]);
        expect(results.where((r) => r.fresh), hasLength(1));
        expect(results[0].item!.id, results[1].item!.id);
      });
      await tester.tap(find.text('Открыть'));
      await flushDb(tester);
      expect(find.text('Твоя сохранённая находка'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(repo.db.close);
    },
  );
  testWidgets(
    'all collected is finite; missing artwork retains accessible fallback',
    (tester) async {
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        await r.setSetting(
          RewardsRepository.storageKey,
          Inventory(
            grants: {
              for (final item in app.rewards.catalog.items)
                item.id: ChestGrant(item.id, 'explorer', item.id),
              'pending': const ChestGrant('pending', 'supernova'),
            },
          ).encode(),
        );
        await app.refresh();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            home: OpenChestDialog(grant: app.inventory.grants['pending']!),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Без анимации'));
      await flushDb(tester);
      expect(find.text('Коллекция этого сундука собрана!'), findsOneWidget);
      expect(app.inventory.unopened, 1);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: CollectionArt('assets/missing.png', label: 'Предмет'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.auto_awesome_outlined), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  test(
    'reset appearance is atomic and preserves ownership and original grant JSON',
    () async {
      final r = memoryRepository(), app = AppController(r);
      addTearDown(() async {
        app.dispose();
        await r.db.close();
      });
      await app.initialize();
      final item = app.rewards.catalog.items.first;
      final state = Inventory(
        grants: {'legacy': ChestGrant('legacy', 'explorer', item.id)},
        equipped: {item.slot: item.id},
      );
      await r.setSetting(RewardsRepository.storageKey, state.encode());
      await app.refresh();
      await r.db.customStatement(
        "CREATE TRIGGER fail_reset BEFORE UPDATE ON settings WHEN NEW.key = 'kvesmos.inventory.v1' BEGIN SELECT RAISE(ABORT, 'disk full'); END",
      );
      await expectLater(app.resetAppearance(), throwsA(anything));
      expect(app.inventory.equipped[item.slot], item.id);
      await r.db.customStatement('DROP TRIGGER fail_reset');
      await app.resetAppearance();
      expect(app.inventory.equipped, isEmpty);
      expect(
        app.inventory.grants['legacy']!.toJson(),
        state.grants['legacy']!.toJson(),
      );
      expect(app.inventory.owned, {item.id});
      expect(app.progress.xp, 0);
    },
  );
}
