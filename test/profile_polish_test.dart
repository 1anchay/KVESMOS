import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/data/rewards_repository.dart';
import 'package:orbitwords/domain/rewards.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'package:orbitwords/ui/profile_achievements.dart';
import 'package:orbitwords/ui/design.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'cosmetic preview is temporary; cancel preserves equipment and double apply is safe',
    (tester) async {
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        final item = app.rewards.catalog.items.firstWhere(
          (i) => i.slot == 'frame',
        );
        final state = Inventory(
          grants: {'test': ChestGrant('test', 'explorer', item.id)},
        );
        await r.setSetting(RewardsRepository.storageKey, state.encode());
        await app.refresh();
      });
      final item = app.rewards.catalog.items.firstWhere(
        (i) => i.slot == 'frame',
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: orbitTheme(Brightness.light),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => CosmeticPreviewDialog(item: item),
                  ),
                  child: const Text('Примерить'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Примерить'));
      await tester.pumpAndSettle();
      final preview = tester.widget<ProfileLook>(find.byType(ProfileLook));
      expect(preview.preview!.id, item.id);
      expect(app.inventory.equipped, isEmpty);
      await tester.scrollUntilVisible(find.text('Отмена'), 200);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Отмена'));
      await tester.pumpAndSettle();
      expect(app.inventory.equipped, isEmpty);
      await tester.tap(find.text('Примерить'));
      await tester.pumpAndSettle();
      final apply = find.byKey(const ValueKey('apply-cosmetic'));
      await tester.scrollUntilVisible(apply, 200);
      await tester.pumpAndSettle();
      await tester.tap(apply);
      await tester.tap(apply);
      await flushDb(tester);
      expect(find.text('Примерить'), findsOneWidget);
      expect(app.inventory.equipped['frame'], item.id);
      expect(app.inventory.owned, hasLength(1));
      expect(app.progress.xp, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
  testWidgets(
    'showcase validates unlocked achievements and survives reopening the old database',
    (tester) async {
      final folder = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('kvesmos-profile-'),
      ))!;
      LearningRepository connect() => LearningRepository(
        AppDatabase(NativeDatabase(File('${folder.path}/orbitwords.sqlite'))),
        loadAsset: (p) => File(p).readAsString(),
      );
      var r = connect();
      var app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        for (var i = 1; i <= 20; i++) {
          await r.append(
            r.event('complete', {
              'session': 's$i',
              'lesson': 'a1-${i.toString().padLeft(2, '0')}',
            }),
          );
        }
        await app.refresh();
        await expectLater(app.saveShowcase(['Locked']), throwsStateError);
        await expectLater(
          app.saveShowcase(app.progress.achievements.take(4).toList()),
          throwsStateError,
        );
        await app.saveShowcase(app.progress.achievements.take(3).toList());
      });
      final selected = List<String>.from(app.featuredAchievements);
      final xp = app.progress.xp;
      final grants = app.inventory.grants.keys.toSet();
      await tester.runAsync(() async {
        app.dispose();
        await r.db.close();
      });
      r = connect();
      app = AppController(r);
      await tester.runAsync(app.initialize);
      expect(app.featuredAchievements, selected);
      expect(app.progress.xp, xp);
      expect(app.inventory.grants.keys.toSet(), grants);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(home: const Scaffold(body: AchievementShowcase())),
        ),
      );
      await tester.pumpAndSettle();
      for (final name in selected) {
        expect(find.text(name), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('edit-showcase')));
      await tester.pumpAndSettle();
      expect(find.text('Выбрано 3 из 3'), findsOneWidget);
      await tester.tap(find.text(selected.first).last);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('save-showcase')));
      await flushDb(tester);
      expect(app.featuredAchievements, hasLength(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
      await tester.runAsync(() => folder.delete(recursive: true));
    },
  );
  testWidgets(
    'profile and every cosmetic preview fit narrow screens with 200% text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(app.initialize);
      for (final brightness in Brightness.values) {
        for (final slot in [
          'avatar',
          'frame',
          'background',
          'accessory',
          'emote',
        ]) {
          final item = app.rewards.catalog.items.firstWhere(
            (i) => i.slot == slot,
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appProvider.overrideWith((_) => app)],
              child: MaterialApp(
                theme: orbitTheme(brightness),
                home: MediaQuery(
                  data: const MediaQueryData(
                    disableAnimations: true,
                    textScaler: TextScaler.linear(2),
                  ),
                  child: Scaffold(body: CosmeticPreviewDialog(item: item)),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('apply-cosmetic')),
            findsNothing,
          ); // unowned previews cannot be equipped
          expect(app.inventory.equipped, isEmpty);
          expect(tester.takeException(), isNull, reason: '$brightness $slot');
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
