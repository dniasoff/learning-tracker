/// Property-based collision fixtures for the child-data-integrity guard (R1).
///
/// Background (TEA-002): three P0 escapes shipped where a child's lifetime
/// total over-counted (~3.8x) because content leaves that share a level-N id
/// across DIFFERENT parents — daf "2" in different masechtos, perek "1" in
/// different sedarim — collided in scope-id keying. The bug was fixed by
/// ancestor-qualifying the scope id (`scopeUnitIdentifier`, content_grouping)
/// and matching against the leaf's qualified id at read time
/// (`LifetimeTreeBuilder.computeLearnedLeafRefs`). But every legacy test
/// fixture used GLOBALLY-UNIQUE ids, so the collision was structurally
/// invisible — the next colliding curriculum shape would not be caught.
///
/// This file builds, for a given curriculum + collision level, a MINIMAL
/// two-parent shape in which both parents carry a child with the SAME level-N
/// value, then a single scope mark targeting parent A. It drives the PURE
/// `LifetimeTreeBuilder.computeLearnedLeafRefs` directly (no DB / no repo), so
/// the sweep runs as fast unit tests.
///
/// The load-bearing detail: the mark's `unitIdentifier` is produced by the
/// REAL `scopeUnitIdentifier` seam (not a hardcoded literal). Reverting that
/// seam to the pre-fix bare form therefore collapses BOTH the stored id and
/// the read-time lookup key at once, reproducing the authentic over-count —
/// which is what makes the red-demo exercise inflation rather than merely
/// under-credit.
library;

import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/network/sefaria/models/content_item.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';

import 'content_fixtures.dart';

/// One synthetic collision scenario: two parents sharing a level-N id, plus a
/// single scope mark on parent A, with the exact expected credit outcome.
class CollisionScenario {
  const CollisionScenario({
    required this.curriculum,
    required this.collisionLevel,
    required this.entryScope,
    required this.markUnitIdentifier,
    required this.leaves,
    required this.ledger,
    required this.expectedCredited,
    required this.mustNotCredit,
  });

  /// The curriculum whose real hierarchy shape this scenario models.
  final CurriculumId curriculum;

  /// The 1-indexed hierarchy level at which the two parents' children collide
  /// (always >= 2 — level1 is the globally-unique curriculum root and is out
  /// of scope for this pure function, see [kCollisionProneLevels]).
  final int collisionLevel;

  /// The raw scope string on the ledger row (`'level$collisionLevel'` by
  /// default, or a curriculum-native alias like `'daf'`).
  final String entryScope;

  /// The ancestor-qualified `unitIdentifier` stored on the mark row — built
  /// via the real `scopeUnitIdentifier` seam from parent A's path.
  final String markUnitIdentifier;

  /// All leaves in the scenario: [leavesPerParent] under parent A and the same
  /// number under parent B, the two parents differing only at
  /// level-(collisionLevel-1) while sharing the same level-collisionLevel id.
  final List<ContentItem> leaves;

  /// The single positive scope-mark ledger row, targeting parent A.
  final List<LearningLedgerEntry> ledger;

  /// Parent A's leaf refs — the EXACT set a correct build must credit.
  final Set<String> expectedCredited;

  /// Parent B's leaf refs — the collision victims that must NEVER be credited
  /// by parent A's mark.
  final Set<String> mustNotCredit;
}

/// Ground-truth per-curriculum levels (>= 2) at which a same-level-id-across-
/// parents collision GENUINELY occurs in the bundled hierarchy data.
///
/// Verified by scanning `assets/content/hierarchy/*.json`: a level qualifies
/// iff some child value repeats under >= 2 DISTINCT parents. Levels that are
/// deliberately EXCLUDED (the "skip, and say which" requirement):
///
///   * Level 1 — always the curriculum root; globally unique, and for
///     composite curricula it is a synthetic container dropped by a separate
///     provider-layer P0 guard. Out of scope for this pure function.
///   * Named levels whose values are globally unique so a cross-parent
///     collision cannot arise: L2 masechta names (bavli, mishnayos,
///     yerushalmi), L2 hilchos names (mishneh_torah), L2 sefer names
///     (nach, tanach).
///   * mishna_berurah L2 (Siman): the curriculum has a SINGLE level1 sefer
///     ("Mishnah Berurah"), so there are no two distinct parents at level1 for
///     an L2 value to collide across; its real collision is L3 (Seif repeats
///     across Simanim).
///
/// Every curriculum still appears with >= 1 genuine collision level, so none
/// is skipped wholesale.
const Map<CurriculumId, List<int>> kCollisionProneLevels = {
  // level1=Sefer, level2=Perek (repeats across sefarim), level3=Pasuk.
  CurriculumId.chumash: [2, 3],
  // level1=Section, level2=Sefer (unique), level3=Perek, level4=Pasuk.
  CurriculumId.nach: [3, 4],
  // Composite: level1=Section (synthetic), level2=Sefer (unique),
  // level3=Perek, level4=Pasuk. No bundled JSON — modelled synthetically.
  CurriculumId.tanach: [3, 4],
  // level1=Seder, level2=Masechta (unique), level3=Perek, level4=Mishna.
  CurriculumId.mishnayos: [3, 4],
  // level1=Seder, level2=Masechta (unique), level3=Daf, level4=Amud.
  CurriculumId.bavli: [3, 4],
  // level1=Seder, level2=Masechta (unique), level3=Daf (leaf); depth 3.
  CurriculumId.yerushalmi: [3],
  // level1=Sefer, level2=Hilchos (unique), level3=Perek, level4=Halacha.
  CurriculumId.mishnehTorah: [3, 4],
  // Single level1 sefer -> no L2 collision; level2=Siman, level3=Seif.
  CurriculumId.mishnaBerurah: [3],
  // level1=Sefer (book), level2=Perek (repeats across books), + deeper (Tanya).
  CurriculumId.mussar: [2, 3, 4],
};

/// The curriculum-native `entryScope` alias for [level] (the label a real
/// write may store instead of the generic `'level$level'`). The read-side
/// switch funnels both into the same bucket; used by the alias-coverage test.
const Map<int, String> kNativeScopeLabelSample = {
  2: 'masechta',
  3: 'daf',
  4: 'amud',
};

/// The value at hierarchy [level] for a parent identified by [parentKey],
/// sharing all ancestors above (collisionLevel-1) and the colliding child id.
///
/// levels `1..collisionLevel-2` are a shared ancestor path (identical for both
/// parents); level `collisionLevel-1` is [parentKey] (the ONE differing
/// segment); level `collisionLevel` is [sharedChildId] (the colliding value).
List<String?> _levelPath({
  required int collisionLevel,
  required String parentKey,
  required String sharedChildId,
}) {
  final path = <String?>[null, null, null, null]; // level1..level4
  for (var lvl = 1; lvl <= collisionLevel; lvl++) {
    if (lvl == collisionLevel) {
      path[lvl - 1] = sharedChildId;
    } else if (lvl == collisionLevel - 1) {
      path[lvl - 1] = parentKey;
    } else {
      path[lvl - 1] = 'shared-L$lvl';
    }
  }
  return path;
}

/// Builds a [CollisionScenario] for [curriculum] at [collisionLevel].
///
/// Two parents (`parentAKey` / `parentBKey`) sit at level-(collisionLevel-1),
/// each carrying [leavesPerParent] leaves that share the SAME
/// level-collisionLevel id ([sharedChildId]). A single positive scope mark
/// targets parent A, its `unitIdentifier` built through the real
/// `scopeUnitIdentifier` seam. A correct build credits parent A's leaves
/// EXACTLY and none of parent B's.
///
/// [collisionLevel] must be >= 2 and a genuine collision level for the
/// curriculum (see [kCollisionProneLevels]); callers normally get it from the
/// sweep helpers rather than passing it directly.
///
/// [entryScope] overrides the row's scope string (defaults to the generic
/// `'level$collisionLevel'`); the alias test passes a curriculum-native label.
CollisionScenario buildCollisionScenario({
  required CurriculumId curriculum,
  int collisionLevel = 2,
  String sharedChildId = '2',
  String parentAKey = 'A',
  String parentBKey = 'B',
  int leavesPerParent = 2,
  String? entryScope,
}) {
  assert(collisionLevel >= 2, 'level1 is bare and out of scope');
  assert(leavesPerParent >= 1, 'need at least one leaf per parent');

  final storageKey = curriculum.storageKey;

  List<ContentItem> leavesFor(String parentKey, int sortBase) {
    final path = _levelPath(
      collisionLevel: collisionLevel,
      parentKey: parentKey,
      sharedChildId: sharedChildId,
    );
    return List.generate(leavesPerParent, (j) {
      return ContentItemFixtures.leaf(
        curriculumId: storageKey,
        level1: path[0]!,
        level2: path[1],
        level3: path[2],
        level4: path[3],
        // Distinct ref even though the level path is shared with siblings and
        // with parent B's leaves (leaves are identified by sefariaRef).
        sefariaRef: '$storageKey|$parentKey|$sharedChildId|leaf$j',
        sortOrder: sortBase + j,
      );
    });
  }

  final parentALeaves = leavesFor(parentAKey, 0);
  final parentBLeaves = leavesFor(parentBKey, 100);

  // Mark parent A THROUGH THE REAL SEAM — never a hardcoded literal.
  final parentAPath = _levelPath(
    collisionLevel: collisionLevel,
    parentKey: parentAKey,
    sharedChildId: sharedChildId,
  );
  final markUnitIdentifier = scopeUnitIdentifier(
    level: collisionLevel,
    level1: parentAPath[0],
    level2: parentAPath[1],
    level3: parentAPath[2],
    level4: parentAPath[3],
  );

  final scope = entryScope ?? 'level$collisionLevel';

  return CollisionScenario(
    curriculum: curriculum,
    collisionLevel: collisionLevel,
    entryScope: scope,
    markUnitIdentifier: markUnitIdentifier,
    leaves: [...parentALeaves, ...parentBLeaves],
    ledger: [
      LearningLedgerEntry(
        ulid: '01ARZ3NDEKTSV4RRFFQ69G5FB1',
        curriculumId: curriculum,
        entryScope: scope,
        unitIdentifier: markUnitIdentifier,
        unitDisplayNameHe: '',
        unitDisplayNameEn: '',
        trackType: 'personal',
        completedAt: DateTime.utc(2026, 1, 1, 12),
        completionNumber: 1,
        markedBy: '01ARZ3NDEKTSV4RRFFQ69G5FAV',
        isManual: false,
        source: CompletionSource.lifetimeOnly,
      ),
    ],
    expectedCredited: parentALeaves.map((l) => l.sefariaRef).toSet(),
    mustNotCredit: parentBLeaves.map((l) => l.sefariaRef).toSet(),
  );
}

/// Curricula (in canonical order) that genuinely exhibit a collision at
/// exactly [collisionLevel]. Curricula whose shape cannot collide at that
/// level (see [kCollisionProneLevels]) are skipped.
Iterable<CurriculumId> curriculaCollidingAtLevel(int collisionLevel) =>
    CurriculumId.values.where(
      (c) => (kCollisionProneLevels[c] ?? const []).contains(collisionLevel),
    );

/// One [CollisionScenario] per curriculum that genuinely collides at
/// [collisionLevel]. The sweep test iterates this for level in {2, 3, 4}.
Iterable<CollisionScenario> collisionScenariosForAllCurricula({
  int collisionLevel = 2,
}) => curriculaCollidingAtLevel(collisionLevel).map(
  (c) => buildCollisionScenario(curriculum: c, collisionLevel: collisionLevel),
);

/// Every genuine collision scenario across all curricula and all their
/// collision-prone levels (the exhaustive sweep set).
Iterable<CollisionScenario> allCollisionScenarios() sync* {
  for (final curriculum in CurriculumId.values) {
    for (final level in kCollisionProneLevels[curriculum] ?? const <int>[]) {
      yield buildCollisionScenario(
        curriculum: curriculum,
        collisionLevel: level,
      );
    }
  }
}
