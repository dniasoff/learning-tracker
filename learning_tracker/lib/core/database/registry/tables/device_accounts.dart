import 'package:drift/drift.dart';

/// Tracks all accounts on this device. One row per account,
/// max 5 enforced at the DAO level.
class DeviceAccounts extends Table {
  TextColumn get accountId => text()();
  TextColumn get email => text()();
  TextColumn get displayName => text()();

  /// `cloudBorn` | `localBorn`
  TextColumn get tier => text()();

  /// The **Firestore-path uid** — the `{uid}` in `users/{uid}/…` — for this
  /// account. Null for local-born accounts that have not yet been bound to a
  /// Firebase principal.
  ///
  /// **AD-24 rule 2:** this persisted field, never the live
  /// `FirebaseAuth.currentUser`, is the sole source of the path uid. It holds
  /// either the resolved cloud uid (email/Google sign-in) or the Anonymous
  /// Auth uid assigned to a local-born account (AD-19, Phase 4). Callers MUST
  /// go through [PathUidResolver] (`path_uid_resolver.dart`) rather than
  /// reading this column directly, so the remap bookkeeping below stays
  /// consistent.
  TextColumn get firebaseUid => text().nullable()();

  /// The uid [firebaseUid] held immediately before the most recent
  /// anon-uid-reset remap (AD-19/AD-24), or null if no remap has ever
  /// happened for this account.
  ///
  /// Breadcrumb for the downstream Firestore data layer (out of this
  /// story's scope — see `path_uid_resolver.dart`): a non-null value here
  /// means the document tree at `users/<previousFirebaseUid>/…` may still
  /// hold data that belongs to this account and has not yet been re-homed
  /// to `users/<firebaseUid>/…`.
  TextColumn get previousFirebaseUid => text().nullable()();

  /// When the most recent anon-uid-reset remap happened, or null if none has
  /// ever happened for this account. Diagnostic timestamp only.
  DateTimeColumn get uidRemappedAt => dateTime().nullable()();

  IntColumn get avatarIndex => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get lastUsedAt => dateTime()();

  /// The filename for this account's user database, e.g.
  /// `user_acc_abc123.db`. Unique so no two accounts share a file.
  TextColumn get dbFileName => text().unique()();

  @override
  Set<Column> get primaryKey => {accountId};
}
