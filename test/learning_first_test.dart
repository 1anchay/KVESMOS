import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/adventures_repository.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/domain/space_adventures.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/space_adventure_node.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

Future<String> learningState(LearningRepository repo) async => jsonEncode({
  'events': (await repo.allEvents()).map((e) => e.toJson()).toList(),
  'inventory': await repo.setting('kvesmos.inventory.v1'),
  'adventures': [
    for (final a in SpaceAdventure.all)
      (await AdventuresRepository(repo).read(a.id)).encode(),
  ],
});

void main() {
  setUpAll(setupSqlite);
  test(
    'upgrade defaults hidden; toggles survive restart and preserve all game/learning data',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      var app = AppController(repo);
      await app.initialize();
      final draft = await repo.startLesson('a1-01');
      await repo.draft(draft.session.id, 0, '{"text":"Hello!"}');
      await repo.setSetting(
        'kvesmos.adventure.v1:beacon',
        AdventureState(
          step: 1,
          revision: 4,
          x: .31,
          y: .62,
          hint: true,
        ).encode(),
      );
      final before = await learningState(repo);
      expect(app.showMiniAdventures, false);
      expect(await app.learningContinuationRoute(), '/lesson/a1-01');
      await app.saveAdventureVisibility(true);
      app.dispose();
      app = AppController(repo);
      await app.initialize();
      expect(app.showMiniAdventures, true);
      await app.saveAdventureVisibility(false);
      app.dispose();
      app = AppController(repo);
      await app.initialize();
      expect(app.showMiniAdventures, false);
      expect(await learningState(repo), before);
      expect((await repo.session(draft.session.id)).draft, '{"text":"Hello!"}');
      app.dispose();
    },
  );

  test(
    'continuation ignores locked/retired drafts; offline and finished routes are safe',
    () async {
      final repo = memoryRepository();
      final subject = AppController(repo);
      addTearDown(() async {
        subject.dispose();
        await repo.db.close();
      });
      await subject.initialize();
      await repo.start('a1-20');
      final old = await repo.startLesson('a1-01');
      await repo.setSetting(
        'kvesmos.session.retired.v1:${old.session.id}',
        'true',
      );
      expect(await subject.learningContinuationRoute(), '/lesson/a1-01');
      await repo.uninstall('a1-01');
      await subject.refresh();
      expect(await subject.learningContinuationRoute(), '/offline');
      for (final lesson in repo.catalog) {
        await repo.append(
          repo.event('complete', {
            'session': 'fixture:${lesson.id}',
            'lesson': lesson.id,
          }),
        );
      }
      await subject.refresh();
      expect(await subject.learningContinuationRoute(), '/lesson/a1-20');
      await repo.setSetting(
        'kvesmos.session.retired.v1:${(await repo.start('a1-20')).id}',
        'true',
      );
      expect(await subject.learningContinuationRoute(), '/map');
    },
  );

  test(
    'preview is read only and uses pinned or legacy material of the existing draft',
    () async {
      final repo = memoryRepository();
      addTearDown(repo.db.close);
      await repo.initialize();
      final before = await learningState(repo);
      final first = await repo.previewLesson('a1-01');
      expect(first.session, isNull);
      expect(await repo.db.select(repo.db.sessions).get(), isEmpty);
      expect(await learningState(repo), before);
      final active = await repo.startLesson('a1-01');
      await repo.draft(active.session.id, 0, 'keep selection');
      final preview = await repo.previewLesson('a1-01');
      expect(preview.session!.id, active.session.id);
      expect(
        preview.lesson.exercises.map((e) => e.id),
        active.lesson.exercises.map((e) => e.id),
      );
      expect(preview.session!.draft, 'keep selection');
      final legacy = await repo.start('a1-02');
      final original = await repo.lesson('a1-02');
      final legacyPreview = await repo.previewLesson('a1-02');
      expect(legacyPreview.session!.id, legacy.id);
      expect(
        legacyPreview.lesson.exercises.first.id,
        original.exercises.first.id,
      );
      expect((await repo.db.select(repo.db.sessions).get()).length, 2);
    },
  );

  for (final completed in [false, true]) {
    testWidgets(
      'all three skips preserve ${completed ? "completed" : "unfinished"} games, XP and ordinary draft',
      (tester) async {
        final repo = memoryRepository(), boundary = GlobalKey();
        final app = AppController(repo), games = AdventuresRepository(repo);
        late String before, draftId;
        await tester.runAsync(() async {
          await app.initialize();
          await app.finishOnboarding();
          for (var n = 1; n <= 5; n++) {
            await repo.append(
              repo.event('complete', {
                'session': 'fixture$n',
                'lesson': 'a1-0$n',
              }),
            );
          }
          for (final a in SpaceAdventure.all) {
            var state = await games.read(a.id);
            for (final step in completed ? a.steps : a.steps.take(1)) {
              state = await games.act(
                a,
                state.revision,
                'move',
                value: step.target,
              );
              if (step.action == AdventureAction.assemble) {
                for (final tile in step.answer.split(' ')) {
                  state = await games.act(
                    a,
                    state.revision,
                    'tile',
                    value: tile,
                  );
                }
              }
              state = await games.act(
                a,
                state.revision,
                'submit',
                value: step.answer,
              );
            }
            expect(state.completed, completed);
          }
          final draft = await repo.startLesson('a1-06');
          draftId = draft.session.id;
          await repo.markTeachingSeen(draftId);
          await repo.draft(
            draftId,
            0,
            '{"text":"saved choice","order":[],"pairs":{}}',
          );
          await app.refresh();
          before = await learningState(repo);
        });
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: RepaintBoundary(key: boundary, child: const OrbitApp()),
          ),
        );
        await flushDb(tester);
        final router = GoRouter.of(tester.element(find.byType(OrbitShell)));
        router.go('/map');
        await flushDb(tester);
        expect(find.byType(SpaceAdventureNode), findsNothing);
        for (final a in SpaceAdventure.all) {
          router.go('/adventure/${a.id}');
          await flushDb(tester);
          await tester.tap(find.byKey(const Key('skip-adventure')));
          await flushDb(tester);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/lesson/a1-06',
          );
          expect(await tester.runAsync(() => learningState(repo)), before);
          expect(
            (await tester.runAsync(() => repo.session(draftId)))!.draft,
            '{"text":"saved choice","order":[],"pairs":{}}',
          );
          router.go('/adventures');
          await flushDb(tester);
          final node = find.ancestor(
            of: find.byKey(ValueKey('adventure-${a.id}')),
            matching: find.byType(SpaceAdventureNode),
          );
          final skip = find.descendant(
            of: node,
            matching: find.byKey(const Key('skip-adventure')),
          );
          await tester.scrollUntilVisible(
            skip,
            220,
            maxScrolls: 30,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(skip);
          await tester.pumpAndSettle();
          await tester.tap(skip);
          await flushDb(tester);
          expect(
            router.routeInformationProvider.value.uri.path,
            '/lesson/a1-06',
          );
          expect(await tester.runAsync(() => learningState(repo)), before);
        }
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(repo.db.close);
      },
    );
  }
}
