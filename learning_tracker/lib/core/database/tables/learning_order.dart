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

  @override
  List<Set<Column>> get uniqueKeys => [
    {profileId, curriculumId, sefariaRef},
  ];
}
