/// Custom lint rules for the Learning Tracker project.
///
/// Provides eighteen rules:
///   - [NoColorLiteralOutsideTheme]: warns on direct `Color(0x…)` hex-literal
///     constructor calls outside `lib/core/theme/`; use AppColors/AppTheme constants.
///   - [NoCurriculumDisplayNameBypass]: prevents access to `.displayNameEn` /
///     `.displayNameHe` outside the canonical `core/labels/` whitelist.
///   - [NoDeadErrorField]: flags a Riverpod Notifier whose state has a
///     `loading`/`error` field pair (evidenced by `copyWith(loading:,
///     error:, ...)` usage) where the file never sets `error:` to anything
///     other than `null` -- a declared-but-dead error field (SM-5 / EH-2,
///     AUD-gamification-10).
///   - [NoEagerListInNonLazyScrollContainer]: flags a `for`/`.map()` widget
///     expansion fed into a non-lazy `ListView(children:)` or a scrollable
///     `Column` under `lib/features/**`; use `ListView.builder` instead
///     (AUD-tutoring-08, PF-2).
///   - [NoEToStringInUi]: warns on `e.toString()` calls inside presentation/
///     files; use localised messages instead.
///   - [NoFeatureCrossImport]: prevents direct cross-feature deep imports;
///     features must communicate only through their barrel `X/X.dart` surface.
///   - [NoFirebaseOutsideCore]: prevents Firebase SDK imports outside
///     `lib/core/auth/`, `lib/core/sync/`, `lib/features/auth/`, and
///     `lib/core/providers/firebase_providers.dart`.
///   - [NoHandRolledAsyncStateNotifier]: flags a `Notifier<T>` whose state
///     type is a hand-rolled sealed Idle/Loading/Error-shaped union as an
///     SM-5 AsyncNotifier-migration candidate (AUD-account-14).
///   - [NoHardcodedDomainTerm]: warns on hardcoded Torah domain-term English
///     literals in user-facing strings in presentation code; render via
///     domainTermLabels / CurriculumLabels / l10n instead.
///   - [NoHardcodedErrorWidgetString]: warns on any hardcoded English literal
///     in a user-facing string slot inside AppErrorView, ErrorDisplay, or
///     PinEntryWidget specifically; resolve through AppLocalizations/ARB
///     instead (AUD-core-widgets-01, AX-2/EH-5).
///   - [NoHardcodedTextDirection]: warns on hardcoded directional layout values
///     that break RTL locales (EdgeInsets.only(left/right), Alignment.centerLeft/
///     centerRight, TextAlign.left/right).
///   - [NoRawLogEvent]: prevents direct `logEvent(name, …)` calls outside
///     `analytics_service.dart`; use typed helper methods instead.
///   - [NoRawTalker]: prevents `package:talker/talker.dart` imports outside
///     `lib/core/logging/`.
///   - [NoSideEffectInProviderBuild]: flags a chained-property (DAO field)
///     mutation or an `unawaited(...)` fire-and-forget call made directly
///     inside a legacy `Provider`/`StreamProvider`/`FutureProvider`
///     `create` callback (AUD-sync-08, SM-2 Enforce backstop).
///   - [NoRefAfterAwaitWithoutMountedCheck]: flags `ref.read`/`ref.watch`/
///     `state = ...` after an earlier `await` in the same async
///     method/closure with no `if (!ref.mounted) return;` guard in between
///     (SM-4, AUD-sync-04).
///   - [NoUnguardedAsyncNotifierInit]: flags a Riverpod Notifier's `build()`
///     firing a private async method fire-and-forget (unawaited, unguarded)
///     whose body has zero try/catch anywhere (AUD-account-11).
///   - [NoUnguardedStateTouchAfterAwait]: flags `state =` / `setState(...)`
///     appearing after an `await` in a Notifier/State method with no
///     intervening `mounted`/`ref.mounted` guard (SM-4, AUD-onboarding-01).
///   - [NoLogLessCatch]: flags a `catch` block under `lib/` that neither logs
///     through `AppLogger` nor rethrows (EH-3, AUD-onboarding-11).
///   - [NoOnboardingRawStringLiteral]: flags a raw string literal passed as
///     onboarding UI text (`Text(`/`errorText:`/`hintText:`/`label:`/etc.)
///     under `lib/features/onboarding/presentation/**` — the AX-2 [P]
///     literals checker (AUD-onboarding-04).
library learning_tracker_lints;

import 'package:custom_lint_builder/custom_lint_builder.dart';

import 'src/rules/no_color_literal_outside_theme.dart';
import 'src/rules/no_curriculum_display_name_bypass.dart';
import 'src/rules/no_dead_error_field.dart';
import 'src/rules/no_e_to_string_in_ui.dart';
import 'src/rules/no_eager_list_in_non_lazy_scroll_container.dart';
import 'src/rules/no_feature_cross_import.dart';
import 'src/rules/no_firebase_outside_core.dart';
import 'src/rules/no_hand_rolled_async_state_notifier.dart';
import 'src/rules/no_hardcoded_domain_term.dart';
import 'src/rules/no_hardcoded_error_widget_string.dart';
import 'src/rules/no_hardcoded_text_direction.dart';
import 'src/rules/no_log_less_catch.dart';
import 'src/rules/no_onboarding_raw_string_literal.dart';
import 'src/rules/no_raw_logevent.dart';
import 'src/rules/no_raw_talker.dart';
import 'src/rules/no_ref_after_await_without_mounted_check.dart';
import 'src/rules/no_side_effect_in_provider_build.dart';
import 'src/rules/no_unguarded_async_notifier_init.dart';
import 'src/rules/no_unguarded_state_touch_after_await.dart';

/// Entrypoint called by the custom_lint plugin runner.
PluginBase createPlugin() => _LearningTrackerLintPlugin();

class _LearningTrackerLintPlugin extends PluginBase {
  @override
  List<LintRule> getLintRules(CustomLintConfigs configs) => const [
        NoColorLiteralOutsideTheme(),
        NoCurriculumDisplayNameBypass(),
        NoDeadErrorField(),
        NoEagerListInNonLazyScrollContainer(),
        NoEToStringInUi(),
        NoFeatureCrossImport(),
        NoFirebaseOutsideCore(),
        NoHandRolledAsyncStateNotifier(),
        NoHardcodedDomainTerm(),
        NoHardcodedErrorWidgetString(),
        NoHardcodedTextDirection(),
        NoLogLessCatch(),
        NoOnboardingRawStringLiteral(),
        NoRawLogEvent(),
        NoRawTalker(),
        NoRefAfterAwaitWithoutMountedCheck(),
        NoSideEffectInProviderBuild(),
        NoUnguardedAsyncNotifierInit(),
        NoUnguardedStateTouchAfterAwait(),
      ];
}
