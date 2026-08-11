import 'dart:io';

import 'package:learning_tracker/core/database/content/content_database.dart';
import 'package:learning_tracker/core/database/seed_manager.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

/// Filesystem path for the bundled content database.
///
/// Resolves the path by running [SeedManager.ensureContentDb] in the
/// background — decompresses the asset on first launch, no-ops on subsequent
/// launches. Runs independently of [runApp] so the UI is not blocked during
/// cold start (see bootstrap.dart).
///
/// Tests override [contentDatabaseProvider] directly with an in-memory DB and
/// never need to override this provider.
@Riverpod(keepAlive: true)
Future<String> contentDbPath(Ref ref) async {
  final docsDir = await getApplicationDocumentsDirectory();
  final seedManager = SeedManager(
    dbDirectory: docsDir.path,
    logger: AppLogger.instance,
  );
  return seedManager.ensureContentDb();
}

/// Content database — read-only, bundled seed content.
///
/// Awaits [contentDbPathProvider] so extraction completes before the database
/// is opened. The first read after a fresh install/clear will suspend until
/// seeding finishes; subsequent launches return immediately (already extracted).
///
/// Tests typically override this with an in-memory database via
/// `createTestContentDatabase()` instead of relying on [contentDbPath].
@Riverpod(keepAlive: true)
Future<ContentDatabase> contentDatabase(Ref ref) async {
  final path = await ref.watch(contentDbPathProvider.future);
  final database = ContentDatabase.openReadOnly(
    File(path),
    logger: AppLogger.instance,
  );
  ref.onDispose(database.close);
  return database;
}
