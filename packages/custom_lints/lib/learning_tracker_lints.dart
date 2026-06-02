/// Custom lint rules for the Learning Tracker project.
///
/// Provides eight rules:
///   - [NoColorLiteralOutsideTheme]: warns on direct `Color(0x…)` hex-literal
///     constructor calls outside `lib/core/theme/`; use AppColors/AppTheme constants.
///   - [NoCurriculumDisplayNameBypass]: prevents access to `.displayNameEn` /
///     `.displayNameHe` outside the canonical `core/labels/` whitelist.
///   - [NoEToStringInUi]: warns on `e.toString()` calls inside presentation/
///     files; use localised messages instead.
///   - [NoFeatureCrossImport]: prevents direct cross-feature deep imports;
///     features must communicate only through their barrel `X/X.dart` surface.
///   - [NoFirebaseOutsideCore]: prevents Firebase SDK imports outside
///     `lib/core/auth/` and `lib/core/sync/`.
///   - [NoHardcodedDomainTerm]: warns on hardcoded Torah domain-term English
///     literals in user-facing strings in presentation code; render via
///     domainTermLabels / CurriculumLabels / l10n instead.
///   - [NoHardcodedTextDirection]: warns on hardcoded directional layout values
///     that break RTL locales (EdgeInsets.only(left/right), Alignment.centerLeft/
///     centerRight, TextAlign.left/right).
///   - [NoRawLogEvent]: prevents direct `logEvent(name, …)` calls outside
///     `analytics_service.dart`; use typed helper methods instead.
///   - [NoRawTalker]: prevents `package:talker/talker.dart` imports outside
///     `lib/core/logging/`.
library learning_tracker_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/no_color_literal_outside_theme.dart';
import 'src/rules/no_curriculum_display_name_bypass.dart';
import 'src/rules/no_e_to_string_in_ui.dart';
import 'src/rules/no_feature_cross_import.dart';
import 'src/rules/no_firebase_outside_core.dart';
import 'src/rules/no_hardcoded_domain_term.dart';
import 'src/rules/no_hardcoded_text_direction.dart';
import 'src/rules/no_raw_logevent.dart';
import 'src/rules/no_raw_talker.dart';

/// Entrypoint called by the custom_lint plugin runner.
PluginBase createPlugin() => _LearningTrackerLintPlugin();

class _LearningTrackerLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoColorLiteralOutsideTheme(),
        NoCurriculumDisplayNameBypass(),
        NoEToStringInUi(),
        NoFeatureCrossImport(),
        NoFirebaseOutsideCore(),
        NoHardcodedDomainTerm(),
        NoHardcodedTextDirection(),
        NoRawLogEvent(),
        NoRawTalker(),
      ];
}
