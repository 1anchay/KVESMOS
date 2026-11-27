import 'dart:io';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/lost_signal_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/lost_signal.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('play Lost Signal, make mistakes, persist and replay safely', (
    tester,
  ) async {
    final learning = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(learning);
    await app.initialize();
    await app.finishOnboarding();
    await app.saveAudio(
      const AudioPreferences(speech: true, effects: true, reactions: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();

    Future<void> mark(String value) async {
      expect(
        (await Process.run('/system/bin/log', [
          '-t',
          'KVESMOS11',
          value,
        ])).exitCode,
        0,
      );
    }

    Future<void> tap(Key key, [int pauseMs = 2400]) async {
      final target = find.byKey(key);
      expect(target, findsOneWidget, reason: '$key');
      await tester.ensureVisible(target);
      await tester.tap(target);
      await Future<void>.delayed(Duration(milliseconds: pauseMs));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: '$key');
    }

    final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
    router.go('/adventures');
    await tester.pumpAndSettle();
    await mark('VIDEO_START:en');
    await Future<void>.delayed(const Duration(seconds: 2));
    await tap(const Key('mission-lost-signal'));
    await mark('CAPTURE:lost-signal-intro');
    await tap(const Key('lost-signal-intro-voice'), 3000);
    expect(app.audio.lastSource, SpeechSource.recording);
    await tap(const Key('lost-signal-start'), 3000);
    expect(app.audio.lastSource, SpeechSource.recording);
    await tap(const Key('door-red'));
    expect(find.textContaining('not blue'), findsOneWidget);
    await tap(const Key('door-blue'), 3000);
    await mark('CAPTURE:lost-signal-control-room');
    await tap(const Key('object-blue-key'));
    await tap(const Key('object-red-key'));
    await tap(const Key('object-battery'), 3000);
    await tap(const ValueKey('reply-No, I don’t have the battery.'));
    expect(find.textContaining('Check your inventory'), findsOneWidget);
    await tap(const ValueKey('reply-Yes, I have the battery.'), 3000);
    await tap(const Key('power-unit'), 3000);
    await tap(const ValueKey('button-red'));
    await tap(const ValueKey('button-green'), 4000);
    expect(find.text('SIGNAL RESTORED'), findsOneWidget);
    expect(app.inventory.grants.keys, contains(LostSignalMission.rewardId));
    expect(app.progress.xp, 30);
    await mark('CAPTURE:lost-signal-complete');
    await mark('VIDEO_DONE:en');

    await tap(const Key('lost-signal-replay'), 200);
    final mission = LostSignalRepository(learning);
    var state = await mission.read();
    Future<void> act(String action, [String value = '']) async {
      state = await mission.act(state.revision, action, value: value);
    }

    await act('start');
    await act('door', 'blue');
    await act('collect', 'red_key');
    await act('collect', 'battery');
    await act('reply', 'Yes, I have the battery.');
    await act('install');
    await act('button', 'green');
    await app.refresh();
    expect(app.progress.xp, 30);
    expect(
      app.inventory.grants.keys.where((id) => id == LostSignalMission.rewardId),
      hasLength(1),
    );
    await mark('DONE');
    await tester.pumpWidget(const SizedBox.shrink());
    await learning.db.close();
  });
}
