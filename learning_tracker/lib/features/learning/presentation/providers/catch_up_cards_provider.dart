/// The catch-up cards of the Learn tab (Story 3.2, DNI-505): which locks
/// have a pending card for the active learner, and what each lists.
///
/// Composition only. The windows are [catchUpCardWindowsAt] over the
/// active learner's settings history ([erevSettingsHistoryProvider], the
/// one settings source of the capture gate, the overlay and the erev
/// view), at the commands' clock. The contents are [projectCatchUpCards]
/// over the shared planner's lists for the covered locked days
/// ([watchPlannedDaysInSequence], AD-49 / Story 3.1), the live
/// `LearnerState` (counted and voided events, sub-track positions) and the
/// complete `sub_tracks` read with its current `learns_on_shabbos`. Every
/// input is a live stream, so a capture or undo on another device of the
/// profile, or a parent's flag edit, recomputes the cards (AC-8, AC-10).
/// No Firestore access here (AD-23).
///
/// Owner devices only (AC-12): a tutored session has no catch-up card.
/// Every read is scoped to the active learner, so a multi-learner device
/// shows a profile's cards only while that profile is in view.
///
/// Plain Riverpod providers (no codegen), matching
/// `erev_planned_tasks_provider.dart`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';
import 'package:learning_tracker/features/sub_tracks/sub_tracks.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

/// A pending catch-up card whose main-track rows are planner tasks.
typedef CatchUpTaskCard = CatchUpCard<DailyTask>;

/// Lays out the planner's lists for [dates], in order, over the live
/// learner state that [ref] watches (one list per date).
typedef CatchUpSequencePlanner =
    Future<List<List<DailyTask>>> Function(Ref ref, List<CivilDate> dates);

/// The planner the cards read: [watchPlannedDaysInSequence], the shared
/// planner (AD-49). Tests override it with a planner over a fake state.
final catchUpSequencePlannerProvider = Provider<CatchUpSequencePlanner>(
  (ref) => watchPlannedDaysInSequence,
);

/// Reports an inconsistent settings history (AC-5, B13): a structured
/// warning with reason `catch_up_history_gap` and no PII. Tests override
/// it to observe the report.
final catchUpHistoryGapReporterProvider =
    Provider<void Function(CatchUpHistoryGap gap)>(
      (ref) =>
          (gap) => AppLogger.instance.warning(
            event: CatchUpHistoryGap.reason,
            fields: {
              'reason': CatchUpHistoryGap.reason,
              'dropped_days': gap.droppedDays.length,
            },
          ),
    );

/// Whether this device shows catch-up cards: an owner session, never a
/// tutored one (AC-12; the card is owner-only and no epic adds a tutor
/// card).
final catchUpOwnerSessionProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(activeTutoredProfileSelectionProvider) == null,
);

/// How long the pending windows may go without a re-check when no
/// boundary is near.
const Duration catchUpRecheckInterval = Duration(minutes: 5);

/// The locks with a card available now for the active learner, oldest
/// first (AC-1, AC-6); empty on a tutor device, with no active learner,
/// inside a lock, or when the windows cannot be computed (fail closed: no
/// card, the gate and overlay decide the lock on their own reads).
///
/// It re-evaluates itself just after the next boundary (a card's expiry,
/// a lock's start or end) and at least every [catchUpRecheckInterval], so
/// a Sunday card is gone at 00:00 Monday learner-local (AC-2).
final catchUpCardWindowsProvider =
    FutureProvider.autoDispose<List<CatchUpCardWindow>>((ref) async {
      if (!ref.watch(catchUpOwnerSessionProvider)) return const [];
      final clock = ref.watch(learningCommandClockProvider);
      final report = ref.watch(catchUpHistoryGapReporterProvider);
      final history = await ref.watch(erevSettingsHistoryProvider.future);
      if (history == null) return const [];
      final now = clock().toUtc();
      var delay = catchUpRecheckInterval;
      var windows = const <CatchUpCardWindow>[];
      try {
        windows = catchUpCardWindowsAt(history, now);
        final next = nextCatchUpTransition(history, now);
        if (next != null) {
          final untilNext = next.difference(now);
          if (untilNext < delay) delay = untilNext;
        }
      } on Object {
        windows = const []; // fail closed: no card
      }
      for (final w in windows) {
        final gap = w.gap;
        if (gap != null && _reportedGaps.add(w.key)) report(gap);
      }
      // Fire just after the boundary, never in a tight loop.
      final wait = delay <= Duration.zero
          ? const Duration(milliseconds: 1)
          : delay + const Duration(milliseconds: 1);
      final timer = Timer(wait, ref.invalidateSelf);
      ref.onDispose(timer.cancel);
      return windows;
    }, retry: (retryCount, error) => null);

/// Locks whose history gap was already reported this run, so a re-check
/// every few minutes does not repeat the warning.
final Set<String> _reportedGaps = {};

/// The pending catch-up cards of the active learner and their contents,
/// oldest first, without complete curricula or empty cards (AC-7, AC-9,
/// A-5). Loading while any input loads; an input error is this
/// provider's error, for the cards' inline retry (AC-11) — the windows
/// stay in [catchUpCardWindowsProvider], so the card remains available
/// until its window ends. Today's list never waits on it.
final catchUpCardsProvider = FutureProvider.autoDispose<List<CatchUpTaskCard>>((
  ref,
) async {
  final windows = await ref.watch(catchUpCardWindowsProvider.future);
  if (windows.isEmpty) return const [];
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) return const [];
  final planner = ref.watch(catchUpSequencePlannerProvider);
  final stateFuture = ref.watch(learnerStateProvider(scope).future);
  final tracksFuture = ref.watch(subTracksForScopeProvider(scope).future);
  final mainTasks = await planner(ref, [
    for (final w in windows)
      for (final d in w.lockedDays) d.date,
  ]);
  return projectCatchUpCards<DailyTask>(
    windows: windows,
    mainTasksByDay: mainTasks,
    curriculumOf: (task) => task.curriculumId.storageKey,
    state: await stateFuture,
    subTracks: await tracksFuture,
  );
}, retry: (retryCount, error) => null);

/// Re-reads the cards' failed inputs (the inline retry, AC-11): the
/// learner state only when it is what failed, so a retry never churns the
/// rest of the app.
void retryCatchUpCards(WidgetRef ref) {
  if (ref.read(activeLearnerStateProvider).hasError) {
    retryLearnerState(ref);
  }
  ref
    ..invalidate(subTracksForScopeProvider)
    ..invalidate(catchUpCardsProvider);
}
