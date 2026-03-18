import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/features/progress/presentation/providers/journey_providers.dart';
import 'package:test/test.dart';

void main() {
  group('LedgerEntry', () {
    test('creates with all required fields', () {
      final entry = LedgerEntry(
        curriculumId: 'mishnayos',
        unitType: 'masechta',
        unitIdentifier: 'Berakhot',
        unitDisplayNameHe: 'ברכות',
        unitDisplayNameEn: 'Berakhot',
        trackType: 'personal',
        completedAt: DateTime(2026, 1, 1),
        completionNumber: 1,
        isManual: false,
      );

      expect(entry.curriculumId, 'mishnayos');
      expect(entry.unitIdentifier, 'Berakhot');
      expect(entry.trackType, 'personal');
      expect(entry.completionNumber, 1);
      expect(entry.isManual, false);
    });
  });

  group('JourneySortModeValue', () {
    test('toggle between grouped and chronological', () {
      var mode = JourneySortModeValue.grouped;

      // Toggle to chronological
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.chronological);

      // Toggle back to grouped
      mode = mode == JourneySortModeValue.grouped
          ? JourneySortModeValue.chronological
          : JourneySortModeValue.grouped;
      expect(mode, JourneySortModeValue.grouped);
    });
  });
}
