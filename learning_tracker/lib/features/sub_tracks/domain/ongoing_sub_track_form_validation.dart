/// Validation and mapping of the ongoing sub-track form (Story 2.5 /
/// DNI-496 AC-3, AC-5, AC-6; UX-DR-80).
///
/// - A blank name, and a rate or weeks value that is not a positive finite
///   number, are inline field errors.
/// - An omitted start date is the learner's civil today (AD-41; the caller
///   passes the date in the profile's `time_zone`, never device midnight);
///   an omitted end date is `null` (an open window).
/// - Only `window_end < window_start` is invalid: equal dates are a one-day
///   window, and an end date in the past is allowed (it ends the sub-track's
///   activity, Story 2.2).
/// - The ongoing usage count reuses the shared AD-45 predicate
///   [countsTowardSubTrackLimits], so the form and `LearningCommands` agree.
///
/// The form never computes `onHome`, `holdsGround`, `inForecast`, capacity
/// or the daily target: those are derived by the engine (Stories 2.2/2.3)
/// from the values written here.
///
/// Pure Dart, so the rules are unit-testable without widgets.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/domain/learner_state/sub_track_validator.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';

/// The fields of the ongoing form that can carry an inline error.
enum OngoingFormField {
  /// "Sub-track name".
  name,

  /// The rate stepper.
  rate,

  /// "Weeks per year".
  weeks,

  /// "End date (optional)".
  end,
}

/// Why a field is invalid.
enum OngoingFormError {
  /// The name is blank or whitespace.
  nameRequired,

  /// Not a positive finite number.
  notPositive,

  /// The end date is before the start date.
  endBeforeStart,
}

/// The raw values of the ongoing form, as entered.
final class OngoingSubTrackFormInput {
  /// Creates the input.
  const OngoingSubTrackFormInput({
    required this.name,
    required this.rateText,
    required this.weeksText,
    required this.learnsOnShabbos,
    this.start,
    this.end,
  });

  /// The name field's text.
  final String name;

  /// The rate field's text (leaf units per week).
  final String rateText;

  /// The weeks field's text.
  final String weeksText;

  /// The chosen start date, or null when omitted.
  final CivilDate? start;

  /// The chosen end date, or null when omitted (open).
  final CivilDate? end;

  /// The "Learns on shabbos / yom tov" switch.
  final bool learnsOnShabbos;
}

/// The validated values of an ongoing sub-track, ready to write.
final class OngoingSubTrackValues {
  /// Creates the values.
  const OngoingSubTrackValues({
    required this.name,
    required this.ratePerWeek,
    required this.weeksPerYear,
    required this.windowStart,
    required this.windowEnd,
    required this.learnsOnShabbos,
  });

  /// Trimmed name.
  final String name;

  /// Leaf units per week, > 0.
  final double ratePerWeek;

  /// Weeks per year, > 0.
  final double weeksPerYear;

  /// Inclusive window start.
  final CivilDate windowStart;

  /// Inclusive window end; null = open.
  final CivilDate? windowEnd;

  /// The shabbos flag.
  final bool learnsOnShabbos;

  /// The `createSubTrack` draft for [curriculumId]: `type = ongoing`, no
  /// academic year and an empty ground (added later, Story 2.6).
  SubTrackDraft toDraft(String curriculumId) => SubTrackDraft(
    curriculumId: curriculumId,
    name: name,
    type: SubTrackType.ongoing,
    windowStart: windowStart,
    windowEnd: windowEnd,
    ratePerWeek: ratePerWeek,
    weeksPerYear: weeksPerYear,
    learnsOnShabbos: learnsOnShabbos,
    ground: const [],
  );

  /// The `editSubTrack` change from [current] to these values: only the
  /// fields that differ, or null when nothing changed (AC-6).
  SubTrackEdit? editFrom(SubTrack current) {
    final nameChanged = name != current.name;
    final rateChanged = ratePerWeek != current.ratePerWeek;
    final weeksChanged = weeksPerYear != current.weeksPerYear;
    final startChanged = windowStart != current.windowStart;
    final endChanged = windowEnd != current.windowEnd;
    final shabbosChanged = learnsOnShabbos != current.learnsOnShabbos;
    if (!(nameChanged ||
        rateChanged ||
        weeksChanged ||
        startChanged ||
        endChanged ||
        shabbosChanged)) {
      return null;
    }
    return SubTrackEdit(
      name: nameChanged ? name : null,
      ratePerWeek: rateChanged ? ratePerWeek : null,
      weeksPerYear: weeksChanged ? weeksPerYear : null,
      windowStart: startChanged ? windowStart : null,
      windowEnd: endChanged ? windowEnd : null,
      clearWindowEnd: endChanged && windowEnd == null,
      learnsOnShabbos: shabbosChanged ? learnsOnShabbos : null,
    );
  }
}

/// The result of validating one [OngoingSubTrackFormInput].
final class OngoingFormValidation {
  /// Creates the result.
  const OngoingFormValidation({required this.errors, this.values});

  /// The inline error of each invalid field.
  final Map<OngoingFormField, OngoingFormError> errors;

  /// The values to write; non-null exactly when [errors] is empty.
  final OngoingSubTrackValues? values;

  /// Whether the form may be saved.
  bool get isValid => errors.isEmpty;
}

/// Validates [input] and maps it to storage values, defaulting an omitted
/// start date to the learner's civil [today] (AC-3).
OngoingFormValidation validateOngoingSubTrackForm(
  OngoingSubTrackFormInput input, {
  required CivilDate today,
}) {
  assert(isCivilDate(today), 'today must be YYYY-MM-DD');
  final errors = <OngoingFormField, OngoingFormError>{};
  final name = input.name.trim();
  if (name.isEmpty)
    errors[OngoingFormField.name] = OngoingFormError.nameRequired;
  final rate = parsePositiveOngoingNumber(input.rateText);
  if (rate == null)
    errors[OngoingFormField.rate] = OngoingFormError.notPositive;
  final weeks = parsePositiveOngoingNumber(input.weeksText);
  if (weeks == null) {
    errors[OngoingFormField.weeks] = OngoingFormError.notPositive;
  }
  final start = input.start ?? today;
  final end = input.end;
  if (end != null && end.compareTo(start) < 0) {
    errors[OngoingFormField.end] = OngoingFormError.endBeforeStart;
  }
  if (errors.isNotEmpty) return OngoingFormValidation(errors: errors);
  return OngoingFormValidation(
    errors: const {},
    values: OngoingSubTrackValues(
      name: name,
      ratePerWeek: rate!,
      weeksPerYear: weeks!,
      windowStart: start,
      windowEnd: end,
      learnsOnShabbos: input.learnsOnShabbos,
    ),
  );
}

/// [text] as a positive finite number, or null. Surrounding whitespace is
/// ignored and a comma is accepted as the decimal separator.
double? parsePositiveOngoingNumber(String text) {
  final value = double.tryParse(text.trim().replaceAll(',', '.'));
  if (value == null || !value.isFinite || value <= 0) return null;
  return value;
}

/// How many ongoing sub-tracks of [curriculumId] count toward the AD-45
/// limit on [today] (non-ended, window not passed: `onHome` or
/// future-start). [subTracks] may hold any curriculum's rows, live or
/// ended; [excludingId] leaves out the sub-track being edited.
int ongoingSubTracksInUse(
  Iterable<SubTrack> subTracks, {
  required String curriculumId,
  required CivilDate today,
  String? excludingId,
}) => subTracks
    .where(
      (s) =>
          s.id != excludingId &&
          s.curriculumId == curriculumId &&
          s.type == SubTrackType.ongoing &&
          countsTowardSubTrackLimits(s, today),
    )
    .length;

/// Whether another ongoing sub-track may be created beside [inUse] counting
/// ones (AD-45 cap [kMaxOngoingSubTracks]).
bool ongoingCreateAllowed(int inUse) => inUse < kMaxOngoingSubTracks;

/// The form field a command-side AD-45 [limit] belongs to, or null when it
/// is not a field error (for example the ongoing cap).
OngoingFormField? ongoingFieldForViolation(SubTrackLimit limit) =>
    switch (limit) {
      SubTrackLimit.windowReversed => OngoingFormField.end,
      SubTrackLimit.nonPositiveRate => OngoingFormField.rate,
      SubTrackLimit.nonPositiveWeeks => OngoingFormField.weeks,
      _ => null,
    };
