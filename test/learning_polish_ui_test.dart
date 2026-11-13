import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/picture_repository.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/activity_calendar.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/picture_art.dart';
import 'package:orbitwords/ui/picture_recall.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.hitTestable().evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      170,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(setupSqlite);
  for (final (index, course) in StudyCourse.all.indexed) {
    testWidgets(
      '${course.id}: illustrated recall works with text at 320dp / 200%',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final r = memoryRepository(), app = AppController(r);
        late PictureWord word;
        await tester.runAsync(() async {
          await app.initialize();
          await app.selectCourse(course.id);
          await app.saveAudio(
            const AudioPreferences(
              speech: false,
              effects: false,
              reactions: false,
            ),
          );
          final pictures = PictureRepository(r), cards = await pictures.cards;
          final book = cards['book']!;
          await r.append(
            r.event('complete', {
              'lesson': book.prerequisite,
              'session': 'seed-book',
            }),
          );
          await app.refresh();
          word = cards[((await pictures.open())['ids'] as List).first]!;
        });
        final xp = app.progress.xp;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              theme: orbitTheme(
                index.isEven ? Brightness.dark : Brightness.light,
              ),
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: const PictureRecallPage(),
              ),
            ),
          ),
        );
        await flushDb(tester);
        expect(find.byType(PictureArt), findsOneWidget);
        expect(find.text(word.forms.first), findsNothing);
        final input = find.byKey(const Key('picture-input'));
        await reveal(tester, input);
        await tester.enterText(
          input,
          word.pinyin.firstOrNull ?? word.bare(word.forms.first),
        );
        await flushDb(tester);
        FocusManager.instance.primaryFocus?.unfocus();
        final check = find.byKey(const Key('picture-next'));
        await reveal(tester, check);
        await tester.tap(check);
        await flushDb(tester);
        await reveal(tester, find.text(word.forms.join(' / ')));
        expect(find.text('Вспомнил!'), findsOneWidget);
        if (course.language == 'zh') {
          expect(find.text(word.pinyin.join(' / ')), findsOneWidget);
        }
        expect(app.progress.xp, xp);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(r.db.close);
      },
    );
  }

  testWidgets(
    'onboarding can skip diagnostics and calendar has accessible day controls',
    (tester) async {
      final r = memoryRepository(now: () => DateTime(2026, 11, 12)),
          app = AppController(r);
      await tester.runAsync(app.initialize);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appProvider.overrideWith((_) => app)],
          child: const OrbitApp(),
        ),
      );
      await flushDb(tester);
      final router = GoRouter.of(tester.element(find.byType(Scaffold).first));
      router.go('/level');
      await tester.pumpAndSettle();
      final diagnostic = find.text('Проверить мои знания');
      await reveal(tester, diagnostic);
      await tester.tap(diagnostic);
      await flushDb(tester);
      final option = find.text('Не знаю');
      await reveal(tester, option);
      await tester.tap(option);
      await flushDb(tester);
      expect(find.text('Задание 2'), findsOneWidget);
      expect(find.textContaining('Ответ не сохранён'), findsNothing);
      final skip = find.text('Пропустить диагностику');
      await reveal(tester, skip);
      await tester.tap(skip);
      await flushDb(tester);
      expect(find.text('Небольшая цель. Большие открытия.'), findsOneWidget);
      expect(app.progress.xp, 0);
      router.go('/stats');
      await flushDb(tester);
      await reveal(tester, find.byType(ActivityCalendar));
      final today = find.byKey(const ValueKey('activity:2026-11-12'));
      await reveal(tester, today);
      await tester.tap(today);
      await tester.pumpAndSettle();
      expect(find.textContaining('уроков: 0'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(r.db.close);
    },
  );
}
