import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/audio_settings.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

Future<void> loadPreviewFonts() async {
  for (final family in ['OrbitSans', 'Roboto', 'Ahem']) {
    final loader = FontLoader(family)
      ..addFont(
        Future.value(
          ByteData.sublistView(
            await File('assets/fonts/roboto-regular.ttf').readAsBytes(),
          ),
        ),
      );
    await loader.load();
  }
  final icons = FontLoader('MaterialIcons')
    ..addFont(
      Future.value(
        ByteData.sublistView(
          await File(
            materialIconsFontPath(),
          ).readAsBytes(),
        ),
      ),
    );
  await icons.load();
}

Future<void> capturePreview(GlobalKey key, String name) async {
  if (Platform.environment['CAPTURE_UI'] != '1') return;
  final render =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await render.toImage(pixelRatio: 2);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  await File('test-output/$name.png').writeAsBytes(data!.buffer.asUint8List());
  image.dispose();
}

void main() {
  setUpAll(setupSqlite);
  testWidgets('audio switches save to SQLite and show unavailable voices', (
    tester,
  ) async {
    final r = memoryRepository();
    final app = AppController(r);
    final boundary = GlobalKey();
    await tester.runAsync(() async {
      await app.initialize();
      await loadPreviewFonts();
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appProvider.overrideWith((_) => app)],
        child: RepaintBoundary(
          key: boundary,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: orbitTheme(Brightness.light),
            home: Scaffold(body: ListView(children: const [AudioSettings()])),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.runAsync(() => capturePreview(boundary, 'kvesmos-040-audio'));
    await tester.tap(find.text('Озвучка'));
    await flushDb(tester);
    expect(app.audio.preferences.speech, false);
    await tester.scrollUntilVisible(find.text('Звуковые эффекты'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Звуковые эффекты'));
    await flushDb(tester);
    expect(app.audio.preferences.effects, false);
    await tester.scrollUntilVisible(find.text('Реакции команды в уроках'), 200);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Реакции команды в уроках'));
    await flushDb(tester);
    expect(app.audio.preferences.reactions, false);
    final raw = await tester.runAsync(
      () => r.setting(LearningAudio.preferencesKey),
    );
    expect(AudioPreferences.decode(raw).speech, false);
    expect(AudioPreferences.decode(raw).effects, false);
    expect(AudioPreferences.decode(raw).reactions, false);
    await tester.scrollUntilVisible(
      find.text('Проверить голоса устройства'),
      200,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Проверить голоса устройства'));
    await flushDb(tester);
    expect(app.audio.voices.scanned, true);
    expect(app.audio.voices.available, isEmpty);
    await tester.scrollUntilVisible(
      find.text('Нет подходящего голоса — доступен текст.').first,
      200,
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(app.progress.xp, 0);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.runAsync(r.db.close);
  });
  testWidgets(
    'pilot picture and listening controls render without engine or new artwork',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final config in [
        ('a1-03', 0, 'kvesmos-040-picture'),
        ('a1-01', 2, 'kvesmos-040-listening'),
      ]) {
        final r = memoryRepository();
        final app = AppController(r);
        final boundary = GlobalKey();
        await tester.runAsync(() async {
          await app.initialize();
          await loadPreviewFonts();
          await r.append(
            r.event('complete', {'lesson': 'a1-02', 'session': 'seed'}),
          );
          await app.refresh();
          final material = await r.startLesson(config.$1, demo: true);
          for (var i = 0; i < config.$2; i++) {
            final e = material.lesson.exercises[i];
            await r.answer(
              material.session.id,
              i,
              e,
              e.answers.first,
              total: 10,
            );
          }
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: RepaintBoundary(
              key: boundary,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: orbitTheme(Brightness.light),
                home: LessonScreen(lessonId: config.$1),
              ),
            ),
          ),
        );
        await flushDb(tester);
        await advanceTeaching(tester);
        await flushDb(tester);
        await tester.runAsync(() async {
          final context = tester.element(find.byType(LessonScreen));
          for (final path in [
            'assets/kvesmos/orbi_thinking.png',
            'assets/kvesmos/aster.png',
          ]) {
            await precacheImage(AssetImage(path), context);
          }
        });
        await tester.pumpAndSettle();
        await tester.runAsync(() => capturePreview(boundary, config.$3));
        expect(find.text('Новый формат'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      }
    },
  );
}
