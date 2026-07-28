import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';

/// Rank of a [MilestoneLevel] from finest (0) to coarsest (2).
///
/// Milestones nest: a unit (masechta / sefer / siman / hilchos) sits inside an
/// aggregate (seder group), which sits inside the whole curriculum. The rank
/// makes that ordering explicit so the granularity gate can compare levels.
int milestoneLevelRank(MilestoneLevel level) => switch (level) {
  MilestoneLevel.unit => 0,
  MilestoneLevel.aggregate => 1,
  MilestoneLevel.curriculum => 2,
};

/// Keep only the milestones at or coarser than the chosen [finest] tier.
///
/// This is a **pure suppression filter** over already-emitted milestones:
/// `rank(m.level) >= rank(finest)`. It NEVER adds or fabricates a milestone —
/// the run-11 false "Chumash complete" P0 was an *emission* bug, and this gate
/// is structurally incapable of that class because it only ever removes rows.
///
/// * `finest == unit`       → all tiers survive (the default; identical to the
///   pre-gate behaviour).
/// * `finest == aggregate`  → unit milestones suppressed; aggregate + whole
///   survive.
/// * `finest == curriculum` → only the whole-curriculum milestone survives.
List<MilestoneAchievement> filterMilestonesByGranularity(
  List<MilestoneAchievement> milestones,
  MilestoneLevel finest,
) {
  final threshold = milestoneLevelRank(finest);
  return milestones
      .where((m) => milestoneLevelRank(m.level) >= threshold)
      .toList();
}
