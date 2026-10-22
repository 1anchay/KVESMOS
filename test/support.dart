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

/// Advance each teaching card through the same buttons a student uses.
Future<void> advanceTeaching(WidgetTester tester) async {
  for (var step = 0; step < 12; step++) {
    if (find.byType(LessonIntroduction).evaluate().isEmpty) return;
    final next = find.text('Понятно, дальше');
    final target =
        next.evaluate().isNotEmpty ? next : find.text('Начать практику');
    expect(target, findsOneWidget);
    await tester.scrollUntilVisible(
      target,
      200,
      scrollable: find.descendant(
        of: find.byType(LessonIntroduction),
        matching: find.byType(Scrollable),
      ).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 120)),
    );
    await tester.pumpAndSettle();
  }
  fail('Teaching introduction never completed');
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
  const fontNames = [
    'MaterialIcons-Regular.otf',
    'materialicons-regular.otf',
  ];
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
