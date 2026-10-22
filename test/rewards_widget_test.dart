import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/character_reactions.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'earned chest opens once without animation, inventory equips and all new screens fit',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository(), boundary = GlobalKey();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        await app.finishOnboarding();
        await r.append(
          r.event('complete', {'lesson': 'a1-01', 'session': 'first'}),
        );
        await app.refresh();
        for (final family in ['OrbitSans', 'Roboto', 'Ahem']) {
          final loader = FontLoader(family)
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
                ),
              ),
            );
          await loader.load();
        }
        final icons = FontLoader('MaterialIcons')
          ..addFont(
            Future.value(
              ByteData.sublistView(
                await File(
                  '.tools/flutter/bin/cache/artifacts/material_fonts/materialicons-regular.otf',
                ).readAsBytes(),
              ),
            ),
          );
        await icons.load();
      });
      final chestId = app.inventory.grants.keys.first;
      Finder chestButton(String text) => find.descendant(
        of: find.byKey(ValueKey(chestId)),
        matching: find.text(text),
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((ref) => app)],
          child: RepaintBoundary(key: boundary, child: const OrbitApp()),
        ),
      );
      await flushDb(tester);
      final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(OrbitShell));
        for (final file in Directory(
          'assets/kvesmos',
        ).listSync().whereType<File>().where((f) => f.path.endsWith('.png'))) {
          await precacheImage(
            AssetImage(file.path.replaceAll('\\', '/')),
            context,
          );
        }
      });
      await tester.pumpAndSettle();

      Future<void> capture(String name) async {
        if (Platform.environment['CAPTURE_UI'] != '1') return;
        await tester.runAsync(() async {
          final render =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await render.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            'test-output/$name.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }

      router.go('/rewards');
      await flushDb(tester);
      await capture('kvesmos-chests');
      await tester.scrollUntilVisible(chestButton('Открыть сундук'), 180);
      await tester.pumpAndSettle();
      await tester.tap(chestButton('Открыть сундук'));
      await tester.pumpAndSettle();
      expect(find.byType(OpenChestDialog), findsOneWidget);
      await tester.tap(find.text('Без анимации'));
      await flushDb(tester);
      expect(find.text('Уже сохранено в вашей коллекции'), findsOneWidget);
      expect(app.inventory.owned, hasLength(1));
      final itemId = app.inventory.owned.single;
      final rarity = app.rewards.catalog.item(itemId).rarity;
      expect(
        find.text(
          CharacterCue.pixieReward(
            rarityNames[rarity]!,
            fresh: true,
          ).lines.first,
        ),
        findsOneWidget,
      );
      expect(find.text(CharacterCue.reward.lines.first), findsOneWidget);
      await capture('kvesmos-reward');
      await tester.ensureVisible(find.text('Забрать'));
      await tester.tap(find.text('Забрать'));
      await tester.pumpAndSettle();
      router.go('/inventory');
      await flushDb(tester);
      final item = app.rewards.catalog.item(itemId);
      await tester.scrollUntilVisible(find.text(item.name), 250);
      await tester.pumpAndSettle();
      await tester.tap(find.text(item.name));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('apply-cosmetic')),
        200,
        scrollable: find.descendant(
          of: find.byType(CosmeticPreviewDialog),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('apply-cosmetic')));
      await flushDb(tester);
      expect(app.inventory.equipped[item.slot], itemId);
      router.go('/profile');
      await flushDb(tester);
      await capture('kvesmos-profile');
      router.go('/crew');
      await flushDb(tester);
      await capture('kvesmos-crew');
      router.go('/quests');
      await flushDb(tester);
      await capture('kvesmos-missions');
      router.go('/stats');
      await flushDb(tester);
      await capture('kvesmos-stats');
      router.go('/inventory');
      await flushDb(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -520));
      await tester.pumpAndSettle();
      await capture('kvesmos-inventory');
      router.go('/');
      await flushDb(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -680));
      await tester.pumpAndSettle();
      await capture('kvesmos-map');
      router.go('/lesson/a1-02');
      await flushDb(tester);
      await capture('kvesmos-lesson');
      expect(tester.takeException(), isNull);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      for (final theme in [ThemeMode.light, ThemeMode.dark]) {
        await tester.runAsync(() => app.savePreferences(newTheme: theme));
        for (final path in [
          '/rewards',
          '/inventory',
          '/crew',
          '/profile',
          '/stats',
        ]) {
          router.go(path);
          await flushDb(tester);
          expect(
            tester.takeException(),
            isNull,
            reason: '$theme $path at 200%',
          );
        }
      }
      router.go('/rewards');
      await flushDb(tester);
      await tester.scrollUntilVisible(chestButton('Посмотреть награду'), 200);
      await tester.pumpAndSettle();
      await tester.tap(chestButton('Посмотреть награду'));
      await tester.pumpAndSettle();
      expect(find.text(item.name), findsOneWidget);
      expect(app.inventory.owned.single, itemId);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
