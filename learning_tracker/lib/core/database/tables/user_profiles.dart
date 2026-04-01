import 'package:drift/drift.dart';

/// User profiles table for storing user account information.
///
/// In the local-first architecture, every device gets a stable `localUid`
/// (v4 UUID) on first launch. Firebase auth is optional — `firebaseUid`
/// is set only when the user creates a cloud account.
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get localUid => text().unique()();
  TextColumn get firebaseUid => text().nullable().unique()();
  TextColumn get displayName => text()();
  TextColumn get userMode => text()();
  BoolColumn get hasAccount =>
      boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
