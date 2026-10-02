/// The siyum celebration (DNI-474 AC-4; FR-17): fires once per device per
/// completion when a unit newly enters the engine's completed units, from
/// any source (live capture, backfill, correction, another device), whenever
/// the app is in the foreground. Chazara never re-fires it; a void that
/// takes a siyum away clears its key so a re-completion celebrates again.
/// Reduce-motion suppresses the confetti, never the celebration itself.
library;

import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_grouping.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/labels/domain_term_labels.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/preferences/profile_scoped_preference_keys.dart';
import 'package:learning_tracker/core/theme/app_palette.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_celebration_policy.dart';
import 'package:learning_tracker/features/progress/domain/services/siyum_milestones.dart';
import 'package:learning_tracker/features/progress/domain/siyum_granularity_filter.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Shows the siyum celebration dialog for [siyumim] (one dialog; the first
/// unit is named, the rest counted). With [reduceMotion] there is no
/// confetti and no auto-dismiss animation.
typedef SiyumCelebrationPresenter =
    Future<void> Function(
      BuildContext context,
      List<SiyumToCelebrate> siyumim, {
      required bool reduceMotion,
    });

/// The presenter the listener uses; tests override it to observe
/// celebrations without pumping the dialog.
final siyumCelebrationPresenterProvider = Provider<SiyumCelebrationPresenter>(
  (ref) => showSiyumCelebration,
);

/// Watches the active learner's [LearnerState] and celebrates newly
/// completed units while the app is in the foreground. Mounted once in the
/// app shell around [child].
class SiyumCelebrationListener extends ConsumerStatefulWidget {
  /// Creates the listener.
  const SiyumCelebrationListener({required this.child, super.key});

  /// The shell content.
  final Widget child;

  @override
  ConsumerState<SiyumCelebrationListener> createState() =>
      _SiyumCelebrationListenerState();
}

class _SiyumCelebrationListenerState
    extends ConsumerState<SiyumCelebrationListener>
    with WidgetsBindingObserver {
  bool _busy = false;
  bool _again = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _evaluate());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_evaluate());
  }

  bool get _foreground {
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    return lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  Future<void> _evaluate() async {
    if (!mounted) return;
    if (_busy) {
      _again = true;
      return;
    }
    _busy = true;
    try {
      do {
        _again = false;
        await _evaluateOnce();
      } while (_again && mounted);
    } finally {
      _busy = false;
    }
  }

  Future<void> _evaluateOnce() async {
    if (!_foreground) return; // the next resume evaluates
    // A tutor device viewing a talmid never celebrates for them.
    if (ref.read(activeTutoredProfileSelectionProvider) != null) return;
    final scope = ref.read(activeLearnerScopeProvider).value;
    final state = ref.read(activeLearnerStateProvider).value;
    if (scope == null || state == null) return; // loading, error or none
    final SiyumCelebrationPlan plan;
    try {
      final prefs = await SharedPreferences.getInstance();
      plan = planSiyumCelebrations(
        profileId: scope.profileId,
        state: state,
        storedKeys: prefs.getKeys(),
        seeded:
            prefs.getBool(
              ProfileScopedPreferenceKeys.siyumShownSeeded(scope.profileId),
            ) ??
            false,
        celebrates: _granularityFilter(),
      );
      if (plan.isEmpty) return;
      // Keys are written before the dialog shows, so an interrupted dialog
      // (rebuild, retry, backgrounding) never replays the same completion.
      for (final key in plan.keysToRemove) {
        await prefs.remove(key);
      }
      for (final key in plan.keysToAdd) {
        await prefs.setBool(key, true);
      }
      if (plan.markSeeded) {
        await prefs.setBool(
          ProfileScopedPreferenceKeys.siyumShownSeeded(scope.profileId),
          true,
        );
      }
    } catch (error, stackTrace) {
      // A local celebration-state failure: progress and the timeline still
      // read the engine; only the one-time dialog is affected.
      AppLogger.instance.warning(
        event: 'siyum_celebration_state_failed',
        fields: {'profileId': scope.profileId},
        exception: error,
        stackTrace: stackTrace,
      );
      return;
    }
    if (plan.celebrate.isEmpty || !mounted) return;
    final present = ref.read(siyumCelebrationPresenterProvider);
    await present(
      context,
      plan.celebrate,
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  /// Rejects units finer than the curriculum's chosen siyum granularity.
  bool Function(String curriculumId, NodeEntry unit) _granularityFilter() {
    final corpora = ref.read(corporaProvider).value ?? const {};
    return (curriculumId, unit) {
      final curriculum = CurriculumId.fromStorageKey(curriculumId);
      final corpus = corpora[curriculumId];
      if (curriculum == null || corpus == null) return true;
      final finest = ref.read(siyumGranularityProvider(curriculum));
      return milestoneLevelRank(milestoneLevelOf(corpus, unit.level)) >=
          milestoneLevelRank(finest);
    };
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<LearnerState?>>(activeLearnerStateProvider, (
      previous,
      next,
    ) {
      if (next.hasValue && !next.isLoading) unawaited(_evaluate());
    });
    return widget.child;
  }
}

/// The default [SiyumCelebrationPresenter]: a dialog naming the completed
/// unit, with confetti unless [reduceMotion].
Future<void> showSiyumCelebration(
  BuildContext context,
  List<SiyumToCelebrate> siyumim, {
  required bool reduceMotion,
}) => showDialog<void>(
  context: context,
  barrierDismissible: true,
  builder: (_) =>
      SiyumCelebrationDialog(siyumim: siyumim, reduceMotion: reduceMotion),
);

/// The siyum celebration dialog.
class SiyumCelebrationDialog extends ConsumerStatefulWidget {
  /// Creates the dialog.
  const SiyumCelebrationDialog({
    required this.siyumim,
    required this.reduceMotion,
    super.key,
  });

  /// The completed units (non-empty).
  final List<SiyumToCelebrate> siyumim;

  /// Whether the platform asks for reduced motion.
  final bool reduceMotion;

  @override
  ConsumerState<SiyumCelebrationDialog> createState() =>
      _SiyumCelebrationDialogState();
}

class _SiyumCelebrationDialogState
    extends ConsumerState<SiyumCelebrationDialog> {
  ConfettiController? _confetti;

  @override
  void initState() {
    super.initState();
    if (!widget.reduceMotion) {
      final controller = ConfettiController(
        duration: const Duration(seconds: 4),
      );
      _confetti = controller;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) controller.play();
      });
    }
  }

  @override
  void dispose() {
    _confetti?.dispose();
    super.dispose();
  }

  String _unitName(SiyumToCelebrate siyum) {
    final useHebrew = domainTermLabels(ref).isHebrew;
    final item = ref.watch(contentIndexProvider).value?.lookup(siyum.unit.ref);
    if (item == null) return siyum.unit.ref;
    return itemDisplayName(item, useHebrew: useHebrew);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final first = widget.siyumim.first;
    final more = widget.siyumim.length - 1;
    final confetti = _confetti;
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        AlertDialog(
          icon: Icon(
            Icons.emoji_events_rounded,
            size: 48,
            color: context.colors.statusSuccessDeep,
          ),
          title: Text(l10n.siyumCelebrationTitle, textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.siyumCelebrationBody(_unitName(first)),
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (more > 0) ...[
                const SizedBox(height: 8),
                Text(
                  l10n.siyumCelebrationMore(more),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.siyumCelebrationDismiss),
            ),
          ],
        ),
        if (confetti != null)
          IgnorePointer(
            child: ConfettiWidget(
              confettiController: confetti,
              blastDirectionality: BlastDirectionality.explosive,
              colors: [
                context.colors.gamifPartyColorCoral,
                context.colors.gamifPartyColorYellow,
                context.colors.chartGreen,
                context.colors.chartBlue,
              ],
            ),
          ),
      ],
    );
  }
}
