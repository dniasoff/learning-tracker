/// AD-50 points: ledger totals and the achievement latch.
///
/// DNI-468 (1.6) fills the functions; the value types are fixed by C0.
library;

import 'package:learning_tracker/domain/learner_state/c0_stub.dart';

/// One `points_ledger` row.
final class PointsLedgerRow {
  /// Creates a row; [eventId] is the earning learning event, if any.
  const PointsLedgerRow({required this.id, required this.amount, this.eventId});

  /// The ledger document id.
  final String id;

  /// Points added (positive) or spent (negative).
  final int amount;

  /// The learning event that earned the points (`pts_{eventId}` rows).
  final String? eventId;

  @override
  bool operator ==(Object other) =>
      other is PointsLedgerRow &&
      other.id == id &&
      other.amount == amount &&
      other.eventId == eventId;

  @override
  int get hashCode => Object.hash(id, amount, eventId);

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
/// C0 stub, filled by DNI-468 (1.6).
PointsTotals pointsTotals(
  List<PointsLedgerRow> rows,
  Set<String> earningEventIds,
) => c0Stub('DNI-468', 'pointsTotals');

/// The achievement ids [totals] now reaches that are not yet in [unlocked].
///
/// C0 stub, filled by DNI-468 (1.6).
Set<String> newlyCrossedAchievements(
  PointsTotals totals,
  List<AchievementThreshold> thresholds,
  Set<String> unlocked,
) => c0Stub('DNI-468', 'newlyCrossedAchievements');
