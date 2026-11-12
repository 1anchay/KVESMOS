import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/today.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/pages.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/today_page.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;
import 'audio_settings_test.dart' show loadPreviewFonts, capturePreview;

void main() {
  setUpAll(setupSqlite);
  test('six newly learned words wait for the real SM-2 review date', () async {
    var now = DateTime(2026, 10, 26, 12);
    final r = memoryRepository(now: () => now);
    final app = AppController(r);
    await app.initialize();
    await r.append(
      r.event('answer', {
        'session': 'words',
        'exercise': 'new',
        'correct': true,
        'words': [
          'en:hello',
          'en:name',
          'en:goodbye',
          'en:from',
          'en:friend',
          'en:welcome',
        ],
      }),
    );
    await app.refresh();
    expect(app.progress.words.length, 6);
    expect(reviewReadyToday(app), false);
    now = DateTime(2026, 10, 28, 12);
    await app.refresh();
    expect(reviewReadyToday(app), true);
    expect(app.missions!.progress.reviewed, isEmpty);
    app.dispose();
    await r.db.close();
  });
  test(
    'daily arrival is durable, concurrent-safe and never awards anything',
    () async {
      var now = DateTime(2026, 10, 26, 23, 59);
      final r = memoryRepository(now: () => now);
      final app = AppController(r);
      await app.initialize();
      final results = await Future.wait(
        List.generate(
          3,
          (_) => app.claimExperienceMoment('arrival:2026-10-26'),
        ),
      );
      expect(results.where((v) => v), hasLength(1));
      expect(await app.claimExperienceMoment('arrival:2026-10-26'), false);
      expect(app.progress.xp, 0);
      expect(app.inventory.grants, isEmpty);
      now = DateTime(2026, 10, 27);
      expect(await app.claimExperienceMoment('arrival:2026-10-27'), true);
      expect(await app.claimExperienceMoment('arrival:2026-10-26'), false);
      expect(await r.setting('reminders'), isNull);
      app.dispose();
      await r.db.close();
    },
  );
  for (final small in [false, true]) {
    testWidgets('today states ${small ? '320px 200%' : '390px above fold'}', (
      tester,
    ) async {
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
        for (final mode in ['first', 'returning', 'partial', 'complete']) {
          var clock = DateTime(2026, 10, 26, 12);
          final r = memoryRepository(now: () => clock);
          final app = AppController(r);
          await tester.runAsync(() async {
            await app.initialize();
            await app.saveAudio(
              const AudioPreferences(
                speech: false,
                effects: false,
                reactions: false,
              ),
            );
            if (mode == 'returning') clock = DateTime(2026, 10, 20);
            final count = mode == 'first'
                ? 0
                : mode == 'complete'
                ? 10
                : 2;
            for (var i = 0; i < count; i++) {
              await r.append(
                r.event('answer', {
                  'session': 'fixture',
                  'exercise': 'e$i',
                  'correct': true,
                  'words': ['en:hello'],
                }),
              );
            }
            if (mode == 'complete') {
              await r.append(
                r.event('complete', {'session': 'fixture', 'lesson': 'a1-01'}),
              );
            }
            clock = DateTime(2026, 10, 26, 12);
            await app.refresh();
          });
          final expected = switch (mode) {
            'first' => TodayMood.firstFlight,
            'returning' => TodayMood.returning,
            'partial' => TodayMood.underway,
            _ => TodayMood.complete,
          };
          expect(TodayJourney(app.progress, clock, app.goal).mood, expected);
          final boundary = GlobalKey();
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
                    key: boundary,
                    child: const OrbitShell(location: '/', child: HomePage()),
                  ),
                ),
              ),
            ),
          );
          await flushDb(tester);
          await tester.runAsync(
            () => precacheImage(
              const AssetImage('assets/kvesmos/orbi_thinking.png'),
              boundary.currentContext!,
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$mode $brightness small=$small',
          );
          if (!small) {
            expect(
              tester.getBottomRight(find.byKey(const Key('today-start'))).dy,
              lessThan(680),
            );
            expect(find.byType(MissionFlightRow), findsNWidgets(3));
            expect(
              tester.getBottomRight(find.byType(MissionFlightRow).last).dy,
              lessThan(760),
            );
          }
          await tester.runAsync(
            () => capturePreview(
              boundary,
              'v07/today-$mode-${brightness.name}${small ? '-320-200' : ''}',
            ),
          );
          expect(
            app.progress.xp,
            mode == 'first'
                ? 0
                : mode == 'complete'
                ? 120
                : 20,
          );
          final grants = app.inventory.grants.length;
          await tester.runAsync(app.refresh);
          await flushDb(tester);
          expect(app.inventory.grants.length, grants);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.runAsync(r.db.close);
        }
      }
    });
  }
}
