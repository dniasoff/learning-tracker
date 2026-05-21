import 'package:drift/drift.dart';

/// Persisted last-applied `updated_at` per `(kind, entityKey)`.
///
/// Phase 3 of the sync architecture plan: closes the LWW symmetry gap.
///
/// Background — before this table, [DriftMergeStore.currentUpdatedAt] returned
/// `null` for several entity kinds (`bookmark`, `settings`, `stageDefinition`,
/// `learningOrder`, …). That made [remoteIsNewer] unconditionally true on
/// every pull, so local edits made between two pulls were silently overwritten.
///
/// This table is the single source of truth for the LWW timestamp every merger
/// consults: after a merger successfully applies a remote row it writes the
/// row's `updated_at` here, and on the next pull `currentUpdatedAt` reads it
/// back. Combined with the optional [syncedAtMs] tie-breaker (Firestore
/// server timestamp recorded for ±5 s clock-skew arbitration), LWW becomes
/// symmetric: a local row written between pulls is preserved as long as the
/// merger's clock outruns the remote's last write.
///
/// Schema:
///   * (kind, entityKey)   — composite primary key.
///   * updatedAtMs         — millisecondsSinceEpoch of the remote row's
///                           `updated_at` field (UTC).
///   * syncedAtMs          — millisecondsSinceEpoch of the Firestore
///                           server timestamp (`synced_at`) when known;
///                           NULL for legacy rows that never carried one.
class SyncKv extends Table {
  /// Entity kind — matches [EntityKind] constants (e.g. `bookmark`,
  /// `settings`, `stage_definition`).
  TextColumn get kind => text()();

  /// Natural key of the entity within [kind]. Format is per-kind and
  /// defined by the individual merger (e.g. `${curriculumId}|${trackType}`
  /// for bookmarks).
  TextColumn get entityKey => text()();

  /// Last-applied client `updated_at` for this `(kind, entityKey)`.
  IntColumn get updatedAtMs => integer()();

  /// Last-known Firestore server timestamp (`synced_at`) for this
  /// `(kind, entityKey)`. Used as the tie-breaker when client `updated_at`
  /// values are within ±5 s on two devices.
  IntColumn get syncedAtMs => integer().nullable()();

  @override
  Set<Column<Object>>? get primaryKey => {kind, entityKey};
}
