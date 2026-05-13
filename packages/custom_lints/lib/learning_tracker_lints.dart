/// Custom lint rules for the Learning Tracker project.
///
/// Provides five rules:
///   - [NoCurriculumDisplayNameBypass]: prevents access to `.displayNameEn` /
///     `.displayNameHe` outside the canonical `core/labels/` whitelist.
///   - [NoFeatureCrossImport]: prevents direct cross-feature deep imports;
///     features must communicate only through their `providers.dart` surface.
///   - [NoFirebaseOutsideCore]: prevents Firebase SDK imports outside
///     `lib/core/auth/` and `lib/core/sync/`.
///   - [NoRawTalker]: prevents `package:talker/talker.dart` imports outside
///     `lib/core/logging/`.
///   - [NoHardcodedTextDirection]: warns on hardcoded directional layout values
///     that break RTL locales (EdgeInsets.only(left/right), Alignment.centerLeft/
///     centerRight, TextAlign.left/right).
library learning_tracker_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/no_curriculum_display_name_bypass.dart';
import 'src/rules/no_feature_cross_import.dart';
import 'src/rules/no_firebase_outside_core.dart';
import 'src/rules/no_hardcoded_text_direction.dart';
import 'src/rules/no_raw_talker.dart';

/// Entrypoint called by the custom_lint plugin runner.
PluginBase createPlugin() => _LearningTrackerLintPlugin();

class _LearningTrackerLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoCurriculumDisplayNameBypass(),
        NoFeatureCrossImport(),
        NoFirebaseOutsideCore(),
        NoRawTalker(),
        NoHardcodedTextDirection(),
      ];
}
