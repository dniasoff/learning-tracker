import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/accounts.dart';

/// LearnerProfiles table — learner profiles within an account.
///
/// Each account can have up to 10 profiles. Each profile has its own
/// separate learning data (completions, bookmarks, goals, etc.).
///
/// Architecture-doc-correct name (was: Profiles). Renamed in schema v1
/// as part of the E25 greenfield rebuild (DNI-322).
/// W3.25: accountId FK added.
class LearnerProfiles extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// W3.25: FK → accounts(id) CASCADE DELETE.
  IntColumn get accountId =>
      integer().references(Accounts, #id, onDelete: KeyAction.cascade)();
  TextColumn get displayName => text()();
  /// Profile mode — exactly 'adult' or 'child'. Enforced by CHECK constraint
  /// (schema v26, WS9.enum). Read via [ProfileMode.fromStorageKey].
  TextColumn get mode =>
      text().customConstraint("NOT NULL CHECK (mode IN ('adult', 'child'))")();
  IntColumn get avatarIndex => integer().withDefault(const Constant<int>(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  /// Tutor "talmid view" mirror (schema v28). When true, this is NOT one of
  /// the account's own learners — it is a read-only local mirror of a child
  /// that lives in another user's (the parent's) account, pulled in because
  /// this device's user is an active tutor for that child. Mirror rows must
  /// never be pushed up this account's own outbox.
  BoolColumn get isTutored =>
      boolean().withDefault(const Constant<bool>(false))();

  /// For a tutored mirror: the parent (owner) account's Firebase UID, the
  /// child's profile id within that account, and the tutor grant id. Used to
  /// resolve the source namespace for the pull and to route permitted edits
  /// back to the parent's namespace via Cloud Functions. Null for own profiles.
  TextColumn get tutorParentUid => text().nullable()();
  TextColumn get tutorRemoteProfileId => text().nullable()();
  TextColumn get tutorGrantId => text().nullable()();
}
