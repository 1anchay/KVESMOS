import 'dart:io';
import 'rewards_fixture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  for (final small in [false, true]) {
    testWidgets(
      'collection journey, both themes ${small ? '320px 200%' : '390px'}',
      (tester) async {
        tester.view.physicalSize = Size(small ? 320 : 390, small ? 760 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await loadPreviewFonts();
          await Directory('test-output/v08').create(recursive: true);
        });
        for (final theme in [ThemeMode.light, ThemeMode.dark]) {
          final r = memoryRepository(now: () => DateTime(2026, 10, 27, 12));
          final app = AppController(r, rewardRandom: RareFrameRandom());
          final boundary = GlobalKey();
          await tester.runAsync(() async {
            await app.initialize();
            await app.finishOnboarding();
            await app.savePreferences(newTheme: theme, newName: 'Аня');
            await app.saveAudio(
              const AudioPreferences(
                speech: false,
                effects: false,
                reactions: false,
              ),
            );
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appProvider.overrideWith((_) => app)],
              child: MediaQuery(
                data: MediaQueryData(
                  size: tester.view.physicalSize,
                  textScaler: TextScaler.linear(small ? 2 : 1),
                  disableAnimations: true,
                ),
                child: RepaintBoundary(key: boundary, child: const OrbitApp()),
              ),
            ),
          );
          // MaterialApp establishes its own MediaQuery; use platform scale as a real device does.
          tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          await flushDb(tester);
          final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
          Future<void> capture(String name) async {
            await tester.runAsync(() async {
              for (final image in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(image.image, boundary.currentContext!);
              }
            });
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$name ${theme.name} small=$small',
            );
            await tester.runAsync(
              () => capturePreview(
                boundary,
                'v08/$name-${theme.name}${small ? '-320-200' : ''}',
              ),
            );
          }

          for (final page in [
            'profile',
            'rewards',
            'inventory',
            'achievements',
          ]) {
            router.go('/$page');
            await flushDb(tester);
            await capture('empty-$page');
          }
          await tester.runAsync(() async {
            for (var n = 1; n <= 11; n++) {
              final material = await r.startLesson(
                'a1-${n.toString().padLeft(2, '0')}',
              );
              for (var i = 0; i < 10; i++) {
                final e = material.lesson.exercises[i];
                await r.answer(
                  material.session.id,
                  i,
                  e,
                  e.answers.first,
                  total: 10,
                );
              }
            }
            await app.refresh();
            await app.saveShowcase(app.progress.achievements.take(3).toList());
          });
          router.go('/profile');
          await flushDb(tester);
          await capture('profile');
          router.go('/rewards');
          await flushDb(tester);
          await capture('rewards');
          final grant = app.inventory.grants.values.first;
          router.push('/chest/${Uri.encodeComponent(grant.id)}');
          await flushDb(tester);
          await capture('chest-ready');
          await tester.ensureVisible(find.text('Без анимации'));
          await tester.tap(find.text('Без анимации'));
          await flushDb(tester);
          expect(app.inventory.owned, hasLength(1));
          final item = app.rewards.catalog.item(app.inventory.owned.single);
          expect(item.rarity, 'rare');
          expect(item.slot, 'frame');
          await capture('rare-reveal');
          await tester.ensureVisible(find.text('Примерить находку'));
          await tester.tap(find.text('Примерить находку'));
          await flushDb(tester);
          await capture('try-on');
          expect(
            Theme.of(
              tester.element(find.byType(CosmeticPreviewDialog)),
            ).colorScheme.brightness,
            Brightness.dark,
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('apply-cosmetic')),
          );
          await tester.tap(find.byKey(const ValueKey('apply-cosmetic')));
          await flushDb(tester);
          expect(app.inventory.equipped['frame'], item.id);
          router.go('/profile');
          await flushDb(tester);
          await capture('profile-equipped');
          await tester.drag(find.byType(ListView).first, const Offset(0, -640));
          await flushDb(tester);
          await capture('records');
          router.go('/inventory');
          await flushDb(tester);
          await capture('wardrobe');
          await tester.drag(find.byType(ListView).first, const Offset(0, -410));
          await flushDb(tester);
          await capture('wardrobe-items');
          router.go('/achievements');
          await flushDb(tester);
          await capture('achievements');
          router.go('/map');
          await flushDb(tester);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(r.db.close);
        }
      },
    );
  }
}
