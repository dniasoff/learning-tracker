import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/constants/curriculum_defaults.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/curriculum_label.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/features/learning/domain/services/completion_detection_service.dart';
import 'package:learning_tracker/features/progress/domain/models/journey_view_model.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// Resolve the localized, Hebrew-terms- and nusach-aware label for one siyum
/// tier ([level]) of [curriculum] — the text shown next to each radio in the
/// granularity selector.
///
/// * [MilestoneLevel.unit] / [MilestoneLevel.aggregate] reuse the existing
///   curriculum level words (Masechta / Seder / Sefer / Siman / Hilchos) via
///   [CurriculumLabels], keyed off the SAME `entryScope` string the milestone
///   emission uses (`unitScopeFor`), so the selector word always matches the
///   siyum label the user will later see.
/// * [MilestoneLevel.curriculum] renders "Whole {curriculum}" from the ARB,
///   with the curriculum name resolved through [curriculumLabelText].
///
/// Deliberately never hardcodes an English tier word — every word flows
/// through the localized label system.
String siyumTierLabel(
  WidgetRef ref,
  BuildContext context, {
  required CurriculumId curriculum,
  required MilestoneLevel level,
}) {
  switch (level) {
    case MilestoneLevel.curriculum:
      return AppLocalizations.of(context)!.siyumGranularityWholeCurriculum(
        curriculumLabelText(ref, curriculum: curriculum),
      );
    case MilestoneLevel.aggregate:
      return _scopeWord(ref, unitScopeFor(curriculum, level: 1));
    case MilestoneLevel.unit:
      final scope = unitScopeFor(
        curriculum,
        level: hasNamedLevel2Unit(curriculum) ? 2 : 1,
      );
      return _scopeWord(ref, scope);
  }
}

/// Map a ledger `entryScope` string to its localized level word.
///
/// Each scope is resolved through a canonical (curriculum, level) whose
/// [CurriculumLabels] entry defines that word cleanly — e.g. `'sefer'` uses
/// Mishneh Torah's level-1 label ("Sefer" / "ספר"), never Chumash's ("חומש"),
/// so the word matches the emitted `siyumSefer` siyum label rather than the
/// per-curriculum display quirk. The words are nusach-aware (Masechta →
/// Masekhet in Sephardi) via [LevelLabels.inLanguage].
String _scopeWord(WidgetRef ref, String scope) {
  final useHebrew = domainTermLabels(ref).isHebrew;
  final variant = ref.watch(currentTransliterationVariantProvider);
  final labels = switch (scope) {
    'masechta' => CurriculumLabels.level(CurriculumId.mishnayos, 2),
    'siman' => CurriculumLabels.level(CurriculumId.mishnaBerurah, 2),
    'hilchos' => CurriculumLabels.level(CurriculumId.mishnehTorah, 2),
    'seder' => CurriculumLabels.level(CurriculumId.mishnayos, 1),
    // 'sefer' and any defensive fallback: the clean "Sefer" / "ספר" word.
    _ => CurriculumLabels.level(CurriculumId.mishnehTorah, 1),
  };
  return labels.inLanguage(useHebrew: useHebrew, variant: variant);
}
