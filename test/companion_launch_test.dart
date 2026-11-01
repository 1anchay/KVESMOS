import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/ui/app.dart';
import 'package:orbitwords/ui/lesson_screen.dart';
import 'support.dart';
import 'widget_test.dart' show flushDb;

void main() {
  setUpAll(setupSqlite);
  for (final onboarded in [true, false]) {
    testWidgets(
      'companion cold/warm launch preserves course, onboarded=$onboarded',
      (tester) async {
        final app = AppController(memoryRepository());
        await tester.runAsync(() async {
          await app.initialize();
          if (onboarded) await app.finishOnboarding();
        });
        app.companion.launchCourse.value = 'ru-es';
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appProvider.overrideWith((_) => app)],
            child: const OrbitApp(),
          ),
        );
        await flushDb(tester);
        if (!onboarded) {
          expect(app.course.id, 'ru-en');
          expect(find.byType(LessonScreen), findsNothing);
          await tester.runAsync(app.finishOnboarding);
          await flushDb(tester);
        }
        expect(app.course.id, 'ru-es');
        expect(
          tester.widget<LessonScreen>(find.byType(LessonScreen)).lessonId,
          'es-a1-01',
        );
        app.companion.launchCourse.value = 'ru-de';
        await flushDb(tester);
        expect(app.course.id, 'ru-de');
        expect(
          tester.widget<LessonScreen>(find.byType(LessonScreen)).lessonId,
          'de-a1-01',
        );
        expect(app.globalProgress.xp, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(app.repository.db.close);
      },
    );
  }
}
