import 'dart:io';
import 'dart:ui' show FrameTiming;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/ui/character_animation_catalog.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'package:orbitwords/ui/design.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('approved companion poses on Android', (tester) async {
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> frames) => timings.addAll(frames);
    binding.addTimingsCallback(collect);
    addTearDown(() => binding.removeTimingsCallback(collect));
    Future<void> marker(String text) async {
      final result = await Process.run('/system/bin/log', [
        '-t',
        'KVESMOS11',
        text,
      ]);
      expect(result.exitCode, 0);
    }

    for (final id in ['orbi', ...CharacterAnimationCatalog.cast]) {
      final slug = id.replaceAll('_', '-');
      for (final action in [
        CharacterState.idle,
        CharacterState.correct,
        CharacterState.support,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: orbitTheme(Brightness.dark),
            home: Scaffold(
              appBar: AppBar(title: const Text('Animation Gallery · QA')),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$id · ${action.name}'),
                    CharacterMoment(
                      key: ValueKey((id, action)),
                      characterId: id,
                      state: action,
                      size: 260,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        if (action == CharacterState.idle) {
          await marker('VIDEO_START:$id');
          await Future<void>.delayed(const Duration(seconds: 6));
        }
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await marker('CAPTURE:companion-$slug-${action.name}');
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
      await marker('VIDEO_DONE:$id');
      await Future<void>.delayed(const Duration(seconds: 1));
    }
    if (timings.length > 10) {
      final frames = timings.skip(10).toList();
      final build =
          frames.map((f) => f.buildDuration.inMicroseconds / 1000).toList()
            ..sort();
      final raster =
          frames.map((f) => f.rasterDuration.inMicroseconds / 1000).toList()
            ..sort();
      // Debug/emulator measurements are diagnostics, not a release FPS claim.
      debugPrint(
        'ART_FRAME_TIMINGS debug emulator: count=${frames.length}, build_p95_ms=${build[(build.length * .95).floor()]}, raster_p95_ms=${raster[(raster.length * .95).floor()]}',
      );
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await marker('DONE');
  });
}
