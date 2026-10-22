// Destructive to this app's test data. Run only on a dedicated test device.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbitwords/main.dart' as entry;
import 'package:orbitwords/core/controller.dart';
import 'package:orbitwords/domain/course.dart';
import 'package:orbitwords/ui/app.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'real Android SQLite: full lesson, all ten exercise types, navigation',
    (tester) async {
      await entry.main();
      await tester.pumpAndSettle();
      final app = ProviderScope.containerOf(
        tester.element(find.byType(OrbitApp)),
      ).read(appProvider);
      await app.repository.reset();
      await app.initializeAfterReset();
      await app.finishOnboarding();
      final context = tester.element(find.byType(Scaffold).first);
      final router = GoRouter.of(context);
      router.go('/lesson/a1-01');
      await tester.pumpAndSettle();
      Future<void> tapVisible(Finder finder) async {
        await tester.scrollUntilVisible(
          finder,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(finder);
        await tester.pumpAndSettle();
      }

      final lesson = await app.repository.lesson('a1-01');
      for (final e in lesson.exercises) {
        await tester.pumpAndSettle();
        if (e.options.isNotEmpty) {
          await tapVisible(
            find.widgetWithText(OutlinedButton, e.answers.first),
          );
        } else if (e.type == ExerciseType.order) {
          for (final token in e.tokens) {
            await tapVisible(find.widgetWithText(ActionChip, token).first);
          }
        } else if (e.type == ExerciseType.pairs) {
          for (final word in e.pairs) {
            await tapVisible(find.widgetWithText(OutlinedButton, word.en));
            await tapVisible(find.widgetWithText(OutlinedButton, word.ru));
          }
        } else {
          await tester.scrollUntilVisible(
            find.byType(TextField),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.enterText(find.byType(TextField), e.answers.first);
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
        }
        await tapVisible(find.widgetWithText(FilledButton, 'Проверить'));
        expect(
          find.text('Сигнал принят! +10 XP'),
          findsOneWidget,
          reason: e.type.name,
        );
        await tapVisible(find.widgetWithText(FilledButton, 'Дальше'));
      }
      expect(find.text('Новая орбита освоена!'), findsOneWidget);
      expect(app.progress.xp, 120);
      expect(app.progress.completed, contains('a1-01'));
      final progress = await app.repository.progress();
      expect(progress.xp, 120);
      router.go('/words');
      await tester.pumpAndSettle();
      expect(find.text('hello'), findsOneWidget);
      router.go('/stats');
      await tester.pumpAndSettle();
      expect(find.text('120'), findsOneWidget);
      router.go('/');
      await tester.pumpAndSettle();
      expect(find.text('Продолжить урок'), findsOneWidget);
    },
  );
}
