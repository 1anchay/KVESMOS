import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/knowledge_repository.dart';
import 'package:orbitwords/data/story_repository.dart';
import 'package:orbitwords/domain/flight_story.dart';
import 'package:orbitwords/domain/story_dialogue.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/flight_ui.dart';
import 'package:orbitwords/ui/knowledge_widgets.dart';
import 'package:orbitwords/ui/story_dialogue_sheet.dart';

import 'support.dart';

class _PreviewRepository extends StoryRepository {
  _PreviewRepository(super.learning, this.cursor, this.variant);
  final String cursor;
  final int variant;
  final moves = <StoryMove>[];

  @override
  Future<StoryView> open(StoryScene scene) async => (
    save: StorySave(),
    run: StoryRun([cursor])..variant = variant,
    verdict: null,
  );

  @override
  Future<StoryView> move(
    StoryScene scene,
    int revision,
    StoryMove move, [
    Object? input,
  ]) async {
    moves.add(move);
    return open(scene);
  }
}

class _QuietLanguage extends LanguageContext {
  _QuietLanguage(super.repository, super.audio);
  @override
  Future<void> refresh() async {}
}

void main() {
  setUpAll(setupSqlite);

  for (final brightness in Brightness.values) {
    for (final width in [320.0, 360.0, 390.0, 430.0]) {
      for (final scale in [1.0, 1.5, 2.0]) {
        testWidgets(
          '$brightness · ${width.toInt()}dp · ${scale * 100}% · five formats',
          (tester) async {
            tester.view.physicalSize = Size(width, 740);
            tester.view.devicePixelRatio = 1;
            tester.platformDispatcher.textScaleFactorTestValue = scale;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            addTearDown(
              tester.platformDispatcher.clearTextScaleFactorTestValue,
            );
            final learning = memoryRepository();
            final app = AppController(learning);
            final language = _QuietLanguage(
              KnowledgeRepository(learning),
              app.audio,
            );
            const fixtures = [
              (FlightStory.repair, 'request', 0, StoryFormat.answer),
              (FlightStory.found, 'react', 0, StoryFormat.reaction),
              (FlightStory.repair, 'cable', 0, StoryFormat.order),
              (FlightStory.power, 'ready', 0, StoryFormat.word),
              (FlightStory.debrief, 'message', 2, StoryFormat.phrase),
            ];
            for (final (scene, cursor, variant, format) in fixtures) {
              final repository = _PreviewRepository(learning, cursor, variant);
              await tester.pumpWidget(
                ProviderScope(
                  overrides: [appProvider.overrideWith((_) => app)],
                  child: MaterialApp(
                    theme: orbitTheme(brightness),
                    home: Scaffold(
                      body: Align(
                        alignment: Alignment.bottomCenter,
                        child: StoryDialogueSheet(
                          key: ValueKey(cursor),
                          scene: scene,
                          repository: repository,
                          language: language,
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pumpAndSettle();
              expect(
                find.byKey(Key('story-task-${format.name}')),
                findsOneWidget,
              );
              final check = find.byKey(const Key('story-submit'));
              expect(check.hitTestable(), findsOneWidget);
              final footerY = tester.getTopLeft(check).dy;
              if (format != StoryFormat.order) {
                final option = find.byKey(const Key('story-option-1'));
                final scroller = find.descendant(
                  of: find.byKey(const Key('story-sheet')),
                  matching: find.byType(Scrollable),
                );
                await tester.scrollUntilVisible(
                  option,
                  115,
                  scrollable: scroller,
                );
                await tester.pumpAndSettle();
                await tester.tap(option);
                await tester.pumpAndSettle();
                expect(repository.moves, isEmpty);
                if (format == StoryFormat.word ||
                    format == StoryFormat.phrase) {
                  final gap = find.byKey(const Key('story-gap'));
                  await tester.scrollUntilVisible(
                    gap,
                    -95,
                    scrollable: scroller,
                  );
                  await tester.pumpAndSettle();
                  expect(
                    tester.widget<Text>(gap).textSpan!.toPlainText(),
                    isNot(contains('_____')),
                  );
                }
                expect(tester.getTopLeft(check).dy, footerY);
                expect(tester.widget<FlightControl>(check).onTap, isNotNull);
              }
              expect(
                tester.takeException(),
                isNull,
                reason: '$cursor / $scale / $width',
              );
            }
            await tester.pumpWidget(const SizedBox.shrink());
            language.dispose();
            await learning.db.close();
          },
        );
      }
    }
  }

  testWidgets(
    '48dp word tiles keep duplicate IDs and bank slots across return and theme',
    (tester) async {
      final semantics = tester.ensureSemantics();
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final selected = <int>[];
      const words = [
        'the',
        'the',
        'controls',
        'preflight instrumentation',
        'is',
      ];
      var brightness = Brightness.light;
      late StateSetter update;
      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return MaterialApp(
              theme: orbitTheme(brightness),
              home: Scaffold(
                body: MediaQuery(
                  data: const MediaQueryData(
                    size: Size(320, 740),
                    disableAnimations: true,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: StoryWordBoard(
                      tokens: words,
                      draft: selected,
                      seed: 'same-node',
                      onMove: (i) => setState(() {
                        if (!selected.remove(i)) selected.add(i);
                      }),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
      Offset bank(int id) =>
          tester.getTopLeft(find.byKey(ValueKey('story-bank-slot-$id')));
      final start = List.generate(words.length, bank);
      final token = find.byKey(const Key('story-token-0'));
      expect(tester.getSize(token).height, greaterThanOrEqualTo(48));
      expect(
        tester
            .getSemantics(token)
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      semantics.dispose();
      await tester.tap(token);
      await tester.pumpAndSettle();
      expect(bank(1), start[1]);
      expect(
        find.byKey(const Key('story-token-0')).hitTestable(),
        findsNothing,
      );
      await tester.tap(find.byKey(const Key('story-token-1')));
      await tester.pumpAndSettle();
      expect(selected, [0, 1]);
      update(() => brightness = Brightness.dark);
      await tester.pumpAndSettle();
      expect(List.generate(words.length, bank), start);
      await tester.tap(find.byKey(const Key('story-draft-token-0')));
      await tester.pumpAndSettle();
      expect(selected, [1]);
      expect(
        find.byKey(const Key('story-token-0')).hitTestable(),
        findsOneWidget,
      );
      expect(List.generate(words.length, bank), start);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'flight palettes meet contrast for body copy and meaningful controls',
    () {
      double ratio(Color a, Color b) {
        final values = [a.computeLuminance(), b.computeLuminance()]..sort();
        return (values.last + .05) / (values.first + .05);
      }

      for (final palette in [FlightPalette.light, FlightPalette.dark]) {
        for (final surface in [
          palette.background,
          palette.surface,
          palette.inset,
          palette.selected,
        ]) {
          for (final foreground in [
            palette.text,
            palette.secondary,
            palette.accent,
          ]) {
            expect(
              ratio(foreground, surface),
              greaterThanOrEqualTo(4.5),
              reason: '$foreground over $surface',
            );
          }
        }
        expect(
          ratio(palette.warning, palette.warningSurface),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          ratio(palette.onAccent, palette.accent),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          ratio(palette.control, palette.surface),
          greaterThanOrEqualTo(3),
        );
        expect(ratio(palette.control, palette.inset), greaterThanOrEqualTo(3));
      }
    },
  );
}
