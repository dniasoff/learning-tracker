import 'package:drift/drift.dart';
import 'package:learning_tracker/core/database/tables/learner_profiles.dart';

/// Stores the current debitable points balance per child profile (WS7.balance).
///
/// One row per profile. Credited on completion via [PointsLedger] entries;
/// debited on reward redemption. Adult profiles never have balance rows
/// (Rule 3: adults have no points).
///
/// The balance column is the authoritative denormalised sum of all ledger
/// entries. All mutations must go through [PointsBalanceDao] which updates
/// both the ledger and the balance atomically in a transaction.
class PointsBalance extends Table {
  /// FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  /// Current debitable balance. Never negative (enforced in PointsBalanceDao).
  IntColumn get balance => integer().withDefault(const Constant<int>(0))();

  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {profileId};
}

/// Append-only ledger of all balance mutations (WS7.balance / WS7.adjust).
///
/// Entry kinds:
/// - `completion` — points credited automatically when a completion is recorded.
/// - `redemption_debit` — points debited when a child redeems a reward.
/// - `redemption_refund` — points credited back when a parent declines a
///   redemption.
/// - `parent_add` — manual addition by parent (PIN-gated, DEC-17).
/// - `parent_deduct` — manual deduction by parent (PIN-gated, DEC-17).
class PointsLedger extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  /// `completion` | `redemption_debit` | `redemption_refund`
  /// | `parent_add` | `parent_deduct`
  TextColumn get entryKind => text()();

  /// Signed delta applied to [PointsBalance.balance].
  /// Positive = credit; negative = debit.
  IntColumn get delta => integer()();

  /// Optional description (note from parent, reward title, etc.).
  TextColumn get note => text().nullable()();

  /// Optional FK to [RewardRedemptions.id] for redemption-related entries.
  IntColumn get redemptionId => integer().nullable()();

  DateTimeColumn get createdAt => dateTime()();

  /// Stable, lexicographically-sortable, cross-device id for append-only
  /// cloud sync (schema v27, WS9 Wave-B). Nullable on existing rows; the
  /// Wave-B sync agent backfills + populates this going forward, and uses it
  /// as the deterministic Firestore document id for ledger entries.
  TextColumn get ulid => text().nullable()();
}

/// Tracks reward redemption requests (WS7.redeem).
///
/// Status lifecycle:
/// - `pending_fulfilment` — child has spent points, waiting for parent action.
/// - `fulfilled` — parent approved and marked as done.
/// - `declined` — parent declined; points were refunded.
class RewardRedemptions extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// FK → learner_profiles(id) CASCADE DELETE.
  IntColumn get profileId =>
      integer().references(LearnerProfiles, #id, onDelete: KeyAction.cascade)();

  /// Snapshot of the reward title at redemption time.
  TextColumn get rewardTitle => text()();

  /// Snapshot of the reward icon index at redemption time.
  IntColumn get iconIndex => integer().withDefault(const Constant<int>(0))();

  /// Points that were debited from the balance when this was created.
  IntColumn get pointsCost => integer()();

  /// `pending_fulfilment` | `fulfilled` | `declined`
  TextColumn get status =>
      text().withDefault(const Constant<String>('pending_fulfilment'))();

  DateTimeColumn get createdAt => dateTime()();

  /// Last-write-wins timestamp for cloud sync (already present pre-v27; used
  /// as the LWW field by the Wave-B sync agent).
  DateTimeColumn get updatedAt => dateTime()();

  /// Stable, lexicographically-sortable, cross-device id for cloud sync
  /// (schema v27, WS9 Wave-B). Nullable on existing rows; the Wave-B sync
  /// agent backfills + populates this and uses it as the deterministic
  /// Firestore document id for redemptions.
  TextColumn get ulid => text().nullable()();
}
