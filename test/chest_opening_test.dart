import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  for (final kind in ['explorer', 'nebula', 'supernova']) {
    testWidgets(
      '$kind commits before animation; skip and reopen keep the same item',
      (tester) async {
        final r = memoryRepository();
        final app = AppController(r);
        await tester.runAsync(() async {
          await app.initialize();
          for (var i = 1; i <= 20; i++) {
            await r.append(
              r.event('complete', {
                'lesson': 'lesson-$i',
                'session': 'session-$i',
              }),
            );
          }
          await app.refresh();
        });
        final grant = app.inventory.grants.values.firstWhere(
          (g) => g.kind == kind,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              home: Builder(
                builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => OpenChestDialog(
                        grant: app.inventory.grants[grant.id]!,
                      ),
                    ),
                    child: const Text('Показать сундук'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Показать сундук'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Открыть'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await tester.pump();
        expect(app.inventory.owned, hasLength(1));
        final id = app.inventory.owned.single;
        expect(find.text('Пикси распаковывает вашу находку…'), findsOneWidget);
        // The transaction completed, but the visual opening is still in progress.
        expect(find.text('Уже сохранено в вашей коллекции'), findsNothing);
        await tester.pump(const Duration(milliseconds: 350));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName.endsWith(
                  '${kind}_closed.png',
                ),
          ),
          findsOneWidget,
        );
        await tester.pump(const Duration(milliseconds: 500));
        expect(
          find.byWidgetPredicate(
            (w) =>
                w is Image &&
                w.image is AssetImage &&
                (w.image as AssetImage).assetName.endsWith('${kind}_open.png'),
          ),
          findsOneWidget,
        );
        if (kind == 'explorer') {
          // Closing midway must not lose or re-roll the already committed item.
          await tester.tap(find.byTooltip('Закрыть'));
          await tester.pumpAndSettle();
        } else {
          if (kind == 'supernova') {
            await tester.pump(const Duration(milliseconds: 600));
          } else {
            await tester.tap(find.text('Пропустить анимацию'));
          }
          await tester.pumpAndSettle();
          expect(find.text('Уже сохранено в вашей коллекции'), findsOneWidget);
          await tester.ensureVisible(find.text('Забрать'));
          await tester.tap(find.text('Забрать'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Показать сундук'));
        await tester.pumpAndSettle();
        expect(find.text(app.rewards.catalog.item(id).name), findsOneWidget);
        expect(find.text('Пикси распаковывает вашу находку…'), findsNothing);
        expect(app.inventory.owned.single, id);
        expect(find.textContaining('сохранённая находка'), findsOneWidget);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      },
    );
  }
  testWidgets(
    'reduced motion presents a saved reward immediately at 200% text',
    (tester) async {
      tester.view.physicalSize = const Size(360, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final r = memoryRepository();
      final app = AppController(r);
      await tester.runAsync(() async {
        await app.initialize();
        await r.append(
          r.event('complete', {'lesson': 'a1-01', 'session': 'first'}),
        );
        await app.refresh();
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                disableAnimations: true,
                textScaler: const TextScaler.linear(2),
              ),
              child: child!,
            ),
            home: Scaffold(
              body: OpenChestDialog(grant: app.inventory.grants.values.first),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Открыть'));
      await tester.tap(find.text('Открыть'));
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
      expect(app.inventory.owned, hasLength(1));
      expect(find.text('Пикси распаковывает вашу находку…'), findsNothing);
      expect(find.text('Уже сохранено в вашей коллекции'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
