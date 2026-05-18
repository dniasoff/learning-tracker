import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Stage definitions table per D3.
///
/// Defines the learning stages (e.g., learning, chazara1, chazara2)
/// for each curriculum with ordering and delay configuration.
class StageDefinitions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// C2: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId => integer().references(
    LearnerProfiles,
    #id,
    onDelete: KeyAction.cascade,
  )();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  IntColumn get stageOrder => integer()();
  TextColumn get stageName => text()();
  IntColumn get delayDays => integer()();
  BoolColumn get isDefault => boolean().withDefault(const Constant(false))();
  TextColumn get scheduleType => text().withDefault(const Constant('delay'))();
  TextColumn get daysOfWeek => text().nullable()();
  IntColumn get rollingWindowSize => integer().nullable()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, stageOrder, trackId},
  ];
}
