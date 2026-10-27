import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/pages.dart';
import 'package:orbitwords/ui/rewards_pages.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  for (final small in [false, true]) {
    testWidgets(
      'main screens: ${small ? '320px 200 percent' : '390px captures'} in both themes',
      (tester) async {
        tester.view.physicalSize = Size(small ? 320 : 390, small ? 760 : 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await loadPreviewFonts();
          if (Platform.environment['CAPTURE_UI'] == '1') {
            await Directory('test-output/v07').create(recursive: true);
          }
        });
        for (final brightness in Brightness.values) {
          for (final name in [
            'home',
            'words',
            'review',
            'profile',
            'rewards',
            'story',
            'completion',
            'correct',
            'support',
            'quests',
          ]) {
            final repo = memoryRepository();
            final app = AppController(repo);
            await tester.runAsync(() async {
              await app.initialize();
              await app.saveAudio(
                const AudioPreferences(
                  speech: false,
                  effects: false,
                  reactions: false,
                ),
              );
              for (var n = 1; n <= 11; n++) {
                final material = await repo.startLesson(
                  'a1-${n.toString().padLeft(2, '0')}',
                );
                for (var i = 0; i < 10; i++) {
                  final e = material.lesson.exercises[i];
                  await repo.answer(
                    material.session.id,
                    i,
                    e,
                    e.answers.first,
                    total: 10,
                  );
                }
              }
              final active = await repo.startLesson('a1-12');
              await repo.markTeachingSeen(active.session.id);
              await repo.answer(
                active.session.id,
                0,
                active.lesson.exercises.first,
                'wrong',
                total: 10,
              );
              for (var i = 0; i < (name == 'completion' ? 9 : 7); i++) {
                final e = active.lesson.exercises[i];
                await repo.answer(
                  active.session.id,
                  i,
                  e,
                  e.answers.first,
                  total: 10,
                );
              }
              await app.refresh();
            });
            final key = GlobalKey();
            final page = switch (name) {
              'home' => const HomePage(),
              'words' => const WordsPage(),
              'review' => const ReviewPage(mistakesOnly: true),
              'profile' => const ProfilePage(),
              'rewards' => const RewardsPage(),
              'quests' => const QuestsPage(),
              _ => const LessonScreen(lessonId: 'a1-12'),
            };
            await tester.pumpWidget(
              ProviderScope(
                overrides: [appProvider.overrideWith((_) => app)],
                child: MaterialApp(
                  theme: orbitTheme(brightness),
                  home: MediaQuery(
                    data: MediaQueryData(
                      size: tester.view.physicalSize,
                      textScaler: TextScaler.linear(small ? 2 : 1),
                      disableAnimations: true,
                    ),
                    child: RepaintBoundary(
                      key: key,
                      child:
                          [
                            'story',
                            'completion',
                            'correct',
                            'support',
                          ].contains(name)
                          ? page
                          : OrbitShell(
                              location: name == 'home' ? '/' : '/$name',
                              child: page,
                            ),
                    ),
                  ),
                ),
              ),
            );
            await flushDb(tester);
            if (name == 'correct' || name == 'support') {
              final option = find.widgetWithText(
                OutlinedButton,
                name == 'correct' ? 'It is under the chair.' : 'It is a cup.',
              );
              await tester.scrollUntilVisible(
                option,
                220,
                maxScrolls: 40,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.tap(option);
              await flushDb(tester);
              await tester.tap(find.text('Проверить'));
              await flushDb(tester);
            }
            if (name == 'completion') {
              await tester.scrollUntilVisible(
                find.byType(TextField),
                220,
                maxScrolls: 40,
                scrollable: find.byType(Scrollable).first,
              );
              await tester.enterText(
                find.byType(TextField),
                'You are welcome.',
              );
              await flushDb(tester);
              await tester.tap(find.text('Проверить'));
              await flushDb(tester);
              await tester.tap(find.text('Дальше'));
              await flushDb(tester);
              expect(app.progress.completed, contains('a1-12'));
            }
            await tester.runAsync(() async {
              for (final asset in [
                'orbi_thinking',
                'orbi_happy',
                'orbi_logo',
                'miko',
                'zig_quartz',
                'explorer_closed',
                'nebula_closed',
                'supernova_closed',
                'pixie',
                'aster',
              ]) {
                await precacheImage(
                  AssetImage('assets/kvesmos/$asset.png'),
                  key.currentContext!,
                );
              }
            });
            await tester.pumpAndSettle();
            expect(
              tester.takeException(),
              isNull,
              reason: '$name $brightness small=$small',
            );
            await tester.runAsync(
              () => capturePreview(
                key,
                'v07/$name-${brightness.name}${small ? '-320-200' : ''}',
              ),
            );
            // Inspect content below the fold as well as the initial viewport.
            final scrollables = find.byType(Scrollable);
            if (scrollables.evaluate().isNotEmpty) {
              await tester.drag(scrollables.first, const Offset(0, -480));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull, reason: 'scrolled $name');
            }
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.runAsync(repo.db.close);
          }
        }
      },
    );
  }
}
