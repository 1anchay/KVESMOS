import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/open.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';
import 'package:orbitwords/ui/lesson_introduction.dart';
import 'package:orbitwords/ui/galaxy_components.dart';

/// Perform the ungraded actions through the same controls as a learner.
Future<void> advanceTeaching(WidgetTester tester) async {
  for (var step = 0; step < 40; step++) {
    if (find.byType(LessonIntroduction).evaluate().isEmpty) return;
    await tester.pumpAndSettle();
    final intro = tester.widget<LessonIntroduction>(
      find.byType(LessonIntroduction),
    );
    final next = find.byKey(const Key('teaching-next'));
    final button = tester.widget<FilledButton>(next);
    if (find
        .descendant(of: next, matching: find.text('Проверить'))
        .evaluate()
        .isNotEmpty) {
      final activity = intro.lesson.guidedIntroduction.firstWhere(
        (a) => find.text(a.phrase).evaluate().isNotEmpty,
      );
      if (activity.tokens.isEmpty) {
        final index = activity.options.indexOf(activity.answer);
        final option = find.byKey(ValueKey('intro-option-$index'));
        if (tester.widget<AnswerTile>(option).selected) {
          await tester.tap(next);
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 60)),
          );
          await tester.pumpAndSettle();
          continue;
        }
        await tester.ensureVisible(option);
        await tester.pumpAndSettle();
        await tester.tap(option);
      } else {
        var added = false;
        for (var i = 0; i < activity.tokens.length; i++) {
          final token = find.byKey(ValueKey('intro-token-$i'));
          if (tester.widget<ActionChip>(token).onPressed == null) continue;
          await tester.ensureVisible(token);
          await tester.pumpAndSettle();
          await tester.tap(token);
          added = true;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)),
          );
          await tester.pumpAndSettle();
        }
        if (!added) await tester.tap(next);
      }
    } else if (button.onPressed != null) {
      await tester.tap(next);
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 60)),
    );
    await tester.pumpAndSettle();
  }
  fail('Interactive introduction never completed');
}

void setupSqlite() {
  // Tests intentionally create isolated executors to model different devices.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final path = Platform.environment['SQLITE_TEST_DLL'];
  if (Platform.isWindows && path != null) {
    open.overrideFor(OperatingSystem.windows, () => DynamicLibrary.open(path));
  }
}

LearningRepository memoryRepository({DateTime Function()? now}) =>
    LearningRepository(
      AppDatabase(NativeDatabase.memory()),
      now: now,
      loadAsset: (path) => File(path).readAsString(),
    );

/// Locate the Flutter SDK font on developer machines and GitHub Actions.
String materialIconsFontPath() {
  final sdkRoot = Platform.environment['FLUTTER_ROOT'];
  const fontNames = ['MaterialIcons-Regular.otf', 'materialicons-regular.otf'];
  final roots = [
    if (sdkRoot != null && sdkRoot.isNotEmpty) sdkRoot,
    '.tools/flutter',
  ];
  final paths = [
    for (final root in roots)
      for (final name in fontNames)
        '$root/bin/cache/artifacts/material_fonts/$name',
  ];
  for (final path in paths) {
    if (File(path).existsSync()) return path;
  }
  throw StateError(
    'Material Icons font not found. Checked: ${paths.join(", ")}',
  );
}
