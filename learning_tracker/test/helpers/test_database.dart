/// Test database helper for creating in-memory Drift databases
/// No file I/O, fast test execution, clean teardown
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/content/content_database.dart';

/// Creates an in-memory test ContentDatabase
ContentDatabase createTestContentDatabase() {
  return ContentDatabase(NativeDatabase.memory());
}
