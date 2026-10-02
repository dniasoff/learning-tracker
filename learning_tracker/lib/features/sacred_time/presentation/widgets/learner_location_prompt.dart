/// The after-lock prompt to set a learner's location (DNI-481 AC-2,
/// UX-DR-99).
///
/// A learner with no location is locked by the fail-closed fallback window
/// (Fri 12:00 → Sun 01:00 learner-local, and the yom tov equivalent). Once
/// such a lock has ended, the device shows a prompt — once per lock per app
/// session — whose action opens the existing city picker
/// (`/sacred-time/city`) for that learner. Never during a lock (the overlay
/// covers the app) and never in a tutored session (the talmid's settings
/// are the parent's to set).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/sacred_time/data/repositories/learner_lock_settings_sources.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// How far back an ended lock still earns the prompt.
const Duration learnerLocationPromptLookBack = Duration(days: 8);

/// One prompt: learner [profileId] has no location and its lock ended at
/// [lockEndUtc].
@immutable
final class LearnerLocationPrompt {
  /// Creates the prompt.
  const LearnerLocationPrompt({
    required this.profileId,
    required this.lockEndUtc,
  });

  /// The learner to prompt for.
  final String profileId;

  /// The end of the lock that prompted it.
  final DateTime lockEndUtc;

  @override
  bool operator ==(Object other) =>
      other is LearnerLocationPrompt &&
      other.profileId == profileId &&
      other.lockEndUtc == lockEndUtc;

  @override
  int get hashCode => Object.hash(profileId, lockEndUtc);

  @override
  String toString() => 'LearnerLocationPrompt($profileId, $lockEndUtc)';
}

/// The prompt due now, or null: the active own learner has no location, a
/// lock of theirs ended within [learnerLocationPromptLookBack], and no lock
/// is in force.
final learnerLocationPromptProvider =
    Provider.autoDispose<LearnerLocationPrompt?>((ref) {
      if (ref.watch(currentSacredWindowProvider) != null) return null;
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        return null;
      }
      final scope = ref.watch(activeLearnerScopeProvider).asData?.value;
      if (scope == null) return null;
      final history = ref.watch(learnerLockSettingsProvider(scope));
      if (history.hasError || !history.hasValue) return null;
      final settings = history.requireValue;
      if (settings.spans.last.settings.hasLocation) return null;
      final now = ref.watch(localDayClockProvider).nowUtc();
      final ended = [
        for (final w in lockWindows(
          settings,
          now.subtract(learnerLocationPromptLookBack),
          now,
        ))
          if (w.endUtc.isBefore(now)) w,
      ];
      if (ended.isEmpty) return null;
      return LearnerLocationPrompt(
        profileId: scope.profileId,
        lockEndUtc: ended.last.endUtc,
      );
    });

/// Shows each due [LearnerLocationPrompt] once, as a snack bar on the root
/// messenger whose action calls [onSetLocation] (the app opens the city
/// picker, behind the parent PIN when one guards the settings).
class LearnerLocationPromptListener extends ConsumerStatefulWidget {
  /// Creates the listener around [child].
  const LearnerLocationPromptListener({
    required this.onSetLocation,
    required this.child,
    super.key,
  });

  /// Opens the location picker for the active learner.
  final Future<void> Function() onSetLocation;

  /// The app.
  final Widget child;

  @override
  ConsumerState<LearnerLocationPromptListener> createState() =>
      _LearnerLocationPromptListenerState();
}

class _LearnerLocationPromptListenerState
    extends ConsumerState<LearnerLocationPromptListener> {
  /// Prompts already shown this app session.
  final Set<LearnerLocationPrompt> _shown = {};

  @override
  void initState() {
    super.initState();
    ref.listenManual<LearnerLocationPrompt?>(
      learnerLocationPromptProvider,
      (_, next) => _show(next),
      fireImmediately: true,
    );
  }

  void _show(LearnerLocationPrompt? prompt) {
    if (prompt == null || !_shown.add(prompt)) return;
    // After this frame: the messenger and its localizations are built.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = rootScaffoldMessengerKey.currentState;
      final l10n = AppLocalizations.of(context);
      if (messenger == null || l10n == null) return;
      final shabbos = domainTermLabels(
        ref,
      ).shabbos(variant: ref.read(currentTransliterationVariantProvider));
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 12),
          content: Text(l10n.sacredTimeLocationPromptMessage(shabbos)),
          action: SnackBarAction(
            label: l10n.sacredTimeLocationPromptAction,
            onPressed: () => widget.onSetLocation(),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
