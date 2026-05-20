import 'package:learning_tracker/core/enums/curriculum_id.dart';

/// Completion state of a node in the lifetime knowledge tree.
enum LifetimeNodeState {
  /// No leaves in this sub-tree have been learned.
  none,

  /// Some but not all leaves have been learned.
  partial,

  /// All leaves in this sub-tree have been learned.
  full,
}

/// One node in the lifetime knowledge tree.
///
/// Carries the structured metadata the renderer needs to produce a
/// level-aware local label ("פרק א", not "משנה דמאי א") — the actual text is
/// rendered by [CurriculumLabel.level] at the UI layer so the Hebrew Terms
/// toggle is respected.
class LifetimeTreeNode {
  const LifetimeTreeNode({
    required this.curriculumId,
    required this.level,
    required this.rawValue,
    required this.parentL1Value,
    required this.hebrewName,
    required this.state,
    required this.children,
  });

  final CurriculumId curriculumId;

  /// Hierarchy level (1..4) — Seder / Masechta / Perek / Mishna for Mishnayos.
  final int level;

  /// Raw value from `content_items.levelN` (e.g. "Chullin", "1" for Perek 1).
  /// Sortable; usable as a node key.
  final String rawValue;

  /// The level-1 value for this branch (needed for curricula whose level
  /// structure varies by top-level book, e.g. Mussar).
  final String parentL1Value;

  /// Optional Hebrew name from the matching intermediate [ContentItem] row.
  /// Null when no intermediate row was found; renderer falls back to raw.
  final String? hebrewName;

  final LifetimeNodeState state;
  final List<LifetimeTreeNode> children;
}

/// Aggregated lifetime progress summary for one curriculum.
///
/// Built by [LifetimeTreeBuilder] from raw completions, learning ledger
/// entries, and the curriculum's content hierarchy.
class CurriculumLifetimeSummary {
  const CurriculumLifetimeSummary({
    required this.curriculumId,
    required this.learnedLeafCount,
    required this.totalLeafCount,
    required this.percentage,
    required this.tree,
    this.learnedLeafRefs = const {},
    this.allLeafRefs = const {},
  });

  final CurriculumId curriculumId;
  final int learnedLeafCount;
  final int totalLeafCount;
  final double percentage;
  final List<LifetimeTreeNode> tree;

  /// Distinct `sefariaRef` strings for leaf sections that have been learned.
  /// Used by [OverlappingCurriculaDeduplicator] to deduplicate across
  /// overlapping curricula (e.g. Chumash ⊂ Tanach).
  final Set<String> learnedLeafRefs;

  /// Distinct `sefariaRef` strings for all leaf sections in this curriculum.
  /// Used by [OverlappingCurriculaDeduplicator] to deduplicate totals
  /// across overlapping curricula (e.g. Chumash ⊂ Tanach).
  final Set<String> allLeafRefs;
}

/// Dual-progress metric for a single track — current cycle + lifetime.
///
/// Computed by [TrackDualProgressCalculator].
class TrackDualProgressMetric {
  const TrackDualProgressMetric({
    required this.trackId,
    required this.trackLabel,
    required this.curriculumId,
    required this.currentCyclePercentage,
    required this.lifetimePercentage,
    required this.isProgramTrack,
    this.todayDueCount,
    this.overdueCount,
  });

  final int trackId;
  final String trackLabel;
  final CurriculumId curriculumId;
  final double currentCyclePercentage;

  /// Learned leaf units ÷ leaf units in this track's [curriculum_scopes] slice
  /// (falls back to full curriculum when no scope is set).
  final double lifetimePercentage;
  final bool isProgramTrack;
  final int? todayDueCount;
  final int? overdueCount;
}

/// Aggregated lifetime learning totals across all active curricula.
///
/// Computed by [OverlappingCurriculaDeduplicator] over a list of
/// [CurriculumLifetimeSummary] objects.
class LifetimeTotals {
  const LifetimeTotals({
    required this.learnedSections,
    required this.totalSections,
    required this.totalCurricula,
  });

  /// Leaf units marked lifetime-learned, summed across all curricula in scope.
  final int learnedSections;

  /// Total leaf units in scope (all loadable hierarchies for the profile).
  final int totalSections;

  /// Tracked [CurriculumId] count (nine); display copy, not the divisor for %.
  final int totalCurricula;

  /// Pooled completion: completed sections / total sections in app content.
  double get percentage =>
      totalSections > 0 ? learnedSections / totalSections : 0.0;
}
