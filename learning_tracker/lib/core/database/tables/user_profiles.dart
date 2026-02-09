import 'package:drift/drift.dart';

/// User profiles table for storing user account information.
class UserProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get firebaseUid => text().unique()();
  TextColumn get displayName => text()();
  TextColumn get userMode => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
