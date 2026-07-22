/// R8 Part B — equivalence guard for
/// [ContentRepositoryImpl.loadLeavesTransient].
///
/// The Lifetime-Knowledge/Dashboard header total needs every curriculum's
/// LEAF items (sefariaRef + level1-4, for ledger scope-mark matching), but
/// obtaining them via [ContentRepositoryImpl.getContentForCurriculum]
/// force-loads and PERMANENTLY caches every curriculum's full leaf+container
/// hierarchy — the R8 out-of-memory driver. `loadLeavesTransient` returns the
/// SAME leaves without retaining anything new.
///
/// This test pins the invariant on the REAL bundled assets for EVERY
/// [CurriculumId]:
///
///   loadLeavesTransient(c).map(sefariaRef).toSet()
///     == getContentForCurriculum(c).where(isLeaf).map(sefariaRef).toSet()
///
/// The repository normally reads assets through `rootBundle`, which is empty
/// in the test environment; [_DiskContentRepository] overrides the single
/// `loadRawContentJson` seam to read the same JSON from disk so BOTH code
/// paths (transient-leaves and materialize) exercise identical real content —
/// mirroring `content_repository_count_leaves_test.dart`'s pattern for
/// [ContentRepositoryImpl.countLeavesForCurriculum].
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
    'loadLeavesTransient sefariaRef set == getContentForCurriculum(c).where'
    '(isLeaf) sefariaRef set, for every CurriculumId (cold + warm paths)',
    () async {
      // NOTE: curricula run into the tens of thousands of leaves each, so
      // every check below uses ONE aggregate assertion per curriculum (plain
      // Dart Set operations, not the `test` package's collection matchers) —
      // an `expect` call, or a matcher, per leaf/row multiplies to hundreds
      // of thousands of calls across all 9 curricula and dominates runtime.
      for (final c in CurriculumId.values) {
        // COLD path: fresh repo so loadLeavesTransient parses the asset
        // transiently (nothing cached yet) — the memory-critical path.
        final repo = _DiskContentRepository();
        final coldLeaves = await repo.loadLeavesTransient(c);
        expect(
          coldLeaves.every((l) => l.isLeaf),
          isTrue,
          reason:
              '${c.storageKey}: loadLeavesTransient must never return a '
              'container row',
        );

        // Materialized truth via the full load. Row COUNTS are compared RAW
        // (non-deduped) — some curricula's bundled content legitimately
        // contains a handful of leaves that repeat a sefariaRef (e.g. an
        // index entry referencing the same underlying text via two paths).
        final materialized = await repo.getContentForCurriculum(c);
        final materializedLeaves = materialized.where((i) => i.isLeaf).toList();
        final materializedLeafRefs = materializedLeaves
            .map((i) => i.sefariaRef)
            .toSet();
        final coldRefs = coldLeaves.map((i) => i.sefariaRef).toSet();

        expect(
          coldRefs.length == materializedLeafRefs.length &&
              coldRefs.difference(materializedLeafRefs).isEmpty,
          isTrue,
          reason:
              '${c.storageKey}: cold loadLeavesTransient sefariaRefs must '
              'equal materialized leaf sefariaRefs',
        );
        expect(
          coldLeaves.length,
          materializedLeaves.length,
          reason:
              '${c.storageKey}: coldLeaves row count must equal the raw '
              '(non-deduped) materialized leaf row count',
        );

        // WARM path: curriculum is now cached (by the getContentForCurriculum
        // call above); loadLeavesTransient must still match.
        final warmLeaves = await repo.loadLeavesTransient(c);
        final warmRefs = warmLeaves.map((i) => i.sefariaRef).toSet();
        expect(
          warmRefs.length == materializedLeafRefs.length &&
              warmRefs.difference(materializedLeafRefs).isEmpty,
          isTrue,
          reason:
              '${c.storageKey}: warm (cache-backed) loadLeavesTransient must '
              'match materialized leaf sefariaRefs',
        );
      }
    },
  );

  test('union of loadLeavesTransient sefariaRefs across all 9 curricula == '
      '70,033 — matches the getContentForCurriculum-based union pinned in '
      'content_repository_count_leaves_test.dart', () async {
    final repo = _DiskContentRepository();

    final unionRefs = <String>{};
    for (final c in CurriculumId.values) {
      final leaves = await repo.loadLeavesTransient(c);
      unionRefs.addAll(leaves.map((i) => i.sefariaRef));
    }

    expect(
      unionRefs.length,
      70033,
      reason:
          'the header denominator ("X / 70,033 sections") must remain '
          'exactly what it was before this rewiring',
    );
  });
}
