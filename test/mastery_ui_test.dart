import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/data/mastery_repository.dart';
import 'package:orbitwords/domain/learning_unit.dart';
import 'package:orbitwords/domain/languages.dart';
import 'package:orbitwords/services/learning_audio.dart';
import 'package:orbitwords/ui/design.dart';
import 'package:orbitwords/ui/unit_mastery.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  for (final course in StudyCourse.all) {
    testWidgets(
      '${course.id}: mastery through UI, small screen, stamp without XP',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final r = memoryRepository(), app = AppController(r);
        late LearningUnit unit;
        late Map<String, dynamic> run;
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
          unit = LearningUnit.fromCatalog(r.catalog).first;
          for (final info in unit.lessons) {
            await r.append(
              r.event('complete', {
                'lesson': info.id,
                'session': 'seed:${info.id}',
              }),
            );
          }
          await app.refresh();
          run = await MasteryRepository(r, unit).open();
        });
        final xp = app.progress.xp;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: MaterialApp(
              theme: orbitTheme(Brightness.dark),
              home: MediaQuery(
                data: const MediaQueryData(
                  textScaler: TextScaler.linear(2),
                  disableAnimations: true,
                ),
                child: UnitMasteryPage(unitId: unit.id),
              ),
            ),
          ),
        );
        await flushDb(tester);
        for (final item in run['items'] as List) {
          final input = find.byKey(const Key('mastery-input'));
          await tester.scrollUntilVisible(
            input,
            180,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          await tester.enterText(
            input,
            item['pronunciation'] ?? item['phrase'],
          );
          await flushDb(tester);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          final next = find.byKey(const Key('mastery-next'));
          expect(next.hitTestable(), findsOneWidget);
          await tester.tap(next);
          await flushDb(tester);
          expect(find.text('Ты вспомнил!'), findsOneWidget);
          await tester.tap(next);
          await flushDb(tester);
        }
        expect(find.text('Созвездие собрано!'), findsOneWidget);
        expect(app.masteredUnits, contains(unit.id));
        expect(app.progress.xp, xp);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
        await tester.runAsync(r.db.close);
      },
    );
  }
}
