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
  // customConstraint embeds DEFAULT 0 in the SQL so that ADD COLUMN (migration
  // from < 28) fills existing rows with 0 rather than NULL, satisfying the
  // CHECK (is_tutored IN (0, 1)) constraint on old rows.
  BoolColumn get isTutored => boolean().customConstraint(
    'NOT NULL DEFAULT 0 CHECK ("is_tutored" IN (0, 1))',
  )();

  /// For a tutored mirror: the parent (owner) account's Firebase UID, the
  /// child's profile id within that account, and the tutor grant id. Used to
  /// resolve the source namespace for the pull and to route permitted edits
  /// back to the parent's namespace via Cloud Functions. Null for own profiles.
  TextColumn get tutorParentUid => text().nullable()();
  TextColumn get tutorRemoteProfileId => text().nullable()();
  TextColumn get tutorGrantId => text().nullable()();

  /// Firestore `learner_profiles/{ulid}` doc-id (AD-24), paired with this
  /// row's Drift autoincrement [id] during the Firestore-rewrite transition
  /// (schema v38, `docs/firestore-rewrite-map.md`). Mirrors the same
  /// nullable-ULID-alongside-the-autoincrement-id shape already used by
  /// `learning_ledger`/`points_ledger`/`reward_redemptions` (schema v27) —
  /// see this table's own migration comment in `user_database.dart` for why
  /// that precedent, not a fresh design, governs this column. Column stays
  /// nullable (P2-2 does not bump the schema for this) — a schema change
  /// buys nothing for a column deleted wholesale in Phase 4.
  ///
  /// **P2-2: minted EAGERLY, unconditionally, before this row is ever
  /// inserted — never lazily backfilled on a later edit.**
  /// `FirestoreProfileRepositoryAdapter.createProfile`/`ensureDefaultProfile`
  /// (`lib/features/profiles/data/repositories/profile_repository_impl.dart`)
  /// mint the identity first and pass it into the very insert that creates
  /// this row, so a profile created THROUGH THAT PATH is never observed
  /// with `ulid IS NULL`.
  ///
  /// **T-41: every OTHER live inserter of this table now agrees.**
  /// `ProfileDao.upsertTutoredProfile`'s insert branch records the remote
  /// child's own id as `ulid` (P2-2). `ProfileDao.upsertFromSync` (the
  /// legacy int-keyed sync-pull merge) refuses to insert at all when it has
  /// no local row to update and no `ulid` to give a new one
  /// (`ProfileSyncMissingUlidException` — see that class's doc comment).
  /// `DataExportImportService` carries `ulid` through both the export and
  /// the import side (mirroring the sibling `learningLedger` block), so a
  /// restored backup's profiles keep their identity — and, per this whole
  /// column's greenfield stance, importing an OLD backup that predates this
  /// fix and has no `ulid` in its `learnerProfiles` section fails loudly
  /// (a cast error on import) rather than silently inserting one with none.
  ///
  /// **`NULL` on a row that predates P2-2 means "created before the eager
  /// mint policy shipped" — still never "no profile".** Profile existence
  /// is governed entirely by the Drift row existing (this [id] resolving
  /// via [ProfileDao.getProfileById]/[getProfilesByAccount]), never by this
  /// column. There is no lazy backfill path anymore — under the greenfield
  /// ruling, a pre-P2-2 row's `NULL` is not healed by any code path; the
  /// remedy is wiping and reseeding the device.
  ///
  /// **Transition cruft — deleted with the Drift user database.** Once every
  /// profile-scoped caller reads Firestore ULID identity directly and the
  /// Drift `learner_profiles` table (and the rest of the Drift user
  /// database) is deleted, this column disappears with it. It has no
  /// meaning in the target (Firestore-only) schema — the temporary pairing
  /// belongs in the stack being deleted, not in the schema being kept.
  TextColumn get ulid => text().nullable()();
}
