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

  test('first A1 lesson teaches before asking and follows a coherent arc', () {
    expect(first.teachingSteps, hasLength(3));
    expect(
      first.teachingSteps.map((step) => step.phrase),
      ['Hello!', 'My name is Miko.', 'Goodbye!'],
    );
    for (final step in first.teachingSteps) {
      expect(step.translation, isNotEmpty);
      expect(step.explanation, isNotEmpty);
    }
    expect(first.exercises.first.type, ExerciseType.choice);
    expect(first.exercises.first.prompt, contains('станции'));
    expect(first.exercises.map((e) => e.type).toSet(), contains(ExerciseType.dialogue));
    expect(first.exercises.map((e) => e.type).toSet(), contains(ExerciseType.listen));
    expect(first.exercises.last.prompt, contains('Goodbye'));
  });

  test('all guided A1 lessons introduce concepts before independent recall', () {
    for (final id in ['a1-01', 'a1-02', 'a1-03']) {
      final lesson = Lesson.fromJson(
        jsonDecode(File('assets/courses/demo/$id.json').readAsStringSync())
            as Map<String, dynamic>,
      );
      expect(lesson.teachingSteps.length, greaterThanOrEqualTo(3), reason: id);
      expect(lesson.exercises, hasLength(10), reason: id);
      for (final step in lesson.teachingSteps) {
        expect(step.phrase.trim(), isNotEmpty);
        expect(step.translation.trim(), isNotEmpty);
        expect(step.explanation.trim(), isNotEmpty);
      }
      expect(lesson.exercises.first.options, isNotEmpty);
      expect(lesson.exercises.map((e) => e.type).toSet(), contains(ExerciseType.review));
      expect(
        lesson.exercises.map((e) => e.type).toSet(),
        contains(ExerciseType.dialogue),
      );
      for (final exercise in lesson.exercises) {
        expect(exercise.explanation, isNotEmpty, reason: exercise.id);
        expect(exercise.hint?.trim(), isNotEmpty, reason: exercise.id);
        expect(exercise.wordIds, isNotEmpty, reason: exercise.id);
        if (exercise.options.isNotEmpty) {
          expect(exercise.options.any((o) => checkAnswer(exercise, o)), true);
          expect(exercise.options.any((o) => !checkAnswer(exercise, o)), true);
        }
        if (exercise.tokens.isNotEmpty) {
          expect(checkAnswer(exercise, exercise.tokens.join(' ')), true);
        }
      }
    }
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
