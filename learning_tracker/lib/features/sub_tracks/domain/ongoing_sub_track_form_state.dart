/// The weeks-per-year prefill of the ongoing sub-track form (Story 2.5 /
/// DNI-496 AC-1, AC-2; UX-DR-80).
///
/// The "Not learning during bein hazmanim" switch is a form aid only: while
/// the parent has not typed a weeks value, it swaps the prefilled weeks
/// between [kOngoingWeeksPerYearDefault] and
/// [kOngoingWeeksPerYearBeinHazmanim]. Once the parent edits the weeks
/// field, the switch never overwrites it. The switch itself is never
/// persisted (FR-6): only `weeks_per_year` reaches the `SubTrack`.
///
/// Pure Dart, no Flutter, so the toggle rules are unit-testable without
/// widgets.
library;

/// Weeks per year prefilled while the bein-hazmanim switch is off
/// ([ASSUMPTION] AC-1: 52).
const kOngoingWeeksPerYearDefault = 52;

/// Weeks per year prefilled while the bein-hazmanim switch is on
/// ([ASSUMPTION per mock] AC-2: 44).
const kOngoingWeeksPerYearBeinHazmanim = 44;

/// The weeks field and the bein-hazmanim switch of one ongoing form.
final class OngoingWeeksPrefill {
  /// A state with explicit values.
  const OngoingWeeksPrefill({
    required this.notLearningBeinHazmanim,
    required this.weeksText,
    required this.weeksEditedByUser,
  });

  /// A new form: switch off, weeks prefilled at
  /// [kOngoingWeeksPerYearDefault], not edited (AC-1).
  const OngoingWeeksPrefill.initial()
    : notLearningBeinHazmanim = false,
      weeksText = '$kOngoingWeeksPerYearDefault',
      weeksEditedByUser = false;

  /// The edit form of a stored sub-track whose `weeks_per_year` is
  /// [storedWeeks].
  ///
  /// The switch is not stored, so it opens off; the stored value is the
  /// parent's own, so it counts as edited and the switch never overwrites
  /// it ([ASSUMPTION] recorded in DNI-496).
  factory OngoingWeeksPrefill.forStored(double storedWeeks) =>
      OngoingWeeksPrefill(
        notLearningBeinHazmanim: false,
        weeksText: formatOngoingNumber(storedWeeks),
        weeksEditedByUser: true,
      );

  /// Whether the bein-hazmanim switch is on.
  final bool notLearningBeinHazmanim;

  /// The weeks field's text, exactly as shown.
  final String weeksText;

  /// Whether the parent has typed in the weeks field.
  final bool weeksEditedByUser;

  /// Whether the weeks field shows the "Prefilled from bein hazmanim
  /// toggle" helper: only while the value is still the prefill.
  bool get showsPrefillHelper => !weeksEditedByUser;

  /// The switch set to [on]. Changes the weeks only while it is untouched.
  OngoingWeeksPrefill toggleBeinHazmanim({required bool on}) =>
      OngoingWeeksPrefill(
        notLearningBeinHazmanim: on,
        weeksText: weeksEditedByUser
            ? weeksText
            : on
            ? '$kOngoingWeeksPerYearBeinHazmanim'
            : '$kOngoingWeeksPerYearDefault',
        weeksEditedByUser: weeksEditedByUser,
      );

  /// The parent typed [text] in the weeks field. From now on the switch
  /// never overwrites it, even when [text] equals a prefill value.
  OngoingWeeksPrefill editWeeks(String text) => OngoingWeeksPrefill(
    notLearningBeinHazmanim: notLearningBeinHazmanim,
    weeksText: text,
    weeksEditedByUser: true,
  );

  @override
  bool operator ==(Object other) =>
      other is OngoingWeeksPrefill &&
      other.notLearningBeinHazmanim == notLearningBeinHazmanim &&
      other.weeksText == weeksText &&
      other.weeksEditedByUser == weeksEditedByUser;

  @override
  int get hashCode =>
      Object.hash(notLearningBeinHazmanim, weeksText, weeksEditedByUser);

  @override
  String toString() =>
      'OngoingWeeksPrefill(on: $notLearningBeinHazmanim, '
      '"$weeksText", edited: $weeksEditedByUser)';
}

/// [value] as form text: whole numbers without a decimal point (`52`, not
/// `52.0`), others as Dart prints them.
String formatOngoingNumber(double value) =>
    value == value.truncateToDouble() && value.isFinite
    ? value.toInt().toString()
    : value.toString();
