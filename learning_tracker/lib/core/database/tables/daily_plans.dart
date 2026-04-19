import 'package:drift/drift.dart';

/// Snapshot of the day's scheduled tasks, per profile + curriculum + local date.
///
/// The scheduler runs once per local day to materialize rows here; completions
/// only mark the matching row done — they do not regenerate the plan. This
/// enforces the "today's list is a contract" property required by program
/// tracks and user-configured self-paced schedules.
class DailyPlans extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get profileId => integer()();
  TextColumn get curriculumId => text()();

  /// Local date (midnight, stored as UTC-normalized midnight of the local day)
  /// that this plan entry belongs to.
  DateTimeColumn get planDate => dateTime()();

  TextColumn get sefariaRef => text()();
  IntColumn get stageOrder => integer()();
  IntColumn get stageDefinitionId => integer()();
  IntColumn get trackId => integer()();
  TextColumn get trackLabel => text().withDefault(const Constant(''))();

  /// Enum name of DailyTaskPriority (e.g., "overdueChazara").
  TextColumn get priority => text()();
  BoolColumn get isOverdue => boolean().withDefault(const Constant(false))();
  TextColumn get reason => text().withDefault(const Constant(''))();
  TextColumn get stageName => text().withDefault(const Constant(''))();
  IntColumn get estimatedEffortMinutes =>
      integer().withDefault(const Constant(3))();

  /// Position within the day's plan (stable ordering for rendering).
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  DateTimeColumn get createdAt => dateTime()();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, planDate, sefariaRef, stageOrder, trackId},
  ];
}
