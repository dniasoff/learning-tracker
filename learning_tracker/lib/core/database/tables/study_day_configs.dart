import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/curriculum_tracks.dart';

class StudyDayConfigs extends Table {
  IntColumn get profileId => integer().withDefault(const Constant(0))();
  TextColumn get curriculumId => text()();
  IntColumn get trackId => integer().references(CurriculumTracks, #id)();
  IntColumn get dayOfWeek => integer()(); // 1=Mon, 2=Tue, ..., 7=Sun (ISO 8601)
  TextColumn get dayType =>
      text().withDefault(const Constant('study'))(); // 'study' or 'review'
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId, curriculumId, dayOfWeek, trackId};
}
