/// The after-lock prompt to set a learner's location (DNI-481 AC-2,
/// UX-DR-99).
///
/// After a recent Sacred-Time window ends, the device can prompt for a
/// missing location so future windows use the learner's actual area. The
/// action opens the existing city picker (`/sacred-time/city`) for THAT
/// learner. Profiles that have never had a configured location create no
/// lock and no after-lock prompt. Never during a lock (the overlay covers
/// the app) and never in a tutored session (the talmid's settings are the
/// parent's to set).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/navigation/root_scaffold_messenger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/profiles/profiles.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/lock_cover_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';

/// How far back an ended lock still earns the prompt.
const Duration learnerLocationPromptLookBack = Duration(days: 8);

/// One prompt: learner [profileId] ([displayName]) has no current location;
/// the recent prior lock ended at [lockEndUtc].
@immutable
final class LearnerLocationPrompt {
  /// Creates the prompt.
  const LearnerLocationPrompt({
    required this.profileId,
    required this.lockEndUtc,
    this.displayName = '',
  });

  /// The learner to prompt for.
  final String profileId;

  /// The end of the lock that prompted it.
  final DateTime lockEndUtc;

  /// The learner's display name ('' while unknown); copy only, not part of
  /// the prompt's identity.
  final String displayName;

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

/// The prompts due now, one per own learner (every learner whose lock
/// drives the device, [lockDrivingScopesProvider]) that has no location
/// and whose prior lock ended within [learnerLocationPromptLookBack]; empty
/// while a lock is in force or its cover is still up
/// ([lockCoverEngagedProvider]), in a tutored session, or while the
/// account's learners load. A learner whose settings load or fail is skipped;
/// unknown settings do not create a lock or a prompt.
final learnerLocationPromptsProvider =
    Provider.autoDispose<List<LearnerLocationPrompt>>((ref) {
      if (ref.watch(currentSacredWindowProvider) != null) return const [];
      // Until the lock cover has released (after it discarded what was
      // requested from the root messenger during the lock), so the prompt
      // is never swept by that discard.
      if (ref.watch(lockCoverEngagedProvider)) return const [];
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        return const [];
      }
      final scopes = ref.watch(lockDrivingScopesProvider).asData?.value;
      if (scopes == null || scopes.isEmpty) return const [];
      final profiles = ref.watch(profileListStreamProvider).asData?.value;
      if (profiles == null) return const [];
      final names = {
        for (final profile in profiles)
          profile.profileId: profile.displayName.trim(),
      };
      final now = ref.watch(localDayClockProvider).nowUtc();
      return [
        for (final scope in scopes)
          ?_promptFor(
            ref.watch(learnerLockSettingsProvider(scope)),
            scope.profileId,
            names[scope.profileId] ?? '',
            now,
          ),
      ];
    });

LearnerLocationPrompt? _promptFor(
  AsyncValue<LearnerSettingsHistory> history,
  String profileId,
  String displayName,
  DateTime now,
) {
  if (history.hasError || !history.hasValue) return null;
  final settings = history.requireValue;
  if (settings.spans.last.settings.hasLocation) return null;
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
    profileId: profileId,
    lockEndUtc: ended.last.endUtc,
    displayName: displayName,
  );
}

/// The after-lock prompt's action for [prompt] (DNI-481 AC-2), each step
/// gated on the one before:
///  1. [authorize] the action for the prompt's TARGET learner (the Parent
///     PINs of the device holder and, for another learner, of the target;
///     see `guardLearnerLocationPromptAccess`). Refused: nothing changes.
///  2. When the target is not the [selectedProfileId] learner, [switchTo]
///     it (the city picker edits the ACTIVE learner); a switch that did not
///     land on the target stops here.
///  3. [openCityPicker], straight after the authorization, with no user
///     turn in between: the picker never opens on a learner whose PIN was
///     not just verified for this action.
Future<void> runLearnerLocationPromptAction(
  LearnerLocationPrompt prompt, {
  required String? Function() selectedProfileId,
  required Future<bool> Function(String targetProfileId) authorize,
  required Future<bool> Function(String profileId) switchTo,
  required Future<void> Function() openCityPicker,
}) async {
  final target = prompt.profileId;
  if (!await authorize(target)) return;
  if (selectedProfileId() != target && !await switchTo(target)) return;
  if (selectedProfileId() != target) return;
  await openCityPicker();
}

/// Shows each due [LearnerLocationPrompt] once, as a snack bar on the root
/// messenger naming its learner, whose action calls [onSetLocation] with
/// that prompt (the app makes its learner the active one and opens the
/// city picker, behind the parent PIN when one guards the settings).
class LearnerLocationPromptListener extends ConsumerStatefulWidget {
  /// Creates the listener around [child].
  const LearnerLocationPromptListener({
    required this.onSetLocation,
    required this.child,
    super.key,
  });

  /// Opens the location picker for the prompt's learner.
  final Future<void> Function(LearnerLocationPrompt prompt) onSetLocation;

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
    ref.listenManual<List<LearnerLocationPrompt>>(
      learnerLocationPromptsProvider,
      (_, next) => next.forEach(_show),
      fireImmediately: true,
    );
  }

  void _show(LearnerLocationPrompt prompt) {
    if (!_shown.add(prompt)) return;
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
          content: Text(
            prompt.displayName.isEmpty
                ? l10n.sacredTimeLocationPromptMessage(shabbos)
                : l10n.sacredTimeLocationPromptMessageNamed(
                    prompt.displayName,
                    shabbos,
                  ),
          ),
          action: SnackBarAction(
            label: l10n.sacredTimeLocationPromptAction,
            onPressed: () => widget.onSetLocation(prompt),
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
