import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'learning_audio_test.dart' show FakeTts;
import 'support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SoundEffectsService.channel,
          (_) async => true,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SoundEffectsService.channel, null);
  });
  final lesson = Lesson.fromJson(
    jsonDecode(File('assets/courses/demo/a1-01.json').readAsStringSync()),
  );
  testWidgets(
    'all teaching steps are reachable at 200% and back resets scroll',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var started = 0;
      final steps = <int>[];
      final audio = LearningAudio(
        (_) async => null,
        (_, _) async {},
        backend: FakeTts(),
      );
      final pending = Completer<void>();
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: LessonIntroduction(
              lesson: lesson,
              audio: audio,
              onStep: (step) async {
                steps.add(step);
              },
              onStart: () async {
                started++;
                await pending.future;
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final next = find.byKey(const Key('teaching-next'));
      for (var i = 0; i < 2; i++) {
        expect(next.hitTestable(), findsOneWidget);
        await tester.tap(next);
        await tester.pumpAndSettle();
      }
      expect(find.text('Начать практику'), findsOneWidget);
      await tester.tap(find.byKey(const Key('teaching-back')));
      await tester.pumpAndSettle();
      expect(steps, [1, 2, 1]);
      expect(
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .pixels,
        0,
      );
      await tester.tap(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      await tester.tap(next);
      await tester.pump();
      expect(started, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'teaching progress survives reopening without answer events or XP',
    () async {
      setupSqlite();
      final repo = memoryRepository();
      await repo.initialize();
      final original = await repo.startLesson('a1-01');
      await repo.saveTeachingStep(original.session.id, 2);
      final reopened = await repo.startLesson('a1-01');
      expect(reopened.session.id, original.session.id);
      expect(await repo.teachingStep(reopened.session.id), 2);
      expect(await repo.hasTeachingSeen(reopened.session.id), false);
      expect(reopened.session.position, 0);
      expect(await repo.db.select(repo.db.events).get(), isEmpty);
      await repo.db.close();
    },
  );
}
