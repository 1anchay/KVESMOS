import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/progress.dart';
import 'package:orbitwords/ui/character_reactions.dart';
import 'package:orbitwords/ui/design.dart';

void main() {
  test('daily XP record needs history, ignores future days, excludes ties', () {
    final p = ProgressSnapshot();
    final today = DateTime(2026, 10, 21);
    p.dailyXp['2026-10-21'] = 120;
    expect(hasDailyXpRecord(p, today), isFalse);
    p.dailyXp['2026-10-20'] = 120;
    expect(hasDailyXpRecord(p, today), isFalse);
    p.dailyXp['2026-10-21'] = 130;
    p.dailyXp['2026-10-22'] = 500;
    expect(hasDailyXpRecord(p, today), isTrue);
    expect(hasDailyXpRecord(p, DateTime(2026, 10, 23)), isFalse);
  });
  test(
    'tutors match exercise context and every reaction uses existing artwork',
    () {
      expect(CharacterCue.tutor(ExerciseType.pairs).id, 'zig_quartz');
      expect(CharacterCue.tutor(ExerciseType.correct).id, 'vespa');
      expect(CharacterCue.tutor(ExerciseType.order).id, 'miko');
      expect(CharacterCue.tutor(ExerciseType.listen).id, 'nox');
      final cues = [
        CharacterCue.greeting,
        CharacterCue.correct,
        CharacterCue.support,
        CharacterCue.completed,
        CharacterCue.reward,
        CharacterCue.record(150),
        CharacterCue.pixieReady,
        CharacterCue.pixieReward('Редкий', fresh: true),
        CharacterCue.navigator,
        CharacterCue.words,
        CharacterCue.practice,
        CharacterCue.engineer,
        CharacterCue.detective,
        CharacterCue.keeper,
        CharacterCue.scholar,
      ];
      for (final cue in cues) {
        final name = cue.id == 'orbi' ? 'orbi_${cue.emotion}' : cue.id;
        expect(
          File('assets/kvesmos/$name.png').existsSync(),
          isTrue,
          reason: name,
        );
        expect(cue.lines.length, greaterThan(1));
      }
      expect(
        CharacterCue.pixieReward('Редкий', fresh: false).lines.first,
        contains('сохранённая'),
      );
    },
  );
  testWidgets(
    'reactions change on events, tap offers another line and has no perpetual animation',
    (tester) async {
      var cue = CharacterCue.greeting;
      var event = 'entry';
      late StateSetter change;
      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              change = setState;
              return Scaffold(
                body: CharacterReaction(cue: cue, eventKey: event),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(CharacterCue.greeting.lines.first), findsOneWidget);
      await tester.tap(find.byType(CharacterReaction));
      await tester.pumpAndSettle();
      expect(find.text(CharacterCue.greeting.lines[1]), findsOneWidget);
      change(() {
        cue = CharacterCue.support;
        event = 'answer:wrong';
      });
      await tester.pumpAndSettle();
      expect(find.text(CharacterCue.support.lines.first), findsOneWidget);
      expect(
        tester.widget<OrbitRobot>(find.byType(OrbitRobot)).emotion,
        'thinking',
      );
      change(() {
        cue = CharacterCue.correct;
        event = 'answer:correct';
      });
      await tester.pumpAndSettle();
      expect(find.text(CharacterCue.correct.lines.first), findsOneWidget);
      expect(
        tester.widget<OrbitRobot>(find.byType(OrbitRobot)).emotion,
        'happy',
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'all characters fit a narrow screen at 200% text in both themes with reduced motion',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cues = [
        CharacterCue.greeting,
        CharacterCue.support,
        CharacterCue.pixieReward('Легендарный', fresh: true),
        CharacterCue.engineer,
        CharacterCue.navigator,
        CharacterCue.practice,
        CharacterCue.words,
        CharacterCue.detective,
        CharacterCue.keeper,
        CharacterCue.scholar,
      ];
      for (final brightness in Brightness.values) {
        for (final cue in cues) {
          await tester.pumpWidget(
            MaterialApp(
              theme: orbitTheme(brightness),
              home: MediaQuery(
                data: const MediaQueryData(
                  disableAnimations: true,
                  textScaler: TextScaler.linear(2),
                ),
                child: Scaffold(
                  body: SingleChildScrollView(
                    child: CharacterReaction(cue: cue, eventKey: cue.id),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text(cue.lines.first), findsOneWidget);
          expect(
            tester.takeException(),
            isNull,
            reason: '${cue.id} $brightness',
          );
        }
      }
    },
  );
}
