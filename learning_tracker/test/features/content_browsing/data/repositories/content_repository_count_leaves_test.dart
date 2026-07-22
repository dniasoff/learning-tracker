/// R8 (OOM) — equivalence guard for
/// [ContentRepositoryImpl.countLeavesForCurriculum].
///
/// The Lifetime-Knowledge header needs each curriculum's total leaf count, but
/// obtaining it via [ContentRepositoryImpl.getContentForCurriculum]
/// force-loads and PERMANENTLY caches every curriculum's full ~N-item
/// hierarchy — the driver of the R8 out-of-memory kill. `countLeavesForCurriculum`
/// returns the SAME number without retaining the materialized list.
///
/// This test pins the invariant on the REAL bundled assets for EVERY
/// [CurriculumId]:
///
///   countLeavesForCurriculum(c)
///     == getContentForCurriculum(c).where((i) => i.isLeaf).length
///
/// It also documents, with hard numbers, WHY the header denominator was NOT
/// rewired to a count-sum in this pass (Part B deferral): the header total is a
/// UNION of leaf refs (dedups Chumash ⊂ Tanach etc.), so a naive per-curriculum
/// count-sum would change the displayed total.
///
/// The repository normally reads assets through `rootBundle`, which is empty in
/// the test environment; [_DiskContentRepository] overrides the single
/// `loadRawContentJson` seam to read the same JSON from disk so BOTH code paths
/// (count and materialize) exercise identical real content.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/content_browsing/data/repositories/content_repository_impl.dart';

/// [ContentRepositoryImpl] that loads bundled hierarchy JSON from disk instead
/// of `rootBundle`, so the equivalence check runs against real content.
class _DiskContentRepository extends ContentRepositoryImpl {
  @override
  Future<String> loadRawContentJson(String key) =>
      File('assets/content/hierarchy/$key.json').readAsString();
}

void main() {
  test(
    'countLeavesForCurriculum == getContentForCurriculum(c).where(isLeaf).length '
    'for every CurriculumId (cold + warm paths)',
    () async {
      for (final c in CurriculumId.values) {
        // COLD path: fresh repo so the count parses the asset transiently
        // (nothing cached yet) — the memory-critical path.
        final repo = _DiskContentRepository();
        final coldCount = await repo.countLeavesForCurriculum(c);

        // Materialized truth via the full load.
        final materializedLeafCount = (await repo.getContentForCurriculum(
          c,
        )).where((i) => i.isLeaf).length;

        expect(
          coldCount,
          materializedLeafCount,
          reason:
              '${c.storageKey}: cold count must equal materialized leaf count',
        );

        // WARM path: curriculum is now cached; the count must still match.
        final warmCount = await repo.countLeavesForCurriculum(c);
        expect(
          warmCount,
          materializedLeafCount,
          reason:
              '${c.storageKey}: warm (cache-backed) count must equal '
              'materialized leaf count',
        );
      }
    },
  );

  test(
    'header total is the UNION of leaf refs (70,033), NOT the per-curriculum '
    'count-sum (93,395) — documents the Part B denominator deferral',
    () async {
      final repo = _DiskContentRepository();

      final unionRefs = <String>{};
      var countSum = 0;
      for (final c in CurriculumId.values) {
        final items = await repo.getContentForCurriculum(c);
        unionRefs.addAll(items.where((i) => i.isLeaf).map((i) => i.sefariaRef));
        countSum += await repo.countLeavesForCurriculum(c);
      }

      // The number the header shows ("X / 70,033 sections"): distinct refs.
      expect(
        unionRefs.length,
        70033,
        reason:
            'lifetimeTotalsAcrossAllCurriculaProvider.totalSections is the '
            'cardinality of the union of allLeafRefs',
      );
      // Summing per-curriculum counts double-counts overlapping curricula.
      expect(
        countSum,
        93395,
        reason: 'naive count-sum double-counts Chumash/Nach inside Tanach',
      );
      // The gap is exactly why routing the denominator through countLeaves+sum
      // would break the total.
      expect(countSum - unionRefs.length, 23362);
    },
  );
}
