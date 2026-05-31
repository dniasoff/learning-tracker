import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/completion_events.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';

part 'completion_event_dao.g.dart';

/// DAO for the [CompletionEvents] append-only log (Story 25.2 / DNI-323).
///
/// FR5 invariant: insert-only. No public delete API. Duplicate inserts on
/// the natural key `(profileId, sefariaRef, stageId, trackType)` collapse
/// to one row via `INSERT OR IGNORE` and return the existing row id.
@DriftAccessor(tables: [CompletionEvents])
class CompletionEventDao extends DatabaseAccessor<UserDatabase>
    with _$CompletionEventDaoMixin {
  CompletionEventDao(super.db);

  /// Append a completion event. Idempotent on the natural key — returns
  /// the existing row id when the natural-key composite already exists.
  ///
  /// M2 fix: the UNIQUE index on completion_events uses 5 columns
  /// `(profileId, sefariaRef, stageId, trackType, curriculumId)`.
  /// The WHERE clause here must match all 5 so the SELECT-after-insert
  /// returns the correct row, not an arbitrary row from a different curriculum
  /// that shares the same sefariaRef + stageId + trackType.
  Future<int> appendEvent(CompletionEventsCompanion entry) async {
    await into(completionEvents).insert(entry, mode: InsertMode.insertOrIgnore);
    final row =
        await (select(completionEvents)
              ..where(
                (t) =>
                    t.profileId.equals(entry.profileId.value) &
                    t.curriculumId.equals(entry.curriculumId.value) &
                    t.sefariaRef.equals(entry.sefariaRef.value) &
                    t.stageId.equals(entry.stageId.value) &
                    t.trackType.equals(entry.trackType.value),
              )
              ..limit(1))
            .getSingle();
    return row.id;
  }

  /// All events for a profile, ordered oldest first.
  Future<List<CompletionEvent>> getEventsByProfile(int profileId) =>
      (select(completionEvents)
            ..where((t) => t.profileId.equals(profileId))
            ..orderBy([(t) => OrderingTerm.asc(t.eventTimestamp)]))
          .get();

  /// Returns the row matching the natural key if it exists AND is tombstoned
  /// (`purgedAt IS NOT NULL`). Returns `null` when the row does not exist or
  /// is active (purgedAt IS NULL).
  ///
  /// Used by the pull-merge path (H2) to resurrect a row that was tombstoned
  /// on this device but re-marked as complete on another device.
  /// Finds a tombstoned (purged) completion row by its UNIQUE natural key —
  /// {profileId, curriculumId, sefariaRef, stageId, trackType}.
  ///
  /// D11: must NOT filter on eventTimestamp. A re-mark produces a NEW
  /// completed_at, while the existing tombstone keeps its ORIGINAL timestamp,
  /// so a timestamp predicate would miss the tombstone — the incoming row would
  /// then INSERT-OR-IGNORE-collide on the natural key and the completion would
  /// stay permanently dead. The unique index has no eventTimestamp column.
  Future<CompletionEvent?> findTombstonedEventByNaturalKey({
    required int profileId,
    required String curriculumId,
    required String sefariaRef,
    required int stageId,
    required String trackType,
  }) async {
    final result =
        await (select(completionEvents)
              ..where(
                (t) =>
                    t.profileId.equals(profileId) &
                    t.curriculumId.equals(curriculumId) &
                    t.sefariaRef.equals(sefariaRef) &
                    t.stageId.equals(stageId) &
                    t.trackType.equals(trackType) &
                    t.purgedAt.isNotNull(),
              )
              ..limit(1))
            .getSingleOrNull();
    return result;
  }

  /// Clears the tombstone on the row with [id] by setting `purgedAt` to null,
  /// making the completion active again. When [eventTimestamp] is provided the
  /// row's timestamp is updated to it too, so a resurrected completion reflects
  /// the incoming re-mark time (matching the local re-mark path).
  Future<void> clearTombstone(int id, {DateTime? eventTimestamp}) async {
    await (update(completionEvents)..where((t) => t.id.equals(id))).write(
      CompletionEventsCompanion(
        purgedAt: const Value(null),
        eventTimestamp: eventTimestamp == null
            ? const Value.absent()
            : Value(eventTimestamp),
      ),
    );
  }
}
