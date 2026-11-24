import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/ui/cutout_actor.dart';
import 'package:orbitwords/ui/design.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  testWidgets('joint animation preview on Android', (tester) async {
    Future<void> marker(String text) async {
      final result = await Process.run('/system/bin/log', [
        '-t',
        'KVESMOS11',
        text,
      ]);
      expect(result.exitCode, 0);
    }

    await marker('VIDEO_START:en');
    for (final id in ['orbi', 'miko']) {
      for (final action in ActorAction.values) {
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
                    CutoutActor(
                      key: ValueKey((id, action)),
                      character: id,
                      action: action,
                      size: 260,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await Future<void>.delayed(const Duration(milliseconds: 1000));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await marker('CAPTURE:cutout-$id-${action.name}');
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      }
    }
    await marker('VIDEO_DONE:en');
    await tester.pumpWidget(const SizedBox.shrink());
    await marker('DONE');
  });
}
