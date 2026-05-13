import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

/// Completions table — append-only record of all completions.
///
/// This table is INSERT-only. No UPDATE or DELETE operations
/// should be performed on completion records.
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
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get stageId => integer()();
  TextColumn get trackType => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  DateTimeColumn get completedAt => dateTime()();
  IntColumn get points => integer().withDefault(const Constant(0))();
}
