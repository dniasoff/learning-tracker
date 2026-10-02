// tutorWriteFailureMessage — AD-53 / DNI-487 AC-6.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/utils/tutor_write_failure_message.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

void main() {
  const turnedOff = TutorWriteEditingTurnedOff(
    message: 'Grant lacks can_edit_learning',
  );

  test('editing turned off names the learner (en + he)', () {
    expect(
      tutorWriteFailureMessage(
        AppLocalizationsEn(),
        turnedOff,
        learnerName: 'Dina',
      ),
      "Dina's parent has turned off editing",
    );
    expect(
      tutorWriteFailureMessage(
        AppLocalizationsHe(),
        turnedOff,
        learnerName: 'דינה',
      ),
      'ההורה של דינה כיבה את העריכה',
    );
  });

  test('any other failure keeps the generic permission copy', () {
    expect(
      tutorWriteFailureMessage(
        AppLocalizationsEn(),
        const TutorWriteFailure(message: 'x', code: 'permission-denied'),
        learnerName: 'Dina',
      ),
      "You don't have permission to make this edit",
    );
  });

  group('DNI-486 surfaces', () {
    final en = AppLocalizationsEn();

    test('tutorEditingTurnedOffText names the learner, falling back to '
        'the generic copy for an unknown or blank name', () {
      expect(
        tutorEditingTurnedOffText(en, learnerName: ' Dina '),
        "Dina's parent has turned off editing",
      );
      expect(
        tutorEditingTurnedOffText(en),
        "You don't have permission to make this edit",
      );
      expect(
        tutorEditingTurnedOffText(en, learnerName: '  '),
        "You don't have permission to make this edit",
      );
    });

    test('tutorSaveErrorText: a governed save refused because editing was '
        'turned off — by the callable or by the preflight — names it', () {
      for (final error in [
        const TutorGovernedWriteException(failure: turnedOff),
        const TutorGovernedWriteException(
          refusal: TutorPreflightNoEditAccess(),
        ),
      ]) {
        expect(
          tutorSaveErrorText(
            en,
            error,
            fallback: 'Failed',
            learnerName: 'Dina',
          ),
          "Dina's parent has turned off editing",
        );
      }
    });

    test('tutorSaveErrorText keeps the form\'s own error for anything '
        'else', () {
      for (final error in <Object>[
        const TutorGovernedWriteException(
          failure: TutorWriteFailure(message: 'x', code: 'internal'),
        ),
        const TutorGovernedWriteException(refusal: TutorPreflightOffline()),
        StateError('boom'),
      ]) {
        expect(
          tutorSaveErrorText(en, error, fallback: 'Failed', learnerName: 'D'),
          'Failed',
        );
      }
    });
  });
}
