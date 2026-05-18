import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Completions table — read-only projection derived from completion_events (C1).
///
/// New rows are written by [CompletionWriter] which writes to
/// [CompletionEvents] first (canonical), then derives this row with
/// [derivedFromEvents] = true. Legacy rows (pre-C1) have [derivedFromEvents]
/// = false and are left untouched by the new write path.
///
/// Deleting from this table is safe (it is a projection); the canonical
/// history lives in [CompletionEvents].
// AR4 hot-path composite index for dashboard reads filtering by
// (profileId, curriculumId) ordered by completedAt DESC. Defined via
// raw SQL so the trailing column can be DESC-ordered (Drift's
// columns-set form does not support per-column ordering).
@TableIndex.sql(
  'CREATE INDEX completions_pidx_pid_cur_completed '
  'ON completions (profile_id, curriculum_id, completed_at DESC)',
)
// Composite index on the natural key. DNI-324 keeps this NON-UNIQUE on the
// existing `completions` history table (review-count semantics permit
// multiple rows per natural key). DNI-323 introduces the new
// `completion_events` table where the same composite becomes UNIQUE,
// satisfying Story 25.2's append-only/dedup invariant.
@TableIndex(
  name: 'completions_natural_key',
  columns: {#profileId, #sefariaRef, #stageId, #trackType},
)
class Completions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId => integer().references(
    LearnerProfiles,
    #id,
    onDelete: KeyAction.cascade,
  )();

  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get points => integer().withDefault(const Constant<int>(0))();

  /// C1: true when this row was derived from a completion_events write.
  /// false for legacy rows written before C1 was deployed.
  BoolColumn get derivedFromEvents =>
      boolean().withDefault(const Constant(false))();
}
