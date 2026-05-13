import 'package:drift/drift.dart';

/// Outbox table — captures pending Firestore mutations atomically.
///
/// A row is written in the same DB transaction as the triggering local write.
/// The OutboxProcessor drains rows by entityKind, dispatching to the
/// appropriate PushPipeline method once connectivity is restored.
///
/// Added in DNI-326 (schema v13).
@TableIndex(name: 'outbox_profile_kind', columns: {#profileId, #entityKind})
class Outbox extends Table {
  /// Auto-increment primary key.
  IntColumn get id => integer().autoIncrement()();

  /// Profile that owns this mutation.
  IntColumn get profileId => integer()();

  /// Logical entity kind, e.g. `completion`, `streak`, `settings`, `track`.
  /// Used by OutboxProcessor to route to the correct PushPipeline method.
  TextColumn get entityKind => text()();

  /// Stable business key for the entity (used for idempotency on re-push).
  TextColumn get entityKey => text()();

  /// JSON-encoded mutation payload.
  TextColumn get payload => text()();

  /// When this row was written (UTC).
  DateTimeColumn get createdAt => dateTime()();

  /// Number of push attempts made so far.
  IntColumn get attempts => integer().withDefault(const Constant(0))();

  /// Last error message, if any push attempt failed.
  TextColumn get lastError => text().nullable()();

  /// Timestamp of the last push attempt (UTC).
  DateTimeColumn get lastAttemptAt => dateTime().nullable()();
}
