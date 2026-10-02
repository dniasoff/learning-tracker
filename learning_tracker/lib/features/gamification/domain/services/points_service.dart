import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Reads the global debitable points balance: the AD-50 filtered sum of the
/// points ledger (DNI-480).
abstract class PointsBalanceReader {
  Future<int> getBalance();
}

/// Reads the points earned for milestone progression: the same AD-50
/// filtered sum without spends and refunds.
///
/// Deliberately separate from [PointsBalanceReader]: points spent on
/// rewards reduce the debitable balance but not lifetime earned. Lifetime
/// earned is not monotonic: voiding an earning event lowers it (AD-50).
abstract class PointsLifetimeEarnedReader {
  Future<int> getLifetimeEarned();
}

/// One counted `pts_{eventId}` award: an earning event's points and the
/// curriculum of its learning event.
final class EarnedPoints {
  const EarnedPoints({
    required this.eventId,
    required this.curriculumId,
    required this.points,
  });

  /// The earning learning event.
  final String eventId;

  /// The curriculum of that event.
  final CurriculumId curriculumId;

  /// The points of its ledger row (frozen at capture, AD-50).
  final int points;
}

/// Reads the awards of the events the engine says earn
/// (`LearnerState.earningEventIds`).
abstract class EarnedPointsReader {
  Future<List<EarnedPoints>> getEarnedPoints();
}

/// Service for querying gamification points (AD-50).
///
/// Points are co-written by `LearningCommands` as `pts_{eventId}` rows with
/// each `source = main` dated or catch-up learn event; the engine alone
/// decides which of them earn. This service only reads: the filtered
/// balance and the per-curriculum split of counted awards. It never reads
/// completions (DNI-480 retired that path).
class PointsService {
  final PointsBalanceReader _balanceReader;
  final EarnedPointsReader _earnedReader;

  PointsService({
    required PointsBalanceReader balanceReader,
    required EarnedPointsReader earnedReader,
  }) : _balanceReader = balanceReader,
       _earnedReader = earnedReader;

  /// Current debitable points balance for this profile (WS7.balance): the
  /// AD-50 filtered, clamped ledger sum (DEC-32).
  Future<int> getGlobalTotal() => _balanceReader.getBalance();

  /// Points of counted awards per curriculum; a curriculum with none is
  /// absent.
  Future<Map<CurriculumId, int>> getCurriculumBreakdown() async {
    final totals = <CurriculumId, int>{};
    for (final award in await _earnedReader.getEarnedPoints()) {
      if (award.points <= 0) continue;
      totals.update(
        award.curriculumId,
        (sum) => sum + award.points,
        ifAbsent: () => award.points,
      );
    }
    return totals;
  }
}
