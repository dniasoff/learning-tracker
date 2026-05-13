/// In-memory Drift database helper (DNI-377 / 27.1).
///
/// Provides a single entry point — [inMemoryDb] — that returns a fresh
/// `UserDatabase` backed by `NativeDatabase.memory()` at the current
/// `schemaVersion`. Each call returns an independent instance: tests can
/// hold two databases side-by-side without state bleeding across them.
///
/// Prefer this helper over the older `createTestDatabase()` in
/// `test_database.dart` — it documents the schema-version contract and is
/// the canonical entry point for integration tests landing in DNI-27.5
/// through 27.9.
library;

import 'package:drift/native.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

/// Returns a brand-new `UserDatabase` whose backing store lives only in
/// process memory. The migration runner executes synchronously on first
/// query, materialising the current `schemaVersion` schema.
///
/// Callers MUST `await db.close()` in `tearDown` to free the native
/// resources.
UserDatabase inMemoryDb() => UserDatabase(NativeDatabase.memory());
