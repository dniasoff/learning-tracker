import 'package:drift/drift.dart';

/// Offline sync queue table for storing pending Firestore operations.
///
/// Operations are queued when the device is offline and flushed
/// when connectivity is restored.
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Type of operation: 'completion', 'bookmark', 'settings', 'streak', 'profile'
  TextColumn get operationType => text()();

  /// JSON-encoded payload of the operation
  TextColumn get payload => text()();

  /// When the operation was queued (UTC)
  DateTimeColumn get queuedAt => dateTime()();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant(0))();

  /// Last error message (if any)
  TextColumn get lastError => text().nullable()();
}
