// tutorWriteFailureMessage — AD-53 / Story 1.25 (DNI-487 AC-6)
//
// The single place that turns a failed tutor write into user-facing copy.
// A write rejected because the parent turned off "Can edit learning" shows
// "{learner}'s parent has turned off editing"; every other failure keeps the
// generic permission-denied copy. Tutor write surfaces (Story 1.24 / DNI-486)
// call this with the result of a TutorWriteService call.

import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
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

/// "{learner}'s parent has turned off editing" for [learnerName]; the
/// generic permission copy when the learner's name is unknown (DNI-487
/// AC-6, rendered by the Story 1.24 / DNI-486 surfaces).
String tutorEditingTurnedOffText(AppLocalizations l10n, {String? learnerName}) {
  final name = learnerName?.trim() ?? '';
  return name.isEmpty
      ? l10n.tutorPermissionDenied
      : l10n.tutorEditingTurnedOff(name);
}

/// The save-error copy of a failed tutor governed form save [error]: the
/// editing-turned-off copy when the parent switched off "Can edit learning"
/// (the callable's AD-53 refusal, or a preflight that found the grant
/// without it after the form was opened); [fallback] — the form's existing
/// save error — for anything else.
String tutorSaveErrorText(
  AppLocalizations l10n,
  Object error, {
  required String fallback,
  String? learnerName,
}) => switch (error) {
  TutorGovernedWriteException(failure: TutorWriteEditingTurnedOff()) ||
  TutorGovernedWriteException(
    refusal: TutorPreflightNoEditAccess(),
  ) => tutorEditingTurnedOffText(l10n, learnerName: learnerName),
  _ => fallback,
};
