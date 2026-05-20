import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Learning order table per D7.
///
/// Allows users to customize the order in which content items
/// are presented within a curriculum.
///
/// sefariaRef references the content item in bundled JSON assets,
/// replacing the old contentItemId FK to the content_items table.
///
/// updatedAt enables last-write-wins conflict resolution when syncing
/// to Firestore across devices (DNI-311).
/// W3.25: profileId FK added.
class LearningOrder extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// W3.25: FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();
  TextColumn get curriculumId => text()();
  TextColumn get sefariaRef => text()();
  IntColumn get userSortOrder => integer()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  /// The content-DB seed version ([SeedMetadata.version]) against which this
  /// order was last saved.
  ///
  /// Default 1 is safe for existing rows: if the current seed version exceeds
  /// the saved version the order is considered stale and the projection is
  /// re-amnestied (last_reorder_at set to nowUtc) so overdue tasks reset.
  /// See §10.1 of the architecture spec.
  IntColumn get learningOrderVersion =>
      integer().withDefault(const Constant(1))();

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, sefariaRef},
  ];
}
