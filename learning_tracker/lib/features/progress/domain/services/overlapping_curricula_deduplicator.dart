import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/models/lifetime_knowledge.dart';

/// Deduplicates leaf-section counts across overlapping curricula.
///
/// Some curricula are strict subsets of others (e.g. Chumash ⊂ Tanach).
/// Without deduplication, a section learned via a Chumash track would count
/// twice in the lifetime totals — once for Chumash and once for Tanach.
///
/// This service collapses the list of per-curriculum [CurriculumLifetimeSummary]
/// objects into a single [LifetimeTotals] using set union on `sefariaRef`
/// strings.
class OverlappingCurriculaDeduplicator {
  const OverlappingCurriculaDeduplicator();

  /// Computes [LifetimeTotals] from a list of per-curriculum summaries.
  ///
  /// Uses set union on `sefariaRef` strings to avoid double-counting sections
  /// that appear in multiple curricula (e.g. Chumash ⊂ Tanach).
  LifetimeTotals compute(List<CurriculumLifetimeSummary> summaries) {
    final allDistinct = <String>{};
    final learnedDistinct = <String>{};
    for (final s in summaries) {
      allDistinct.addAll(s.allLeafRefs);
      learnedDistinct.addAll(s.learnedLeafRefs);
    }
    return LifetimeTotals(
      learnedSections: learnedDistinct.length,
      totalSections: allDistinct.length,
      totalCurricula: CurriculumId.values.length,
    );
  }
}
