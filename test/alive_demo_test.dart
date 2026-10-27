// Optional recording of actual production widgets against an isolated database.
// CAPTURE_DEMO=1 flutter test test/alive_demo_test.dart
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'support.dart';
import 'audio_settings_test.dart' show loadPreviewFonts;
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';

void main() {
  setUpAll(setupSqlite);
  testWidgets('capture real Flutter journey frames for visual review', (
    tester,
  ) async {
    // Isolated fixture; never clear or modify the installed user's database.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final boundary = GlobalKey();
    var frame = 0;
    var frameDirectory = 'test-output/v07/frames';
    await tester.runAsync(() async {
      await loadPreviewFonts();
      await Directory('test-output/v07/frames').create(recursive: true);
    });
    Future<void> film([int count = 6]) async {
      for (var i = 0; i < count; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(() async {
          final object =
              boundary.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await object.toImage(pixelRatio: 1);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '$frameDirectory/${(frame++).toString().padLeft(5, '0')}.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
    }

    var now = DateTime(2026, 10, 26, 12);
    final repo = LearningRepository(
      AppDatabase(NativeDatabase.memory()),
      now: () => now,
    );
    final app = AppController(repo);
    await tester.runAsync(app.initialize);
    expect(
      app.progress.xp,
      0,
      reason: 'Use a disposable fresh QA emulator only',
    );
    await tester.runAsync(
      () => app.saveAudio(
        const AudioPreferences(speech: false, effects: false, reactions: true),
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: RepaintBoundary(key: boundary, child: const OrbitApp()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      for (final name in [
        'orbi_thinking',
        'orbi_happy',
        'orbi_wink_thumbsup',
        'orbi_logo',
        'explorer_closed',
        'explorer_open',
        'pixie',
      ]) {
        await precacheImage(
          AssetImage('assets/kvesmos/$name.png'),
          boundary.currentContext!,
        );
      }
    });
    await film(12);
    await film(10);
    Future<void> tap(Finder finder) async {
      if (finder.evaluate().isEmpty ||
          finder.hitTestable().evaluate().isEmpty) {
        await tester.scrollUntilVisible(
          finder,
          180,
          maxScrolls: 35,
          scrollable: find.byType(Scrollable).first,
        );
      }
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await film();
      for (
        var i = 0;
        i < 30 && find.text('Сохраняем…').evaluate().isNotEmpty;
        i++
      ) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 120)),
        );
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 120)),
      );
    }

    for (var i = 0; i < 3; i++) {
      await tap(find.text('Продолжить'));
    }
    await tap(find.text('Начать путешествие'));
    await film(15);
    await tap(find.text('Карта путешествия'));
    await film(12);
    await tap(find.byKey(const Key('map-lesson-a1-01')));
    for (
      var i = 0;
      i < 10 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
      i++
    ) {
      await tap(find.byKey(const Key('teaching-next')));
    }
    final material = (await tester.runAsync(() => repo.startLesson('a1-01')))!;
    for (final e in material.lesson.exercises) {
      debugPrint('ALIVE_STEP ${e.id}');
      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      list.position.jumpTo(0);
      await tester.pumpAndSettle();
      if (e == material.lesson.exercises.first) {
        await tap(
          find.widgetWithText(
            OutlinedButton,
            e.options.firstWhere((v) => !e.answers.contains(v)),
          ),
        );
        await tap(find.text('Проверить'));
        expect(find.text('Почти! Я помогу.'), findsOneWidget);
        await film(10);
        await tap(find.text('Попробовать снова'));
      }
      if (e.options.isNotEmpty) {
        await tap(find.widgetWithText(OutlinedButton, e.answers.first));
      } else if (e.type == ExerciseType.order) {
        for (final token in e.tokens) {
          await tap(find.widgetWithText(ActionChip, token));
        }
      } else if (e.type == ExerciseType.pairs) {
        for (final pair in e.pairs) {
          await tap(find.widgetWithText(OutlinedButton, pair.en));
          await tap(find.widgetWithText(OutlinedButton, pair.ru));
        }
      } else {
        await tester.scrollUntilVisible(
          find.byType(TextField),
          180,
          maxScrolls: 35,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.enterText(find.byType(TextField), e.answers.first);
        await tester.pumpAndSettle();
      }
      await tap(find.text('Проверить'));
      await tap(find.text('Дальше'));
      if (find.byKey(const Key('checkpoint-continue')).evaluate().isNotEmpty) {
        await film(12);
        await tap(find.byKey(const Key('checkpoint-continue')));
      }
    }
    expect(app.progress.xp, 120);
    expect(app.progress.errors, 1);
    expect(app.inventory.grants.length, 3);
    expect(find.text('Ещё одно открытие!'), findsOneWidget);
    await film(15);
    await tap(find.text('Открыть находки'));
    await tap(find.text('Открыть сундук').first);
    await tap(find.text('Открыть').first);
    await film(15);
    expect(tester.takeException(), isNull);
    debugPrint('ALIVE_RECORD_DONE');
    await tap(find.text('Забрать'));
    // A second recording advances only this isolated repository's clock.
    now = now.add(const Duration(days: 1));
    await tester.runAsync(app.refresh);
    frame = 0;
    frameDirectory = 'test-output/v07/day-two-frames';
    await tester.runAsync(
      () => Directory(frameDirectory).create(recursive: true),
    );
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/');
    await tester.pumpAndSettle();
    await film(20);
    GoRouter.of(tester.element(find.byType(Scaffold).first)).go('/practice');
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await film(20);
    final picks = List<String>.from(
      jsonDecode(
        (await tester.runAsync(
          () async => (await repo.setting('kvesmos.practice.v1'))!,
        ))!,
      )['words'],
    );
    for (final id in picks) {
      await tap(find.text('Скрыть и вспомнить'));
      await tester.enterText(find.byType(TextField), repo.vocabulary[id]!.en);
      await film(10);
      await tap(find.text('Проверить'));
      await film(10);
      await tap(find.text('Следующее слово'));
    }
    await film(20);
    expect(find.text('Слова снова на связи!'), findsOneWidget);
    debugPrint('DAY_TWO_RECORD_DONE');
    await tester.runAsync(app.refresh);
    final count = app.inventory.grants.length;
    await tester.runAsync(app.refresh);
    expect(app.inventory.grants.length, count);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(repo.db.close);
  }, skip: Platform.environment['CAPTURE_DEMO'] != '1');
}
