import 'package:drift/drift.dart';

/// Profiles table — learner profiles within an account.
///
/// Each account can have up to 10 profiles. Each profile has its own
/// separate learning data (completions, bookmarks, goals, etc.).
class Profiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get accountId => integer()();
  TextColumn get displayName => text()();
  TextColumn get mode => text()(); // 'child' or 'adult'
  IntColumn get avatarIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
