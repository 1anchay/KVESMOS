import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

class _Roll implements Random {
  final double value;
  _Roll(this.value);
  @override
  double nextDouble() => value;
  @override
  int nextInt(int max) => 0;
  @override
  bool nextBool() => true;
}

void main() {
  setUpAll(setupSqlite);
  testWidgets(
    'all rarity ceremonies name the saved item and expose semantics',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      await tester.runAsync(() async {
        await loadPreviewFonts();
        await Directory('test-output/v08').create(recursive: true);
      });
      for (final entry in [
        ('common', 'explorer', .1),
        ('epic', 'supernova', .6),
        ('legendary', 'supernova', .95),
      ]) {
        final r = memoryRepository();
        final app = AppController(r, rewardRandom: _Roll(entry.$3));
        final key = GlobalKey();
        await tester.runAsync(() async {
          await app.initialize();
          await app.saveAudio(
            const AudioPreferences(
              speech: false,
              effects: false,
              reactions: false,
            ),
          );
          for (final lesson in r.catalog) {
            await r.append(
              r.event('complete', {'session': lesson.id, 'lesson': lesson.id}),
            );
          }
          await app.refresh();
        });
        final grant = app.inventory.grants.values.firstWhere(
          (g) => g.kind == entry.$2,
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              home: RepaintBoundary(
                key: key,
                child: OpenChestDialog(grant: grant),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Открыть'));
        await flushDb(tester);
        final item = app.rewards.catalog.item(app.inventory.owned.single);
        expect(item.rarity, entry.$1);
        expect(find.bySemanticsLabel(item.name), findsWidgets);
        expect(find.text(rarityNames[entry.$1]!), findsOneWidget);
        await tester.runAsync(() async {
          for (final image in tester.widgetList<Image>(find.byType(Image))) {
            await precacheImage(image.image, key.currentContext!);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(
          () => capturePreview(key, 'v08/reveal-${entry.$1}'),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      }
      semantics.dispose();
    },
  );
}
