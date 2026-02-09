import 'package:drift_flutter/drift_flutter.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'database_provider.g.dart';

@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final database = AppDatabase(
    driftDatabase(name: 'learning_tracker'),
  );
  ref.onDispose(database.close);
  return database;
}
