import 'dart:ffi';
import 'dart:io';
import 'package:drift/native.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/open.dart';
import 'package:orbitwords/data/database.dart';
import 'package:orbitwords/data/repository.dart';

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
