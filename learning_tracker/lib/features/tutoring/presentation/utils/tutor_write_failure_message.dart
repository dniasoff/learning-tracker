// tutorWriteFailureMessage — AD-53 / Story 1.25 (DNI-487 AC-6)
//
// The single place that turns a failed tutor write into user-facing copy.
// A write rejected because the parent turned off "Can edit learning" shows
// "{learner}'s parent has turned off editing"; every other failure keeps the
// generic permission-denied copy. Tutor write surfaces (Story 1.24 / DNI-486)
// call this with the result of a TutorWriteService call.

import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Localized message for a [TutorWriteFailure] on [learnerName]'s profile.
String tutorWriteFailureMessage(
  AppLocalizations l10n,
  TutorWriteFailure failure, {
  required String learnerName,
}) => switch (failure) {
  TutorWriteEditingTurnedOff() => l10n.tutorEditingTurnedOff(learnerName),
  _ => l10n.tutorPermissionDenied,
};
