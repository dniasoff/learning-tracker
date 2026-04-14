import 'package:drift/drift.dart';

/// Tracks all accounts on this device. One row per account,
/// max 5 enforced at the DAO level.
class DeviceAccounts extends Table {
  TextColumn get accountId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();

  /// `cloudBorn` | `localBorn`
  TextColumn get tier => text()();

  /// Firebase UID — null for local-born accounts.
  TextColumn get firebaseUid => text().nullable()();

  IntColumn get avatarIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime()();

  /// The filename for this account's user database, e.g.
  /// `user_acc_abc123.db`. Unique so no two accounts share a file.
  TextColumn get dbFileName => text().unique()();

  @override
  Set<Column> get primaryKey => {accountId};
}
