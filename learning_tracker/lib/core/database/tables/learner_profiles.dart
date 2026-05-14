import 'package:drift/drift.dart';

/// LearnerProfiles table — learner profiles within an account.
///
/// Each account can have up to 10 profiles. Each profile has its own
/// separate learning data (completions, bookmarks, goals, etc.).
///
/// Architecture-doc-correct name (was: Profiles). Renamed in schema v1
/// as part of the E25 greenfield rebuild (DNI-322).
class LearnerProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer()();
  TextColumn get displayName => text()();
  TextColumn get mode => text()(); // 'child' or 'adult'
  IntColumn get avatarIndex => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
