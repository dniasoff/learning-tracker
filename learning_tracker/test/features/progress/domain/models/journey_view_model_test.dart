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
      );
      expect(vm.curricula, isEmpty);
      expect(vm.totalCompletions, 0);
      expect(vm.totalUniqueUnits, 0);
    });

    test('computes totals across curricula', () {
      final vm = JourneyViewModel(
        curricula: [
          CurriculumJourney(
            curriculumId: CurriculumId.mishnayos,
            completions: [
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
                trackType: TrackType.personal,
                completedAt: DateTime(2026, 1, 1),
                completionNumber: 1,
                isManual: false,
              ),
              UnitCompletion(
                unitIdentifier: 'Berakhot',
                unitType: 'masechta',
                displayNameHe: 'ברכות',
                displayNameEn: 'Berakhot',
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
      );

      expect(vm.totalCompletions, 2);
      expect(vm.totalUniqueUnits, 1);
      expect(vm.curricula.first.uniqueUnitsCompleted, 1);
      expect(vm.curricula.first.totalUnitsAvailable, 63);
    });
  });

  group('UnitCompletion', () {
    test('stores all fields correctly', () {
      final completion = UnitCompletion(
        unitIdentifier: 'Shabbat',
        unitType: 'masechta',
        displayNameHe: 'שבת',
        displayNameEn: 'Shabbat',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 3, 15),
        completionNumber: 1,
        isManual: true,
      );

      expect(completion.unitIdentifier, 'Shabbat');
      expect(completion.trackType, TrackType.personal);
      expect(completion.isManual, isTrue);
      expect(completion.completionNumber, 1);
    });

    test('equality works via freezed', () {
      final a = UnitCompletion(
        unitIdentifier: 'Berakhot',
        unitType: 'masechta',
        displayNameHe: 'ברכות',
        displayNameEn: 'Berakhot',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );
      final b = UnitCompletion(
        unitIdentifier: 'Berakhot',
        unitType: 'masechta',
        displayNameHe: 'ברכות',
        displayNameEn: 'Berakhot',
        trackType: TrackType.personal,
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );
      expect(a, equals(b));
    });
  });

  group('MilestoneAchievement', () {
    test('seder_complete type', () {
      final milestone = MilestoneAchievement(
        type: 'seder_complete',
        displayName: 'Seder Zeraim',
        achievedAt: DateTime(2026, 6, 1),
      );
      expect(milestone.type, 'seder_complete');
      expect(milestone.displayName, 'Seder Zeraim');
    });

    test('curriculum_complete type', () {
      final milestone = MilestoneAchievement(
        type: 'curriculum_complete',
        displayName: 'Mishnayos',
        achievedAt: DateTime(2026, 12, 1),
      );
      expect(milestone.type, 'curriculum_complete');
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
            displayName: 'Mishnayos',
            achievedAt: DateTime(2026, 12, 25),
          ),
        ],
      );

      expect(journey.milestones.length, 1);
      expect(journey.milestones.first.type, 'curriculum_complete');
    });
  });
}
