import 'package:drift/drift.dart';

/// Simple key-value store for device-level state that doesn't
/// belong in any single account's database. Primary use:
/// `lastActiveAccountId`.
class DeviceState extends Table {
  TextColumn get key => text()();
  TextColumn get value => text().nullable()();

  @override
  Set<Column> get primaryKey => {key};
}
