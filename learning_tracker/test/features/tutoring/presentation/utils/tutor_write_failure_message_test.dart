// tutorWriteFailureMessage — AD-53 / DNI-487 AC-6.

import 'package:flutter_test/flutter_test.dart';
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
}
