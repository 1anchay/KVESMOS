import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/adventures_repository.dart';
import 'package:orbitwords/domain/space_adventures.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  for (final small in [false, true]) {
    for (final theme in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets(
        'play all adventures ${theme.name} ${small ? "320 200%" : "390"}',
        (tester) async {
          tester.view.physicalSize = Size(small ? 320 : 390, small ? 760 : 844);
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = small ? 2 : 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final r = memoryRepository(),
              app = AppController(r),
              boundary = GlobalKey();
          await tester.runAsync(() async {
            await loadPreviewFonts();
            await Directory('test-output/v09').create(recursive: true);
            await app.initialize();
            await app.finishOnboarding();
            await app.savePreferences(newTheme: theme);
            await app.saveAudio(
              AudioPreferences(
                speech: false,
                effects: false,
                reactions: !small,
              ),
            );
            for (var n = 1; n <= 5; n++) {
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
          });
          await tester.pumpWidget(
            ProviderScope(
              overrides: [appProvider.overrideWith((_) => app)],
              child: RepaintBoundary(key: boundary, child: const OrbitApp()),
            ),
          );
          await flushDb(tester);
          final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
          final game = AdventuresRepository(r);
          var frame = 0;
          final video =
              Platform.environment['SPACE_VIDEO'] == '1' &&
              !small &&
              theme == ThemeMode.light;
          Future<void> film() async {
            if (!video) return;
            for (var i = 0; i < 5; i++) {
              await tester.pump(const Duration(milliseconds: 200));
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()!
                            as RenderRepaintBoundary)
                        .toImage(pixelRatio: 1);
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                await File(
                  'test-output/v09/frames/${(frame++).toString().padLeft(5, '0')}.png',
                ).writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
          }

          if (video) {
            await tester.runAsync(
              () => Directory('test-output/v09/frames').create(recursive: true),
            );
          }
          Future<void> tap(Key key) async {
            final f = find.byKey(key);
            tester
                .state<ScrollableState>(find.byType(Scrollable).first)
                .position
                .jumpTo(0);
            await tester.pumpAndSettle();
            await tester.scrollUntilVisible(
              f,
              180,
              maxScrolls: 30,
              scrollable: find.byType(Scrollable).first,
            );
            await tester.ensureVisible(f);
            await tester.pumpAndSettle();
            await tester.tap(f);
            if (video) {
              await tester.runAsync(
                () => Future<void>.delayed(const Duration(milliseconds: 120)),
              );
              await film();
              await tester.pumpAndSettle();
            } else {
              await flushDb(tester);
            }
          }

          Future<void> capture(String name) async {
            await tester.runAsync(() async {
              for (final image in tester.widgetList<Image>(
                find.byType(Image),
              )) {
                await precacheImage(image.image, boundary.currentContext!);
              }
            });
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull, reason: name);
            await tester.runAsync(
              () => capturePreview(
                boundary,
                'v09/$name-${theme.name}${small ? '-320-200' : ''}',
              ),
            );
          }

          router.go('/map');
          await flushDb(tester);
          await tap(const Key('map-world-0'));
          await tester.ensureVisible(find.byKey(const Key('adventure-beacon')));
          await capture('map');
          for (final adventure in SpaceAdventure.all) {
            router.go('/adventure/${adventure.id}');
            await flushDb(tester);
            await capture(adventure.id);
            final before = app.progress.xp;
            for (final step in adventure.steps) {
              await tap(ValueKey('object-${step.target}'));
              expect(
                (await tester.runAsync(() => game.read(adventure.id)))!.focus,
                step.target,
                reason: step.id,
              );
              if (step.id == 'guide') {
                await tap(const Key('adventure-voice'));
                expect(find.textContaining('Читай фразу выше'), findsOneWidget);
                await tap(const Key('adventure-hint'));
              }
              if (step.id == 'hello') {
                await tap(const ValueKey('answer-Goodbye!'));
                await capture('error');
                // Route disposal/reentry uses only persisted state, including last line.
                final saved = await tester.runAsync(
                  () => game.read(adventure.id),
                );
                router.go('/map');
                await flushDb(tester);
                router.go('/adventure/${adventure.id}');
                await flushDb(tester);
                expect(
                  (await tester.runAsync(
                    () => game.read(adventure.id),
                  ))!.encode(),
                  saved!.encode(),
                );
                expect(find.textContaining('Попробуем ещё.'), findsOneWidget);
              }
              switch (step.action) {
                case AdventureAction.inspect:
                  await tap(const Key('adventure-submit'));
                case AdventureAction.dialogue:
                case AdventureAction.route:
                  await tap(ValueKey('answer-${step.answer}'));
                case AdventureAction.assemble:
                  for (final tile in step.answer.split(' ')) {
                    await tap(ValueKey('tile-$tile'));
                  }
                  await capture('signal');
                  await tap(const Key('adventure-submit'));
                case AdventureAction.cargo:
                  if (step.id == 'sort-book') {
                    await tap(const Key('cargo-pen'));
                    await tap(const Key('adventure-submit'));
                    expect(
                      find.textContaining('Попробуем ещё.'),
                      findsOneWidget,
                    );
                    await capture('cargo-error');
                  }
                  if (!small) {
                    await tester.ensureVisible(
                      find.byKey(const Key('cargo-target')),
                    );
                    await tester.pumpAndSettle();
                    final src = tester.getCenter(
                      find.byKey(ValueKey('cargo-${step.answer}')),
                    );
                    final dst = tester.getCenter(
                      find.byKey(const Key('cargo-target')),
                    );
                    await tester.dragFrom(src, dst - src);
                    await flushDb(tester);
                    await film();
                  } else {
                    await tap(ValueKey('cargo-${step.answer}'));
                    await tap(const Key('adventure-submit'));
                  }
              }
            }
            expect(
              (await tester.runAsync(() => game.read(adventure.id)))!.completed,
              true,
            );
            expect(app.progress.xp, before + adventure.xp);
            await capture('${adventure.id}-complete');
            await film();
          }
          router.go('/profile');
          await flushDb(tester);
          expect(app.progress.completed.length, 5);
          router.go('/map');
          await flushDb(tester);
          await tester.pumpWidget(const SizedBox());
          await tester.runAsync(r.db.close);
        },
      );
    }
  }
}
