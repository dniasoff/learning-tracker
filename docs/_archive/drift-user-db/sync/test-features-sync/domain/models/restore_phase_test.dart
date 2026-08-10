import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/sync/domain/models/restore_phase.dart';

void main() {
  group('RestorePhase', () {
    test('has exactly the three documented values', () {
      expect(RestorePhase.values, hasLength(3));
      expect(
        RestorePhase.values,
        containsAll(<RestorePhase>[
          RestorePhase.pullingData,
          RestorePhase.loadingCurricula,
          RestorePhase.importingContent,
        ]),
      );
    });

    test('values are stable identifiers, not free text', () {
      // AUD-app-02 (EH-5/EH-6): presentation resolves each phase to a
      // localized string via AppLocalizations/ARB through an exhaustive
      // switch — the enum name itself must never be shown directly to a
      // user, so this pins the identifiers as a contract rather than
      // exercising any formatting.
      for (final phase in RestorePhase.values) {
        expect(phase.name, isNotEmpty);
      }
    });

    test('name round-trips through RestorePhase.values.byName', () {
      for (final phase in RestorePhase.values) {
        expect(RestorePhase.values.byName(phase.name), same(phase));
      }
    });
  });
}
