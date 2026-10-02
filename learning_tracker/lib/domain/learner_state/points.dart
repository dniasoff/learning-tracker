/// AD-50 points: ledger totals and the achievement latch.
///
/// Pure projections over typed inputs; the engine decides earning
/// (`LearnerState.earningEventIds`, `earning_events.dart`) and the callers
/// (DNI-469 writes, DNI-480 readers) own every Firestore read and write.
///
/// * The balance and lifetime count a `pts_{eventId}` row only while its
///   event is in `earningEventIds`, plus every non-event row. No reversal
///   rows exist, so voiding an earning event lowers both: lifetime is not
///   monotonic.
/// * Achievements latch (AD-27): [newlyCrossedAchievements] names only the
///   ids to add to `preferences/gamification_settings.unlocked_achievement_ids`;
///   an id already there stays unlocked whatever the totals do later.
library;

/// The upper clamp of both totals, `[0, 1 << 30]`, as the points-ledger
/// repository applies today.
const pointsTotalMax = 1 << 30;

/// The non-event entry kinds that count toward lifetime earned, as today:
/// a refund returns spent points and is not newly earned.
const lifetimeEarnedEntryKinds = <String>{'completion', 'parent_add'};

/// One `points_ledger` row.
final class PointsLedgerRow {
  /// Creates a row; [eventId] is the earning learning event, if any, and
  /// [entryKind] the stored `entry_kind`.
  const PointsLedgerRow({
    required this.id,
    required this.amount,
    this.eventId,
    this.entryKind,
  });

  /// The ledger document id.
  final String id;

  /// Points added (positive) or spent (negative).
  final int amount;

  /// The learning event that earned the points (`pts_{eventId}` rows); a
  /// row without one is a non-event row (spend, refund, adjustment, legacy
  /// completion).
  final String? eventId;

  /// The stored `entry_kind` (`completion`, `redemption_debit`,
  /// `redemption_refund`, `parent_add`, `parent_deduct`), if known. Only
  /// non-event rows read it, for lifetime earned.
  final String? entryKind;

  @override
  bool operator ==(Object other) =>
      other is PointsLedgerRow &&
      other.id == id &&
      other.amount == amount &&
      other.eventId == eventId &&
      other.entryKind == entryKind;

  @override
  int get hashCode => Object.hash(id, amount, eventId, entryKind);

  @override
  String toString() => 'PointsLedgerRow($id, $amount)';
}

/// The filtered points totals of one learner.
final class PointsTotals {
  /// Creates totals.
  const PointsTotals({required this.balance, required this.lifetimeEarned});

  /// Current spendable balance.
  final int balance;

  /// Every point ever earned.
  final int lifetimeEarned;

  @override
  bool operator ==(Object other) =>
      other is PointsTotals &&
      other.balance == balance &&
      other.lifetimeEarned == lifetimeEarned;

  @override
  int get hashCode => Object.hash(balance, lifetimeEarned);

  @override
  String toString() => 'PointsTotals($balance, $lifetimeEarned)';
}

/// An achievement unlocked once lifetime points reach [points].
final class AchievementThreshold {
  /// Creates a threshold.
  const AchievementThreshold({required this.id, required this.points});

  /// The achievement id.
  final String id;

  /// The lifetime points needed.
  final int points;

  @override
  bool operator ==(Object other) =>
      other is AchievementThreshold && other.id == id && other.points == points;

  @override
  int get hashCode => Object.hash(id, points);

  @override
  String toString() => 'AchievementThreshold($id, $points)';
}

/// The totals of [rows], counting an earning row only when its event is in
/// [earningEventIds] (AD-50).
///
/// * A row with an `eventId` counts only while that event earns: an
///   ineligible, voided or orphan `pts_` row counts nothing.
/// * A non-event row always counts toward the balance, and toward lifetime
///   only when it is a positive [lifetimeEarnedEntryKinds] row (spends and
///   refunds never raise lifetime).
/// * A counted event row counts toward lifetime when positive.
/// * Both sums are clamped to `[0, pointsTotalMax]`.
///
/// Rows are keyed by ledger id: a repeated id counts once.
PointsTotals pointsTotals(
  List<PointsLedgerRow> rows,
  Set<String> earningEventIds,
) {
  final seen = <String>{};
  var balance = 0;
  var lifetime = 0;
  for (final row in rows) {
    if (!seen.add(row.id)) continue;
    final eventId = row.eventId;
    if (eventId != null && !earningEventIds.contains(eventId)) continue;
    balance += row.amount;
    final earned =
        eventId != null || lifetimeEarnedEntryKinds.contains(row.entryKind);
    if (earned && row.amount > 0) lifetime += row.amount;
  }
  return PointsTotals(
    balance: balance.clamp(0, pointsTotalMax),
    lifetimeEarned: lifetime.clamp(0, pointsTotalMax),
  );
}

/// The achievement ids [totals] now reaches that are not yet in [unlocked].
///
/// An achievement is crossed when `totals.lifetimeEarned` is at least its
/// threshold. Ids already in [unlocked] are never returned, and nothing is
/// ever removed: the persisted list is the latch (AD-27, AD-50).
Set<String> newlyCrossedAchievements(
  PointsTotals totals,
  List<AchievementThreshold> thresholds,
  Set<String> unlocked,
) => {
  for (final t in thresholds)
    if (totals.lifetimeEarned >= t.points && !unlocked.contains(t.id)) t.id,
};

/// Every unlocked achievement id: the latched [unlocked] list plus those
/// [totals] newly crosses. An unlocked id stays unlocked when the totals
/// later drop.
Set<String> unlockedAchievementIds(
  PointsTotals totals,
  List<AchievementThreshold> thresholds,
  Set<String> unlocked,
) => {...unlocked, ...newlyCrossedAchievements(totals, thresholds, unlocked)};
