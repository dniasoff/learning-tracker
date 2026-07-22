import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/services/lifetime_tree_builder.dart';

import '../../../../fixtures/collision_fixtures.dart';

/// Systemic sweep of the child-data-integrity guard (TEA-002 / R1).
///
/// The original P0 escapes over-counted a child's lifetime total because a
/// scope mark on one parent (e.g. daf "2" of Berakhos) credited EVERY parent
/// that happened to share that level-N id (daf "2" of Shabbos, ...). One
/// regression test guarded the specific Berakhos/Shabbos shape; this sweep
/// generalises the guard across EVERY curriculum and EVERY hierarchy level at
/// which a same-level-id-across-parents collision genuinely occurs, so the
/// NEXT colliding curriculum shape is caught structurally.
///
/// Each scenario asserts BOTH directions so the suite goes red under either
/// failure mode:
///   * exact set equality — catches an authentic over-count (bare keying
///     collapses both parents into one bucket -> parent B's leaves inflate the
///     credited set) AND a read-only revert that yields under-credit; and
///   * an empty intersection with `mustNotCredit` — an explicit statement that
///     the collision victim (parent B) is never credited, so a pure inflation
///     regression cannot slip past a `contains(targetLeaf)`-style check.
void main() {
  const builder = LifetimeTreeBuilder();

  Set<String> credit(CollisionScenario s) => builder.computeLearnedLeafRefs(
    leaves: s.leaves,
    completedRefs: const {},
    ledgerEntries: s.ledger,
  );

  group('collision sweep — scope mark credits ONLY its targeted parent', () {
    for (final level in const [2, 3, 4]) {
      final scenarios = collisionScenariosForAllCurricula(
        collisionLevel: level,
      ).toList();

      for (final s in scenarios) {
        test('${s.curriculum.name} L$level: credits only the targeted parent', () {
          final got = credit(s);

          // Exact set — no inflation, no under-credit.
          expect(
            got,
            s.expectedCredited,
            reason:
                'L$level mark "${s.markUnitIdentifier}" (scope ${s.entryScope}) '
                'must credit exactly parent A\'s ${s.expectedCredited.length} '
                'leaves',
          );
          // The collision victim (parent B) must never be credited.
          expect(
            got.intersection(s.mustNotCredit),
            isEmpty,
            reason:
                'parent B shares the level-$level id but a different '
                'qualified id; its leaves must not be cross-credited',
          );
        });
      }
    }
  });

  group('collision sweep — coverage of CurriculumId.values', () {
    test('every curriculum is swept at >= 1 genuine collision level', () {
      for (final c in CurriculumId.values) {
        final levels = kCollisionProneLevels[c];
        expect(
          levels,
          isNotNull,
          reason: '$c missing from kCollisionProneLevels',
        );
        expect(
          levels,
          isNotEmpty,
          reason:
              '$c has no genuine collision level — if that is truly the case '
              'it must be documented, not silently absent',
        );
      }
    });

    test(
      'documented skips: levels where a cross-parent collision cannot occur',
      () {
        // These are the "skip, and say which" exclusions. Asserting them keeps
        // the documentation honest: if the data shape ever changes so one of
        // these DOES start colliding, this test fails and forces a re-review.
        bool collidesAt(CurriculumId c, int level) =>
            (kCollisionProneLevels[c] ?? const []).contains(level);

        // L1 is never swept (curriculum root / synthetic composite container).
        for (final c in CurriculumId.values) {
          expect(collidesAt(c, 1), isFalse, reason: '$c L1 must be excluded');
        }

        // L2 named-value curricula: masechta / hilchos / sefer names are
        // globally unique, so no two parents share a level2 id.
        for (final c in const [
          CurriculumId.bavli,
          CurriculumId.mishnayos,
          CurriculumId.yerushalmi,
          CurriculumId.mishnehTorah,
          CurriculumId.nach,
          CurriculumId.tanach,
        ]) {
          expect(
            collidesAt(c, 2),
            isFalse,
            reason: '$c L2 values are unique names — cannot collide',
          );
        }

        // Mishna Berurah has a single level1 sefer, so L2 has no sibling
        // parent to collide across (its real collision is L3).
        expect(
          collidesAt(CurriculumId.mishnaBerurah, 2),
          isFalse,
          reason:
              'mishna_berurah has one sefer -> no L2 cross-parent collision',
        );
        expect(collidesAt(CurriculumId.mishnaBerurah, 3), isTrue);
      },
    );
  });

  group(
    'collision sweep — curriculum-native scope alias funnels correctly',
    () {
      test('a "daf" mark (native L3 alias) credits like a "level3" mark', () {
        // The read-side switch maps native labels (daf/perek/masechta/amud/…)
        // and generic level$N into the SAME bucket. Prove the alias path stays
        // qualified and does not cross-credit the colliding sibling.
        final s = buildCollisionScenario(
          curriculum: CurriculumId.bavli,
          collisionLevel: 3,
          entryScope: kNativeScopeLabelSample[3], // 'daf'
        );
        expect(s.entryScope, 'daf');

        final got = credit(s);
        expect(got, s.expectedCredited);
        expect(got.intersection(s.mustNotCredit), isEmpty);
      });
    },
  );
}
