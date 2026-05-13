import 'package:drift/drift.dart';

/// Accounts table — user accounts (v2 hard-tier schema).
///
/// Every user has a real account with an email. `tier` is set at signup
/// by network state and is immutable — except for the one-way upgrade
/// flow (Epic 20 story 20.9) which flips `localBorn` → `cloudBorn`
/// atomically along with setting `firebaseUid`.
///
/// Architecture-doc-correct name (was: UserProfiles). Renamed in schema v1
/// as part of the E25 greenfield rebuild (DNI-322).
class Accounts extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// Email is the stable identity for both tiers.
  TextColumn get email => text().unique()();

  /// Populated only for cloud-born (or upgraded) accounts.
  TextColumn get firebaseUid => text().nullable().unique()();

  /// argon2id password hash — populated only for local-born accounts.
  /// Cleared when a local-born account is upgraded to cloud-born.
  TextColumn get passwordHash => text().nullable()();

  /// `cloudBorn` | `localBorn`. Set at signup, immutable except via upgrade.
  TextColumn get tier => text()();

  TextColumn get displayName => text()();
  TextColumn get userMode => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
}
