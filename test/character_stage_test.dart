import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'package:orbitwords/ui/design.dart';
import 'support.dart';

void main() {
  testWidgets('Orbi reacts to touch and crew profiles are distinct', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: CharacterMoment(characterId: 'orbi', size: 150)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(CharacterMoment));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.bySemanticsLabel('Орби приветствует'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.binding.hasScheduledFrame, false);
    expect(
      CharacterAnimationProfile.forId('miko').tempo,
      isNot(CharacterAnimationProfile.forId('zig_quartz').tempo),
    );
  });
  testWidgets(
    'every character state has a visible finite gesture and reduced-motion pose',
    (tester) async {
      for (final state in CharacterState.values) {
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: CharacterMoment(
                key: ValueKey(state),
                characterId: 'orbi',
                state: state,
                size: 150,
              ),
            ),
          ),
        );
        final transforms = find.descendant(
          of: find.byType(CharacterMoment),
          matching: find.byType(Transform),
        );
        final initial = tester
            .widget<Transform>(transforms.first)
            .transform
            .clone();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          tester.widget<Transform>(transforms.first).transform,
          isNot(initial),
          reason: state.name,
        );
        await tester.pumpAndSettle();
        expect(tester.binding.hasScheduledFrame, false);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: const CharacterMoment(
              characterId: 'miko',
              state: CharacterState.celebration,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.binding.hasScheduledFrame, false);
    },
  );
  testWidgets('state renderer accepts supplied frame sequences', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CharacterMoment(
          characterId: 'orbi',
          state: CharacterState.correct,
          frames: {
            CharacterState.correct: [
              'assets/kvesmos/orbi_happy.png',
              'assets/kvesmos/orbi_wink_thumbsup.png',
            ],
          },
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('assets/kvesmos/orbi_happy.png')),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('assets/kvesmos/orbi_wink_thumbsup.png')),
      findsOneWidget,
    );
  });
  testWidgets(
    'animation gallery and blink frame render without layout failures',
    (tester) async {
      tester.view.physicalSize = const Size(900, 820);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      if (Platform.environment['CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          final font = FontLoader('OrbitSans')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
                ),
              ),
            );
          await font.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(
              Future.value(
                ByteData.sublistView(
                  await File(materialIconsFontPath()).readAsBytes(),
                ),
              ),
            );
          await icons.load();
        });
      }
      await tester.pumpWidget(
        MaterialApp(
          theme: orbitTheme(Brightness.dark),
          home: Scaffold(
            body: RepaintBoundary(
              key: key,
              child: GridView.count(
                crossAxisCount: 4,
                childAspectRatio: 1,
                children: [
                  for (final state in CharacterState.values)
                    Column(
                      children: [
                        CharacterMoment(
                          characterId: 'orbi',
                          state: state,
                          size: 150,
                        ),
                        Text(state.name),
                      ],
                    ),
                  const CharacterMoment(
                    characterId: 'miko',
                    state: CharacterState.greeting,
                    size: 150,
                  ),
                  const CharacterMoment(
                    characterId: 'pixie',
                    state: CharacterState.celebration,
                    size: 150,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (Platform.environment['CAPTURE_UI'] == '1') {
        await tester.runAsync(() async {
          for (final asset in [
            'orbi_thinking',
            'orbi_happy',
            'orbi_surprised',
            'orbi_wink_thumbsup',
            'miko',
            'pixie',
          ]) {
            await precacheImage(
              AssetImage('assets/kvesmos/$asset.png'),
              key.currentContext!,
            );
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          final boundary =
              key.currentContext!.findRenderObject() as RenderRepaintBoundary;
          final image = await boundary.toImage();
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await Directory('test-output').create(recursive: true);
          await File(
            'test-output/character-states.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    },
  );
}
