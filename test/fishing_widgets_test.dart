import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/fishing_story.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/fishing_page.dart';

import 'fishing_fixture.dart';
import 'support.dart';

void main() {
  setUpAll(setupSqlite);
  testWidgets('departure can refresh after a radio sheet is dismissed', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final learning = memoryRepository();
    final app = AppController(learning);
    await tester.runAsync(() async {
      await saveCompletedFirstFlight(learning);
      await app.initialize();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: MaterialApp(
          theme: orbitTheme(Brightness.light),
          home: const FishingDeparturePage(),
        ),
      ),
    );
    Future<void> waitFor(Finder target) async {
      for (var i = 0; i < 15 && target.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 75)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(target, findsOneWidget);
    }

    final briefing = find.byKey(const Key('fishing-briefing'));
    await waitFor(briefing);
    await tester.ensureVisible(briefing);
    await tester.tap(briefing);
    final close = find.byKey(const Key('story-close'));
    await waitFor(close);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(close);
    await tester.pump(const Duration(milliseconds: 350));
    await waitFor(briefing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(learning.db.close);
  });

  for (final brightness in Brightness.values) {
    testWidgets('fishing in ${brightness.name} at 320dp and 200% text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final learning = memoryRepository();
      final app = AppController(learning);
      await tester.runAsync(() async {
        await saveCompletedFirstFlight(learning);
        await app.initialize();
        final scene = FishingStory.briefing;
        final story = StoryRepository(learning);
        var run = (await story.open(scene)).run;
        for (final action in [
          StoryMove.next,
          StoryMove.submit,
          StoryMove.next,
          StoryMove.next,
          StoryMove.next,
        ]) {
          run = (await story.move(
            scene,
            run.revision,
            action,
            action == StoryMove.submit ? 'I need a rod.' : null,
          )).run;
        }
        expect(run.finished, true);
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: MaterialApp(
            theme: orbitTheme(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(2),
                disableAnimations: true,
              ),
              child: child!,
            ),
            home: const FishingPage(),
          ),
        ),
      );
      final aim = find.byKey(const Key('fishing-aim'));
      for (var i = 0; i < 10 && aim.evaluate().isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 80)),
        );
        await tester.pump(const Duration(milliseconds: 40));
      }
      expect(aim, findsOneWidget);
      await tester.ensureVisible(aim);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(aim);
      await tester.pump(const Duration(milliseconds: 100));
      final zone = find.byKey(const Key('fishing-zone-trench'));
      await tester.ensureVisible(zone);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(zone);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.textContaining('глубокая вода'), findsOneWidget);
      final charge = find.byKey(const Key('fishing-charge'));
      await tester.ensureVisible(charge);
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(charge);
      await tester.pump(const Duration(milliseconds: 50));
      final journal = find.byKey(const Key('fishing-journal'));
      await tester.tap(journal);
      await tester.pump(const Duration(milliseconds: 320));
      final meter = find.textContaining('Сила · ');
      final strength = tester.widget<Text>(meter).data;
      for (var i = 0; i < 25; i++) {
        await tester.pump(const Duration(milliseconds: 41));
      }
      expect(tester.widget<Text>(meter).data, strength);
      expect(find.byKey(const Key('journal-search')), findsOneWidget);
      await tester.tap(find.byTooltip('Закрыть'));
      await tester.pump(const Duration(milliseconds: 320));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(learning.db.close);
    });
  }
}
