import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/domain/intro_activity.dart';
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
  for (final id in [
    'a1-01',
    'en-a1-40',
    'es-a1-01',
    'es-a1-18',
    'de-a1-01',
    'de-a1-18',
    'fr-a1-01',
    'fr-a1-12',
    'zh-a1-01',
    'zh-a1-12',
  ]) {
    testWidgets('$id: immediate action, mistake, help, exact resume, no voice', (
      tester,
    ) async {
      final lesson = Lesson.fromJson(
        jsonDecode(
          File(
            'assets/courses/${id == 'a1-01' ? 'demo/' : ''}$id.json',
          ).readAsStringSync(),
        ),
      );
      final audio = LearningAudio(
        (_) async => null,
        (_, _) async {},
        backend: FakeTts()..installed = [],
      );
      IntroDraft? saved;
      var started = 0;
      Widget screen() => MaterialApp(
        home: LessonIntroduction(
          lesson: lesson,
          audio: audio,
          initialDraft: saved,
          onDraft: (draft) async {
            saved = draft;
          },
          onStart: () async {
            started++;
          },
        ),
      );
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      final first = lesson.guidedIntroduction.first;
      expect(find.text(first.phrase), findsOneWidget);
      expect(find.text(first.prompt), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('teaching-next')))
            .onPressed,
        isNull,
      );
      final wrong = first.options.indexWhere((s) => s != first.answer);
      expect(wrong, greaterThanOrEqualTo(0));
      await tester.ensureVisible(find.byKey(ValueKey('intro-option-$wrong')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('intro-option-$wrong')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teaching-next')));
      await tester.pumpAndSettle();
      expect(saved!.actions[first.id]['wrong'], true);
      expect(started, 0);
      await tester.ensureVisible(find.byKey(const Key('intro-reveal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('intro-reveal')));
      await tester.pumpAndSettle();
      expect(saved!.actions[first.id]['reveal'], true);
      await tester.tap(find.byTooltip('Послушать пример'));
      await tester.pumpAndSettle();
      expect(audio.lastProblem, isNotNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(screen());
      await tester.pumpAndSettle();
      expect(find.textContaining('Пока не совпало'), findsOneWidget);
      expect(find.text(first.translation), findsWidgets);
      final right = find.byKey(
        ValueKey('intro-option-${first.options.indexOf(first.answer)}'),
      );
      await tester.ensureVisible(right);
      await tester.pumpAndSettle();
      await tester.tap(right);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('teaching-next')));
      await tester.pumpAndSettle();
      expect(saved!.actions[first.id]['solved'], true);
      // A correct answer does not complete the lesson or force reading a rule.
      expect(started, 0);
      await tester.tap(find.byKey(const Key('teaching-next')));
      await tester.pumpAndSettle();
      expect(saved!.index, 1);
      await tester.tap(find.byKey(const Key('teaching-back')));
      await tester.pumpAndSettle();
      expect(saved!.index, 0);
      expect(saved!.actions[first.id]['solved'], true);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('320dp/200% retains fixed controls and durable token draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final lesson = Lesson.fromJson(
      jsonDecode(File('assets/courses/demo/a1-01.json').readAsStringSync()),
    );
    final audio = LearningAudio(
      (_) async => null,
      (_, _) async {},
      backend: FakeTts(),
    );
    IntroDraft? saved;
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
            initialStep: 1,
            onDraft: (draft) async {
              saved = draft;
            },
            onStart: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('teaching-next')).hitTestable(),
      findsOneWidget,
    );
    final token = find.byKey(const Key('intro-token-0'));
    await tester.ensureVisible(token);
    await tester.pumpAndSettle();
    await tester.tap(token);
    await tester.pumpAndSettle();
    expect(saved!.actions['legacy-1']['tokens'], [0]);
    expect(tester.takeException(), isNull);
  });
  test(
    'new draft coexists with old position and scored session draft, without XP',
    () async {
      setupSqlite();
      final repo = memoryRepository();
      await repo.initialize();
      final original = await repo.startLesson('a1-01');
      await repo.saveTeachingStep(original.session.id, 1);
      expect((await repo.introDraft(original.session.id)).index, 1);
      await repo.draft(original.session.id, 0, '{"text":"draft"}');
      const draft = IntroDraft(
        index: 1,
        actions: {
          'legacy-1': {
            'tokens': [0, 2],
            'reveal': true,
          },
        },
      );
      await repo.saveIntroDraft(original.session.id, draft);
      final reopened = await repo.startLesson('a1-01');
      expect(reopened.session.id, original.session.id);
      expect(
        (await repo.introDraft(reopened.session.id)).toJson(),
        draft.toJson(),
      );
      expect(reopened.session.draft, '{"text":"draft"}');
      expect(await repo.hasTeachingSeen(reopened.session.id), false);
      expect(await repo.db.select(repo.db.events).get(), isEmpty);
      await repo.db.close();
    },
  );
}
