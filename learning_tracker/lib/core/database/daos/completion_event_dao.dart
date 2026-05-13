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
  Future<int> appendEvent(CompletionEventsCompanion entry) async {
    await into(completionEvents).insert(entry, mode: InsertMode.insertOrIgnore);
    final row =
        await (select(completionEvents)
              ..where(
                (t) =>
                    t.profileId.equals(entry.profileId.value) &
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
}
