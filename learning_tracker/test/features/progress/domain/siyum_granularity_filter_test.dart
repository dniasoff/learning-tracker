// Unit tests for the siyum-granularity gate — the CORE of the feature.
//
// `filterMilestonesByGranularity` is a pure suppression filter over
// already-emitted milestones. These tests build a milestone set that spans all
// three tiers (unit + aggregate + curriculum) and assert the gate keeps
// exactly the tiers at-or-coarser-than the chosen one.
//
// RED-DEMO (see the "SUPPRESSION" test): neuter
// `filterMilestonesByGranularity` to `return milestones;` and the two
// suppression assertions below FAIL (unit rows leak through at chosen=aggregate;
// unit + aggregate rows leak through at chosen=curriculum). Restore the
// `.where(...)` body and they pass again — proving the assertions actually
// exercise the suppression, not a tautology.
@Tags(['progress'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/domain/siyum_granularity_filter.dart';

MilestoneAchievement _milestone(MilestoneLevel level) => MilestoneAchievement(
  type: switch (level) {
    MilestoneLevel.unit => 'unit_complete',
    MilestoneLevel.aggregate => 'seder_complete',
    MilestoneLevel.curriculum => 'curriculum_complete',
  },
  level: level,
  curriculumId: CurriculumId.mishnayos,
  displayName: level.name,
  achievedAt: DateTime(2026, 1, 1),
);

void main() {
  group('milestoneLevelRank', () {
    test('ranks finest → coarsest 0/1/2', () {
      expect(milestoneLevelRank(MilestoneLevel.unit), 0);
      expect(milestoneLevelRank(MilestoneLevel.aggregate), 1);
      expect(milestoneLevelRank(MilestoneLevel.curriculum), 2);
    });
  });

  group('filterMilestonesByGranularity — all three tiers present', () {
    final all = [
      _milestone(MilestoneLevel.unit),
      _milestone(MilestoneLevel.aggregate),
      _milestone(MilestoneLevel.curriculum),
    ];

    List<MilestoneLevel> levelsOf(List<MilestoneAchievement> ms) =>
        ms.map((m) => m.level).toList();

    test('chosen = unit → all tiers survive (default behaviour)', () {
      final out = filterMilestonesByGranularity(all, MilestoneLevel.unit);
      expect(
        levelsOf(out),
        containsAll(<MilestoneLevel>[
          MilestoneLevel.unit,
          MilestoneLevel.aggregate,
          MilestoneLevel.curriculum,
        ]),
      );
      expect(out, hasLength(3));
    });

    test(
      'SUPPRESSION — chosen = aggregate → unit suppressed, rest survive',
      () {
        final out = filterMilestonesByGranularity(
          all,
          MilestoneLevel.aggregate,
        );
        // This is the red-demo assertion: with the filter neutered, the unit
        // milestone leaks through and this fails.
        expect(
          levelsOf(out),
          isNot(contains(MilestoneLevel.unit)),
          reason: 'unit-level siyumim must be suppressed at chosen=aggregate',
        );
        expect(
          levelsOf(out),
          containsAll(<MilestoneLevel>[
            MilestoneLevel.aggregate,
            MilestoneLevel.curriculum,
          ]),
        );
        expect(out, hasLength(2));
      },
    );

    test(
      'SUPPRESSION — chosen = curriculum → only the whole siyum survives',
      () {
        final out = filterMilestonesByGranularity(
          all,
          MilestoneLevel.curriculum,
        );
        // Red-demo assertion: with the filter neutered, unit + aggregate leak.
        expect(
          levelsOf(out),
          isNot(contains(MilestoneLevel.unit)),
          reason: 'unit-level siyumim must be suppressed at chosen=curriculum',
        );
        expect(
          levelsOf(out),
          isNot(contains(MilestoneLevel.aggregate)),
          reason:
              'aggregate-level siyumim must be suppressed at chosen=curriculum',
        );
        expect(levelsOf(out), [MilestoneLevel.curriculum]);
      },
    );
  });

  group('safety — the gate can only ever suppress, never fabricate', () {
    test(
      'filtering at unit is the identity (default-behaviour equivalence)',
      () {
        final all = [
          _milestone(MilestoneLevel.curriculum),
          _milestone(MilestoneLevel.unit),
          _milestone(MilestoneLevel.aggregate),
          _milestone(MilestoneLevel.unit),
        ];
        final out = filterMilestonesByGranularity(all, MilestoneLevel.unit);
        expect(
          out,
          all,
          reason:
              'default (unit) must return the exact input list — no additions, '
              'no reordering, no drops — so an unset preference is behaviour-'
              'identical to before the gate existed.',
        );
      },
    );

    test('output is always a subset of the input at every chosen tier', () {
      final all = [
        _milestone(MilestoneLevel.unit),
        _milestone(MilestoneLevel.aggregate),
        _milestone(MilestoneLevel.curriculum),
      ];
      for (final chosen in MilestoneLevel.values) {
        final out = filterMilestonesByGranularity(all, chosen);
        expect(
          out.length,
          lessThanOrEqualTo(all.length),
          reason: 'the gate never grows the list',
        );
        for (final m in out) {
          expect(
            all,
            contains(m),
            reason: 'every kept row came from the input',
          );
        }
      }
    });

    test('empty input yields empty output at every tier', () {
      for (final chosen in MilestoneLevel.values) {
        expect(filterMilestonesByGranularity(const [], chosen), isEmpty);
      }
    });
  });
}
