import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';

/// Scheduler-side resolver for program-label strings.
///
/// Type-aware program-label resolution lives here (not in
/// `lib/core/labels/`) so `lib/core/` does not have to import scheduler
/// types — which would be a Rule 1 violation (`lib/core/` MUST NOT import
/// `lib/features/`).
///
/// The toggle source-of-truth still lives in `lib/core/labels/` —
/// [DomainTermLabels.isHebrew] is the single boolean knob that decides
/// whether to render Hebrew or English. Each method here:
///   1. reads that boolean through the existing [domainTermLabels] /
///      [domainTermLabelsFromRef] entry points (so scheduler code does not
///      poke `useHebrewTermsProvider` directly — audit rule 7/15);
///   2. picks the appropriate field on the scheduler-side type.
///
/// Call sites in `features/scheduler/` MUST use these methods instead of
/// the older `domainTermLabels(ref).learningProgramLabel(...)` shape (which
/// was removed when this shim was introduced — see F4 in the W7-D
/// adversarial review fix wave).
class ProgramLabelResolver {
  const ProgramLabelResolver._(this._labels);

  final DomainTermLabels _labels;

  /// Resolver bound to the active Hebrew Terms toggle.
  ///
  /// Cheap to construct on every rebuild — [DomainTermLabels] itself just
  /// captures the toggle boolean.
  factory ProgramLabelResolver.of(WidgetRef ref) =>
      ProgramLabelResolver._(domainTermLabels(ref));

  /// Provider-side variant of [ProgramLabelResolver.of].
  factory ProgramLabelResolver.fromRef(Ref ref) =>
      ProgramLabelResolver._(domainTermLabelsFromRef(ref));

  /// Returns the display name for a [LearningProgramData] respecting the
  /// Hebrew Terms toggle.
  ///
  /// Hebrew ON → looks up the Hebrew name via
  ///   [CalendarProgramRegistry.byId] using the program's `name` as id and
  ///   falls back to [LearningProgramData.displayName] when the program
  ///   isn't a registered calendar program (so a Hebrew form doesn't
  ///   exist).
  /// Hebrew OFF → returns the program's English
  ///   [LearningProgramData.displayName].
  String learningProgramLabel(LearningProgramData program) {
    if (!_labels.isHebrew) return program.displayName;
    return CalendarProgramRegistry.hebrewNameFor(
          name: program.name,
          apiKey: program.apiProgramKey,
        ) ??
        program.displayName;
  }

  /// Returns the display name for a [CalendarProgramEntry] respecting the
  /// Hebrew Terms toggle. Mirrors [learningProgramLabel] for entries.
  String calendarEntryLabel(CalendarProgramEntry entry) =>
      _labels.isHebrew ? entry.displayNameHe : entry.displayNameEn;

  /// Returns the today's-ref label for a [CalendarProgramEntry] respecting
  /// the Hebrew Terms toggle. Falls back to the English
  /// [CalendarProgramEntry.todayRef] when the Hebrew form is unavailable.
  String calendarEntryTodayRef(CalendarProgramEntry entry) {
    if (_labels.isHebrew && entry.todayRefHe.isNotEmpty)
      return entry.todayRefHe;
    return entry.todayRef;
  }
}
