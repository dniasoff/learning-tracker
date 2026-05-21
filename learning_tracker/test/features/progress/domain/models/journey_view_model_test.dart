import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/enums/track_type.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:test/test.dart';

void main() {
  group('JourneyViewModel', () {
    test('creates with empty curricula', () {
      const vm = JourneyViewModel(
        curricula: [],
        totalCompletions: 0,
        totalUniqueUnits: 0,
        unitLevelSiyumimCount: 0,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      );
      expect(vm.curricula, isEmpty);
      expect(vm.totalCompletions, 0);
      expect(vm.totalUniqueUnits, 0);
      expect(vm.unitLevelSiyumimCount, 0);
      expect(vm.aggregateLevelSiyumimCount, 0);
      expect(vm.curriculumLevelSiyumimCount, 0);
    });

    test('computes totals across curricula', () {
      final vm = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                entryScope: 'masechta',
                entryKey: 'Berakhot',
                parentL1Key: 'Zeraim',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 1, 1),
                completionNumber: 1,
                isManual: false,
              ),
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                entryScope: 'masechta',
                entryKey: 'Berakhot',
                parentL1Key: 'Zeraim',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 2, 1),
                completionNumber: 2,
                isManual: false,
              ),
            ],
            uniqueUnitsCompleted: 1,
            totalUnitsAvailable: 63,
            milestones: [],
          ),
        ],
        totalCompletions: 2,
        totalUniqueUnits: 1,
        unitLevelSiyumimCount: 0,
        aggregateLevelSiyumimCount: 0,
        curriculumLevelSiyumimCount: 0,
      );

      expect(vm.totalCompletions, 2);
      expect(vm.totalUniqueUnits, 1);
      expect(vm.curricula.first.uniqueUnitsCompleted, 1);
      expect(vm.curricula.first.totalUnitsAvailable, 63);
    });

    test('carries the three-level breakdown counters', () {
      const vm = JourneyViewModel(
        curricula: [],
        totalCompletions: 0,
        totalUniqueUnits: 0,
        unitLevelSiyumimCount: 11,
        aggregateLevelSiyumimCount: 1,
        curriculumLevelSiyumimCount: 0,
      );
      expect(vm.unitLevelSiyumimCount, 11);
      expect(vm.aggregateLevelSiyumimCount, 1);
      expect(vm.curriculumLevelSiyumimCount, 0);
    });

    // F21 — defense in depth for the freezed-generated `copyWith`. A bug in
    // the generated code (or a hand-written override) would silently drop
    // the new three-level counter fields on a copy and the rest of the test
    // suite wouldn't notice because every other test constructs the VM
    // directly via the factory. Roundtrip each new field individually so a
    // future copyWith regression surfaces here with a precise failure.
    group('copyWith — three-level counter roundtrip', () {
      const baseline = JourneyViewModel(
        curricula: [],
        totalCompletions: 5,
        totalUniqueUnits: 3,
        unitLevelSiyumimCount: 7,
        aggregateLevelSiyumimCount: 2,
        curriculumLevelSiyumimCount: 1,
      );

      test('copyWith(unitLevelSiyumimCount: 99) materialises the new value '
          'and preserves the other counters', () {
        final updated = baseline.copyWith(unitLevelSiyumimCount: 99);

        // The new value is reflected.
        expect(updated.unitLevelSiyumimCount, 99);

        // Every other field carries through untouched. The non-counter
        // fields are also checked so a copyWith bug that swapped fields
        // (e.g. assigned the unit count to the aggregate count) surfaces
        // here, not just in a unit-level regression.
        expect(updated.aggregateLevelSiyumimCount, 2);
        expect(updated.curriculumLevelSiyumimCount, 1);
        expect(updated.totalCompletions, 5);
        expect(updated.totalUniqueUnits, 3);
        expect(updated.curricula, isEmpty);
      });

      test('copyWith(aggregateLevelSiyumimCount: 99) materialises the new '
          'value and preserves the other counters', () {
        final updated = baseline.copyWith(aggregateLevelSiyumimCount: 99);

        expect(updated.aggregateLevelSiyumimCount, 99);
        expect(updated.unitLevelSiyumimCount, 7);
        expect(updated.curriculumLevelSiyumimCount, 1);
        expect(updated.totalCompletions, 5);
        expect(updated.totalUniqueUnits, 3);
      });

      test('copyWith(curriculumLevelSiyumimCount: 99) materialises the new '
          'value and preserves the other counters', () {
        final updated = baseline.copyWith(curriculumLevelSiyumimCount: 99);

        expect(updated.curriculumLevelSiyumimCount, 99);
        expect(updated.unitLevelSiyumimCount, 7);
        expect(updated.aggregateLevelSiyumimCount, 2);
        expect(updated.totalCompletions, 5);
        expect(updated.totalUniqueUnits, 3);
      });

      test('all three counters can be updated in a single copyWith call', () {
        final updated = baseline.copyWith(
          unitLevelSiyumimCount: 10,
          aggregateLevelSiyumimCount: 20,
          curriculumLevelSiyumimCount: 30,
        );
        expect(updated.unitLevelSiyumimCount, 10);
        expect(updated.aggregateLevelSiyumimCount, 20);
        expect(updated.curriculumLevelSiyumimCount, 30);
        // Equality with the freezed-generated == catches any silent field
        // mix-up that the individual getters might miss.
        expect(
          updated,
          equals(
            const JourneyViewModel(
              curricula: [],
              totalCompletions: 5,
              totalUniqueUnits: 3,
              unitLevelSiyumimCount: 10,
              aggregateLevelSiyumimCount: 20,
              curriculumLevelSiyumimCount: 30,
            ),
          ),
        );
      });
    });
  });

  group('UnitCompletion', () {
    test('stores structural keys correctly', () {
      final completion = UnitCompletion(
        unitIdentifier: 'Shabbat',
        entryScope: 'masechta',
        entryKey: 'Shabbat',
        parentL1Key: 'Moed',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 3, 15),
        completionNumber: 1,
        isManual: true,
      );

      expect(completion.unitIdentifier, 'Shabbat');
      expect(completion.entryScope, 'masechta');
      expect(completion.entryKey, 'Shabbat');
      expect(completion.parentL1Key, 'Moed');
      expect(completion.trackType, TrackType.personal);
      expect(completion.isManual, isTrue);
      expect(completion.completionNumber, 1);
    });

    test('equality works via freezed', () {
      final a = UnitCompletion(
        unitIdentifier: 'Berakhot',
        entryScope: 'masechta',
        entryKey: 'Berakhot',
        parentL1Key: 'Zeraim',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );
      final b = UnitCompletion(
        unitIdentifier: 'Berakhot',
        entryScope: 'masechta',
        entryKey: 'Berakhot',
        parentL1Key: 'Zeraim',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );
      expect(a, equals(b));
    });

    test('parentL1Key is null for seder-level entries', () {
      final completion = UnitCompletion(
        unitIdentifier: 'Zeraim',
        entryScope: 'seder',
        entryKey: 'Zeraim',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );
      expect(completion.parentL1Key, isNull);
    });
  });

  group('unitCompletionLevel', () {
    test('seder maps to level 1', () {
      expect(unitCompletionLevel('seder'), 1);
    });

    test('book maps to level 1', () {
      expect(unitCompletionLevel('book'), 1);
    });

    test('masechta maps to level 2', () {
      expect(unitCompletionLevel('masechta'), 2);
    });

    test('sefer maps to level 2', () {
      expect(unitCompletionLevel('sefer'), 2);
    });

    test('unknown scope defaults to level 2', () {
      expect(unitCompletionLevel('unknown'), 2);
    });
  });

  group('MilestoneAchievement', () {
    test('aggregate-level milestone', () {
      final milestone = MilestoneAchievement(
        type: 'seder_complete',
        level: MilestoneLevel.aggregate,
        curriculumId: CurriculumId.mishnayos,
        displayName: 'Zeraim',
        aggregateKey: 'Zeraim',
        containedUnitKeys: ['Berakhot', 'Peah', 'Demai'],
        achievedAt: DateTime(2026, 6, 1),
      );
      expect(milestone.type, 'seder_complete');
      expect(milestone.level, MilestoneLevel.aggregate);
      expect(milestone.curriculumId, CurriculumId.mishnayos);
      expect(milestone.aggregateKey, 'Zeraim');
      expect(milestone.containedUnitKeys, ['Berakhot', 'Peah', 'Demai']);
    });

    test('curriculum-level milestone', () {
      final milestone = MilestoneAchievement(
        type: 'curriculum_complete',
        level: MilestoneLevel.curriculum,
        curriculumId: CurriculumId.mishnayos,
        displayName: 'Mishnayos',
        achievedAt: DateTime(2026, 12, 1),
      );
      expect(milestone.type, 'curriculum_complete');
      expect(milestone.level, MilestoneLevel.curriculum);
      expect(milestone.containedUnitKeys, isEmpty);
    });

    test('unit-level milestone carries scope and parent', () {
      final milestone = MilestoneAchievement(
        type: 'unit_complete',
        level: MilestoneLevel.unit,
        curriculumId: CurriculumId.bavli,
        displayName: 'Berakhot',
        unitKey: 'Berakhot',
        unitScope: 'masechta',
        parentAggregateKey: 'Zeraim',
        achievedAt: DateTime(2026, 5, 4),
      );
      expect(milestone.level, MilestoneLevel.unit);
      expect(milestone.unitScope, 'masechta');
      expect(milestone.parentAggregateKey, 'Zeraim');
    });
  });

  group('JourneySortModeValue', () {
    test('has grouped and chronological values', () {
      expect(JourneySortModeValue.values.length, 2);
      expect(JourneySortModeValue.grouped, isNotNull);
      expect(JourneySortModeValue.chronological, isNotNull);
    });
  });

  group('CurriculumJourney', () {
    test('progress calculation', () {
      const journey = CurriculumJourney(
        curriculumId: CurriculumId.bavli,
        completions: [],
        uniqueUnitsCompleted: 10,
        totalUnitsAvailable: 37,
        milestones: [],
      );

      final progress =
          journey.uniqueUnitsCompleted / journey.totalUnitsAvailable;
      expect(progress, closeTo(0.27, 0.01));
    });

    test('milestone detection stored correctly', () {
      final journey = CurriculumJourney(
        curriculumId: CurriculumId.mishnayos,
        completions: [],
        uniqueUnitsCompleted: 63,
        totalUnitsAvailable: 63,
        milestones: [
          MilestoneAchievement(
            type: 'curriculum_complete',
            level: MilestoneLevel.curriculum,
            curriculumId: CurriculumId.mishnayos,
            displayName: 'Mishnayos',
            achievedAt: DateTime(2026, 12, 25),
          ),
        ],
      );

      expect(journey.milestones.length, 1);
      expect(journey.milestones.first.type, 'curriculum_complete');
      expect(journey.milestones.first.level, MilestoneLevel.curriculum);
    });
  });
}
