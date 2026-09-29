// Per-file database isolation.
//
// `flutter test` runs test files concurrently in separate isolates, but
// DatabaseHelper resolves a single fixed path from `getDatabasesPath()`. Two
// files touching the pantry tables at once therefore see each other's rows.
// Pointing each file at its own temp directory keeps the suites independent.

import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Initialises the FFI backend and gives this isolate a private database dir.
Future<void> initTestDatabase(String suiteName) async {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  final dir = await Directory.systemTemp.createTemp('pantrypal_$suiteName');
  await databaseFactory.setDatabasesPath(dir.path);
}
