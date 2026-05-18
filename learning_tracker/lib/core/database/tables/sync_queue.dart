import 'package:drift/drift.dart';

/// Offline sync queue table for storing pending Firestore operations.
///
/// Operations are queued when the device is offline and flushed
/// when connectivity is restored.
///
/// I-5: [entityKey] is a nullable business-key for dedup. Callers that
/// provide a non-null entityKey use INSERT OR REPLACE via
/// [SyncQueueDao.enqueueWithKey] so rapid successive edits to the same
/// entity collapse to a single pending row.
@TableIndex(name: 'sync_queue_entity_key', columns: {#entityKey}, unique: true)
class SyncQueue extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Type of operation: 'completion', 'bookmark', 'settings', 'streak', 'profile'
  TextColumn get operationType => text()();

  /// JSON-encoded payload of the operation
  TextColumn get payload => text()();

  /// When the operation was queued (UTC)
  DateTimeColumn get queuedAt => dateTime()();

  /// Number of retry attempts
  IntColumn get retryCount => integer().withDefault(const Constant<int>(0))();

  /// Last error message (if any)
  TextColumn get lastError => text().nullable()();

  /// I-5: Stable entity key for dedup (e.g. "track_config:42", "profile:1").
  /// Null for operations that do not require dedup (legacy callers, one-off events).
  /// UNIQUE — INSERT OR REPLACE on this key keeps only the latest payload.
  TextColumn get entityKey => text().nullable()();
}
