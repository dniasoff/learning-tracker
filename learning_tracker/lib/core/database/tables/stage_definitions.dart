import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Stage definitions table per D3.
///
/// Defines the learning stages (e.g., learning, chazara1, chazara2)
/// for each curriculum with ordering and schedule configuration.
///
/// W3.23: added `updatedAt` for LWW sync support.
/// W3.27: replaced schedule quartet (scheduleType/daysOfWeek/
///   rollingWindowSize/delayDays) with a single JSON `schedule` column.
///   The JSON encodes the ScheduleSpec sealed union, e.g.
///   `{"type":"delay","delay_days":7}` or
///   `{"type":"days_of_week","days":[0,3,5]}`.
/// W3.29: dropped `supersededAt` — lifecycle managed via `state`.
class StageDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  IntColumn get stageOrder => integer()();
  TextColumn get stageName => text()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();

  /// JSON-encoded ScheduleSpec, e.g. {"type":"delay","delay_days":7}.
  /// Replaces the former quartet: scheduleType / daysOfWeek /
  /// rollingWindowSize / delayDays.
  TextColumn get schedule => text().withDefault(
    const Constant('{"type":"delay","delay_days":0}'),
  )();

  /// W3.23: last-write-wins timestamp for sync.
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, stageOrder, trackId},
  ];
}
