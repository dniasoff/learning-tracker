import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_registry.dart';
import 'package:learning_tracker/features/scheduler/domain/services/calendar_program_service.dart';
import 'package:learning_tracker/features/scheduler/domain/services/learning_program_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

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
  /// Builds a resolver directly from a resolved [DomainTermLabels] value —
  /// no [WidgetRef]/[Ref] required. This is the label-selection logic's
  /// real entry point: the methods below only branch on
  /// [DomainTermLabels.isHebrew], so a plain `test()` can construct
  /// `ProgramLabelResolver(const DomainTermLabels(true))` directly instead
  /// of pumping a widget tree. [of] and [fromRef] are thin Riverpod wiring
  /// built on top of this constructor.
  const ProgramLabelResolver(this._labels);

  final DomainTermLabels _labels;

  /// Resolver bound to the active Hebrew Terms toggle.
  ///
  /// Cheap to construct on every rebuild — [DomainTermLabels] itself just
  /// captures the toggle boolean.
  factory ProgramLabelResolver.of(WidgetRef ref) =>
      ProgramLabelResolver(domainTermLabels(ref));

  /// Provider-side variant of [ProgramLabelResolver.of].
  factory ProgramLabelResolver.fromRef(Ref ref) =>
      ProgramLabelResolver(domainTermLabelsFromRef(ref));

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

  /// Returns a locale-aware description for [program].
  ///
  /// Picks the ARB key matching the program's [LearningProgramData.name] from
  /// [l10n].  Falls back to [LearningProgramData.description] (the English
  /// seed text) when no ARB key exists for the program name.
  String learningProgramDescription(
    LearningProgramData program,
    AppLocalizations l10n,
  ) {
    switch (program.name) {
      case 'oraysa':
        return l10n.programDescriptionOraysa;
      case 'dirshu_kinyan_torah':
        return l10n.programDescriptionDirshuKinyanTorah;
      case 'dirshu_amud_hayomi':
        return l10n.programDescriptionDirshuAmudHaYomi;
      case 'dirshu_kinyan_yerushalmi':
        return l10n.programDescriptionDirshuKinyanYerushalmi;
      case 'daf_yomi':
        return l10n.programDescriptionDafYomi;
      case 'mishnah_yomis':
        return l10n.programDescriptionMishnayYomis;
      case 'nach_yomi':
        return l10n.programDescriptionNachYomi;
      case 'yerushalmi_yomi':
        return l10n.programDescriptionYerushalmiYomi;
      case 'rambam_1_chapter':
        return l10n.programDescriptionRambam1Chapter;
      case 'rambam_3_chapters':
        return l10n.programDescriptionRambam3Chapters;
      case 'daf_a_week':
        return l10n.programDescriptionDafAWeek;
      case 'halakhah_yomit':
        return l10n.programDescriptionHalakhahYomit;
      case 'arukh_hashulchan_yomi':
        return l10n.programDescriptionArukhHashulchanYomi;
      case 'tanakh_yomi':
        return l10n.programDescriptionTanakhYomi;
      case 'chofetz_chaim_daily':
        return l10n.programDescriptionChofetzChaimDaily;
      case 'kitzur_shulchan_aruch_yomi':
        return l10n.programDescriptionKitzurShulchanAruchYomi;
      case 'tehillim_yomi':
        return l10n.programDescriptionTehillimYomi;
      case 'perek_yomi':
        return l10n.programDescriptionPerekYomi;
      case 'sefer_hamitzvot':
        return l10n.programDescriptionSeferHaMitzvot;
      case 'shemirat_halashon':
        return l10n.programDescriptionShemiratHaLashon;
      case 'pirkei_avot_summer':
        return l10n.programDescriptionPirkeiAvotSummer;
      default:
        return program.description;
    }
  }
}

/// Convenience top-level function — mirrors [learningProgramLabelText] for
/// descriptions.  Resolves via [ProgramLabelResolver] so that features do not
/// construct the resolver directly.
String learningProgramDescriptionText(
  WidgetRef ref,
  BuildContext context, {
  required LearningProgramData program,
}) {
  final l10n = AppLocalizations.of(context)!;
  return ProgramLabelResolver.of(ref).learningProgramDescription(program, l10n);
}
