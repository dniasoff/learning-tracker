/// Fires [AnalyticsEvent.streakMilestoneReached] when a curriculum's
/// streak newly crosses a milestone (7, 30, 100 days), per curriculum
/// (DNI-479, AD-40: `LearnerState` has no profile-wide streak).
///
/// Lives in [core/analytics/] so all analytics calls are confined to this
/// layer (Story 27.14, DNI-390).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// One milestone a curriculum's streak newly reached.
typedef StreakMilestoneCrossing = ({CurriculumId curriculum, int milestone});

/// The engine-derived per-curriculum milestone transitions of one session.
///
/// The first state observed for a curriculum is its baseline (nothing
/// fires for a streak that was already past a milestone when the session
/// began). After that, a milestone fires when the curriculum's current
/// streak goes from below it to at or above it, and at most once per
/// session per curriculum, so a re-emitted or recomputed state never
/// fires twice. A curriculum that is not a [CurriculumId] (or has no
/// streak) is ignored.
class StreakMilestoneTracker {
  final Map<CurriculumId, int> _last = {};
  final Map<CurriculumId, Set<int>> _fired = {};

  /// The crossings [state] adds since the last observed state.
  List<StreakMilestoneCrossing> observe(LearnerState state) {
    final out = <StreakMilestoneCrossing>[];
    for (final MapEntry(key: key, value: curriculum)
        in state.curricula.entries) {
      final id = CurriculumId.fromStorageKey(key);
      final streak = curriculum.streak;
      if (id == null || streak == null) continue;
      final previous = _last[id];
      _last[id] = streak.current;
      if (previous == null) continue;
      final fired = _fired.putIfAbsent(id, () => <int>{});
      for (final milestone in kStreakMilestones) {
        if (previous < milestone &&
            streak.current >= milestone &&
            fired.add(milestone)) {
          out.add((curriculum: id, milestone: milestone));
        }
      }
    }
    return out;
  }
}

/// Watches the active learner's state while the app shell watches it, and
/// logs each [StreakMilestoneTracker] crossing with the curriculum's
/// `curriculum_id` enum and the milestone count only (PV-1: no profile,
/// learner, event or content identifier).
///
/// Rebuilt — and the session baseline reset — on every profile switch. A
/// tutor viewing a talmid never attributes the talmid's milestone to the
/// tutor's analytics identity.
///
/// Wire via: `ref.watch(streakMilestoneAnalyticsObserverProvider)` in the
/// app shell to activate.
///
/// Error handling: a fire-and-forget background effect. A learner-state
/// error is skipped (the next complete state is observed), and an
/// [Exception] from the analytics call is logged at WARNING level, never
/// propagated to the app-shell build.
final streakMilestoneAnalyticsObserverProvider =
    StreamProvider.autoDispose<void>((ref) {
      if (ref.watch(activeTutoredProfileSelectionProvider) != null) {
        return const Stream<void>.empty();
      }
      ref.watch(activeProfileIdProvider);
      final analytics = ref.watch(analyticsServiceProvider);
      final logger = AppLogger.instance;
      final tracker = StreakMilestoneTracker();

      ref.listen<AsyncValue<LearnerState?>>(activeLearnerStateProvider, (
        _,
        next,
      ) {
        final state = next.asData?.value;
        if (state == null) return;
        for (final crossing in tracker.observe(state)) {
          unawaited(
            analytics
                .logStreakMilestoneReached(
                  curriculumId: crossing.curriculum.storageKey,
                  milestone: crossing.milestone,
                )
                .catchError((Object e, StackTrace st) {
                  logger.warning(
                    event: 'streak_milestone_analytics_log_failed',
                    fields: {'milestone': crossing.milestone},
                    exception: e,
                    stackTrace: st,
                  );
                }),
          );
        }
      }, fireImmediately: true);

      return const Stream<void>.empty();
    });
