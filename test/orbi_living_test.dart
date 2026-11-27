import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/ui/character_moment.dart';

void main() {
  testWidgets(
    'Orbi holds speech beyond a gesture and returns after every reaction',
    (tester) async {
      Future<void> show(
        CharacterState state, {
        bool motion = true,
        bool visible = true,
        bool reduce = false,
      }) async {
        await tester.pumpWidget(
          MaterialApp(
            home: MediaQuery(
              data: MediaQueryData(disableAnimations: reduce),
              child: TickerMode(
                enabled: visible,
                child: CharacterMoment(
                  characterId: 'orbi',
                  state: state,
                  animate: motion,
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await show(CharacterState.talking);
      await tester.pump(const Duration(seconds: 12));
      expect(find.byKey(const ValueKey('orbi-talk')), findsOneWidget);
      await show(CharacterState.idle);
      expect(find.byKey(const ValueKey('orbi-hover')), findsOneWidget);
      for (final state in [
        CharacterState.greeting,
        CharacterState.correct,
        CharacterState.support,
        CharacterState.surprise,
        CharacterState.celebration,
        CharacterState.goodbye,
      ]) {
        await show(state);
        expect(find.byKey(const ValueKey('orbi-hover')), findsNothing);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('orbi-hover')), findsOneWidget);
      }
      await show(CharacterState.talking, visible: false);
      expect(find.byKey(const ValueKey('orbi-rest')), findsOneWidget);
      await show(CharacterState.talking, motion: false);
      expect(find.byKey(const ValueKey('orbi-rest')), findsOneWidget);
      await show(CharacterState.talking, reduce: true);
      expect(find.byKey(const ValueKey('orbi-rest')), findsOneWidget);
      await show(CharacterState.talking);
      final dynamic moment = tester.state(find.byType(CharacterMoment));
      moment.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byKey(const ValueKey('orbi-rest')), findsOneWidget);
      moment.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.byKey(const ValueKey('orbi-talk')), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
