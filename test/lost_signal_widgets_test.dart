import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/lost_signal_mission.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);

  testWidgets('player completes Lost Signal through scene objects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = memoryRepository();
    final app = AppController(repository);
    await tester.runAsync(app.initialize);
    await tester.runAsync(
      () => app.saveAudio(
        const AudioPreferences(speech: false, effects: false, reactions: false),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const MaterialApp(home: LostSignalMissionPage()),
      ),
    );
    await flushDb(tester);

    Future<void> tap(Key key) async {
      await tester.tap(find.byKey(key));
      await flushDb(tester);
      expect(tester.takeException(), isNull, reason: '$key');
    }

    await tap(const Key('lost-signal-start'));
    await tap(const Key('door-red'));
    expect(find.textContaining('not blue'), findsOneWidget);
    await tap(const Key('door-blue'));
    expect(find.text('CONTROL ROOM'), findsOneWidget);
    await tap(const Key('object-blue-key'));
    expect(find.textContaining('Nothing useful'), findsOneWidget);
    await tap(const Key('object-red-key'));
    await tap(const Key('object-battery'));
    await tap(const ValueKey('reply-No, I don’t have the battery.'));
    expect(find.textContaining('Check your inventory'), findsOneWidget);
    await tap(const ValueKey('reply-Yes, I have the battery.'));
    await tap(const Key('power-unit'));
    await tap(const ValueKey('button-red'));
    expect(find.textContaining('not green'), findsOneWidget);
    await tap(const ValueKey('button-green'));
    expect(find.text('SIGNAL RESTORED'), findsOneWidget);
    expect(app.inventory.grants, hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.db.close();
  });

  testWidgets('mission remains usable at 320 px and 200% text', (tester) async {
    tester.view.physicalSize = const Size(320, 760);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repository = memoryRepository();
    final app = AppController(repository);
    await tester.runAsync(app.initialize);
    await tester.runAsync(
      () => app.saveAudio(
        const AudioPreferences(speech: false, effects: false, reactions: false),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const MaterialApp(home: LostSignalMissionPage()),
      ),
    );
    await flushDb(tester);
    expect(find.byKey(const Key('lost-signal-start')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.db.close();
  });
}
