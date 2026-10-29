import 'dart:ui' show FrameTiming;
import 'dart:convert';
import 'dart:io';
import 'package:orbitwords/data/adventures_repository.dart';
import 'package:go_router/go_router.dart';
import '../test/rewards_fixture.dart';
// Disposable QA emulator ONLY. Flutter's runner may clear its target package.
// Back up the QA app before running; restore the production APK and backup after.
import 'package:flutter/material.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';

Future<void> marker(String value) async {
  debugPrint(value);
  await Process.run('/system/bin/log', ['-t', 'KVESMOS_QA', value]);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('first minute, real lesson, daily rewards and next step', (
    tester,
  ) async {
    // Isolated fixture; never clear or modify the installed user's database.
    final repo = LearningRepository(AppDatabase(NativeDatabase.memory()));
    final app = AppController(repo, rewardRandom: RareFrameRandom());
    await app.initialize();
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> batch) => timings.addAll(batch);
    WidgetsBinding.instance.addTimingsCallback(collect);
    expect(
      app.progress.xp,
      0,
      reason: 'Use a disposable fresh QA emulator only',
    );
    await app.saveAudio(
      const AudioPreferences(speech: true, effects: true, reactions: true),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: const OrbitApp(),
      ),
    );
    await tester.pumpAndSettle();
    await marker('V010_LESSON_START');
    await Future<void>.delayed(const Duration(seconds: 3));
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
      await tester.pumpAndSettle();
      for (
        var i = 0;
        i < 30 && find.text('Сохраняем…').evaluate().isNotEmpty;
        i++
      ) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
        await tester.pumpAndSettle();
      }
      await Future<void>.delayed(const Duration(milliseconds: 80));
    }

    for (var i = 0; i < 3; i++) {
      await tap(find.text('Продолжить'));
    }
    await tap(find.text('Начать путешествие'));
    await Future<void>.delayed(const Duration(seconds: 2));
    await tap(find.byKey(const Key('today-start')));
    await tap(find.text('Послушать пример'));
    expect(app.audio.lastSource, SpeechSource.recording);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    await tap(find.text('Медленнее'));
    expect(app.audio.lastSource, SpeechSource.recording);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    for (
      var i = 0;
      i < 10 && find.byType(LessonIntroduction).evaluate().isNotEmpty;
      i++
    ) {
      await tap(find.byKey(const Key('teaching-next')));
    }
    final material = await repo.startLesson('a1-01');
    for (final e in material.lesson.exercises) {
      debugPrint('ALIVE_STEP ${e.id}');
      final list = tester.state<ScrollableState>(find.byType(Scrollable).first);
      list.position.jumpTo(0);
      await tester.pumpAndSettle();
      if (e == material.lesson.exercises.first) {
        await tap(find.text('Нужна подсказка?'));
        expect(find.text(e.hint!), findsOneWidget);
        await tap(find.text('Нужна подсказка?'));
        await tap(
          find.widgetWithText(
            OutlinedButton,
            e.options.firstWhere((v) => !e.answers.contains(v)),
          ),
        );
        await tap(find.text('Проверить'));
        expect(find.text('Почти! Я помогу.'), findsOneWidget);
        await Future<void>.delayed(const Duration(seconds: 1));
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
        await tap(find.byKey(const Key('checkpoint-continue')));
      }
    }
    expect(app.progress.xp, 120);
    expect(app.progress.errors, 1);
    expect(app.inventory.grants.length, 3);
    expect(find.text('Ещё одно открытие!'), findsOneWidget);
    await Future<void>.delayed(const Duration(seconds: 2));
    await tap(find.text('Открыть находки'));
    await tap(find.text('Открыть сундук').first);
    await tap(find.text('Открыть').first);
    await Future<void>.delayed(const Duration(seconds: 1));
    WidgetsBinding.instance.removeTimingsCallback(collect);
    Map<String, dynamic> distribution(List<double> values) {
      values.sort();
      return {
        'frames': values.length,
        'medianMs': values[values.length ~/ 2],
        'p95Ms': values[((values.length - 1) * .95).round()],
        'over16_7ms': values.where((v) => v > 16.7).length,
      };
    }

    expect(timings, isNotEmpty);
    debugPrint(
      'KVESMOS_FRAME_TIMINGS ${jsonEncode({'mode': 'debug x64 emulator; engine FrameTiming, not video FPS', 'build': distribution(timings.map((t) => t.buildDuration.inMicroseconds / 1000).toList()), 'raster': distribution(timings.map((t) => t.rasterDuration.inMicroseconds / 1000).toList())})}',
    );
    await Future<void>.delayed(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(app.inventory.owned, hasLength(1));
    final item = app.rewards.catalog.item(app.inventory.owned.single);
    expect(item.rarity, 'rare');
    await tap(find.text('Примерить находку'));
    await tap(find.byKey(const ValueKey('apply-cosmetic')));
    expect(app.inventory.equipped[item.slot], item.id);
    await tap(find.text('Посмотреть профиль'));
    await tap(find.text('Вся коллекция'));
    expect(find.text('Первый контакт'), findsOneWidget);
    GoRouter.of(tester.element(find.byType(OrbitShell))).go('/map');
    await tester.pumpAndSettle();
    expect(app.progress.xp, 120);
    for (final effect in [
      SoundEffect.equip,
      SoundEffect.epic,
      SoundEffect.legendary,
    ]) {
      await Future<void>.delayed(const Duration(milliseconds: 900));
      expect(
        await app.audio.play(effect),
        isTrue,
        reason: 'Native ${effect.name} effect',
      );
    }
    await marker('V010_LESSON_DONE');
    await Future<void>.delayed(const Duration(seconds: 3));
    await marker('V010_SKIP_START');
    await Future<void>.delayed(const Duration(seconds: 3));
    final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
    router.go('/adventures');
    await tester.pumpAndSettle();
    await tap(find.byKey(const Key('show-adventures')));
    expect(app.showMiniAdventures, true);
    router.go('/map');
    await tester.pumpAndSettle();
    await tap(find.byKey(const Key('adventure-beacon')));
    await tap(find.byKey(const Key('approach')));
    await tap(find.byKey(const Key('adventure-submit')));
    final games = AdventuresRepository(repo);
    final beforeSkip = (await games.read('beacon')).encode();
    final eventsBefore = (await repo.allEvents()).length;
    await tap(find.byKey(const Key('skip-adventure')));
    expect(router.routeInformationProvider.value.uri.path, '/lesson/a1-02');
    expect((await games.read('beacon')).encode(), beforeSkip);
    expect((await repo.allEvents()).length, eventsBefore);
    expect(app.progress.xp, 120);
    router.go('/adventures');
    await tester.pumpAndSettle();
    await tap(find.byKey(const Key('show-adventures')));
    expect(app.showMiniAdventures, false);
    router.go('/map');
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('adventure-beacon')), findsNothing);
    router.go('/adventures');
    await tester.pumpAndSettle();
    await tap(find.byKey(const Key('adventure-beacon')));
    expect((await games.read('beacon')).encode(), beforeSkip);
    await tap(find.byKey(const Key('skip-adventure')));
    expect(router.routeInformationProvider.value.uri.path, '/lesson/a1-02');
    await marker('V010_SKIP_DONE');
    await Future<void>.delayed(const Duration(seconds: 3));
    await app.refresh();
    final count = app.inventory.grants.length;
    await app.refresh();
    expect(app.inventory.grants.length, count);
    await tester.pumpWidget(const SizedBox.shrink());
    await repo.db.close();
  });
}
