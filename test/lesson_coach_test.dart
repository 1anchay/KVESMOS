import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/ui/character_moment.dart';
import 'package:orbitwords/ui/lesson_coach.dart';

void main() {
  late Lesson first;
  setUpAll(() {
    first = Lesson.fromJson(
      jsonDecode(File('assets/courses/demo/a1-01.json').readAsStringSync())
          as Map<String, dynamic>,
    );
  });

  test('first lesson has authored optional hints for every activity', () {
    expect(first.exercises, hasLength(10));
    for (final activity in first.exercises) {
      expect(activity.hint, isNotNull, reason: activity.id);
      expect(activity.hint!.trim(), isNotEmpty, reason: activity.id);
      expect(activity.explanation.trim(), isNotEmpty, reason: activity.id);
    }
  });

  testWidgets('hints are voluntary and explain focus vocabulary', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LessonCoachCard(
              lesson: first,
              exercise: first.exercises.first,
            ),
          ),
        ),
      ),
    );
    expect(find.text('Нужна подсказка?'), findsOneWidget);
    expect(find.text(first.exercises.first.hint!), findsNothing);
    await tester.tap(find.text('Нужна подсказка?'));
    await tester.pumpAndSettle();
    expect(find.text(first.exercises.first.hint!), findsOneWidget);
    expect(find.text('hello — привет'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the character moment changes Orbi artwork without loops', (
    tester,
  ) async {
    bool? correct;
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return CharacterMoment(characterId: 'orbi', correct: correct);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => correct = true);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.auto_awesome_rounded), findsOneWidget);
    expect(tester.binding.hasScheduledFrame, false);
    expect(tester.takeException(), isNull);
  });
}
