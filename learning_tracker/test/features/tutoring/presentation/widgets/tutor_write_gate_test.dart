// Story 1.24 (DNI-486) AC-4/AC-5 — the tutor write note copy and the
// visible-but-disabled control wrapper.

@Tags(['tutor_mode'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/widgets/tutor_write_gate.dart';
import 'package:learning_tracker/l10n/app_localizations_en.dart';
import 'package:learning_tracker/l10n/app_localizations_he.dart';

import '../../../../helpers/pump_app.dart';

void main() {
  final en = AppLocalizationsEn();
  final he = AppLocalizationsHe();

  test('note copy per availability, in English and Hebrew', () {
    expect(
      tutorWriteNoteText(
        en,
        TutorWriteAvailability.noEditAccess,
        learnerName: 'Yossi',
      ),
      "Yossi's parent hasn't given you editing access",
    );
    expect(
      tutorWriteNoteText(
        he,
        TutorWriteAvailability.noEditAccess,
        learnerName: 'יוסי',
      ),
      contains('יוסי'),
    );
    expect(
      tutorWriteNoteText(en, TutorWriteAvailability.offline),
      'Online required',
    );
    expect(tutorWriteNoteText(he, TutorWriteAvailability.offline), isNotEmpty);
    for (final none in [
      TutorWriteAvailability.owner,
      TutorWriteAvailability.available,
      TutorWriteAvailability.locked,
    ]) {
      expect(tutorWriteNoteText(en, none), isNull, reason: none.name);
    }
  });

  test('an unknown learner name falls back to the generic permission copy', () {
    expect(
      tutorWriteNoteText(en, TutorWriteAvailability.noEditAccess),
      en.tutorPermissionDenied,
    );
  });

  testWidgets('an unblocked control is untouched', (tester) async {
    await tester.pumpWidget(
      pumpApp(
        child: const TutorDisabledControl(blocked: false, child: Text('Save')),
      ),
    );
    expect(find.byKey(const Key('tutorDisabledControl')), findsNothing);
    expect(find.text('Save'), findsOneWidget);
  });

  testWidgets('a blocked control is visible at 40% and absorbs taps', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      pumpApp(
        child: TutorDisabledControl(
          blocked: true,
          child: TextButton(onPressed: () => taps++, child: const Text('Save')),
        ),
      ),
    );
    expect(find.text('Save'), findsOneWidget);
    expect(
      tester
          .widget<Opacity>(find.byKey(const Key('tutorDisabledControl')))
          .opacity,
      tutorDisabledControlOpacity,
    );
    await tester.tap(find.text('Save'), warnIfMissed: false);
    expect(taps, 0);
  });
}
