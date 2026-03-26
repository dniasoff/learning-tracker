import 'package:drift/drift.dart';

/// Learning program presets table.
///
/// Stores immutable learning program definitions (e.g., Oraysa, Daf Yomi).
/// Presets are never modified — only deprecated and replaced.
class LearningPrograms extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get curriculumType => text()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get stagesConfig => text()(); // JSON
  BoolColumn get hasTests => boolean().withDefault(const Constant(false))();
  TextColumn get testConfig =>
      text().withDefault(const Constant('{}'))(); // JSON
  DateTimeColumn get createdAt => dateTime()();

  /// API source for calendar programs: 'sefaria', 'hebcal', or null (custom)
  TextColumn get apiSource => text().nullable()();

  /// Key identifying this program in the API response
  TextColumn get apiProgramKey => text().nullable()();

  /// Whether this is a calendar-linked program (vs custom/local)
  BoolColumn get isCalendarProgram =>
      boolean().withDefault(const Constant(false))();
}
