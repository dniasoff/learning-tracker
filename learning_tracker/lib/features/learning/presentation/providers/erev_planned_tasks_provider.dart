/// The erev view's data (Story 3.1, DNI-504): whether the Learn tab is in
/// the erev window of the next lock, and the planner's task list for each
/// locked day of that lock.
///
/// Nothing here computes a quantity or stores a plan (AD-49, deviation
/// #10). The window is [erevWindowAt] over the active learner's settings
/// history from [learnerLockSettingsProvider] (the one settings source of
/// the capture gate and the overlay, AD-36/AD-37). The planned days are the
/// shared planner's lists for those dates, laid out in sequence after
/// today's list over the live `LearnerState` ([watchPlannedDaysAfterToday]),
/// so a capture recomputes every planned section and today's list together.
///
/// Plain Riverpod providers (no codegen), matching
/// `learning_command_providers.dart`.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/scheduler/scheduler.dart';

/// One locked day of the erev lock and the planner's tasks for it.
final class ErevPlannedDay {
  /// Creates the day.
  ErevPlannedDay({required this.day, required List<DailyTask> tasks})
    : tasks = List.unmodifiable(tasks);

  /// The locked civil day.
  final LockedDay day;

  /// The planner's task list for [day], in the planner's order: new
  /// learning and calendar days, then reviews. Empty when nothing is
  /// planned for it.
  final List<DailyTask> tasks;

  @override
  String toString() => 'ErevPlannedDay(${day.date}, ${tasks.length} tasks)';
}

/// Lays out the planner's lists for [lockedDates] after today's list, over
/// the live learner state that [ref] watches (one list per date, in order).
typedef ErevSequencePlanner =
    Future<List<List<DailyTask>>> Function(
      Ref ref,
      List<CivilDate> lockedDates,
    );

/// The planner the erev view reads: [watchPlannedDaysAfterToday], the
/// shared planner (AD-49). Tests override it with a planner over a fake
/// state.
final erevSequencePlannerProvider = Provider<ErevSequencePlanner>(
  (ref) => watchPlannedDaysAfterToday,
);

/// The active learner's settings history, or null with no active learner.
/// An unreadable history is an error: the erev view then stays hidden and
/// the gate fails closed on its own read (AD-36).
final erevSettingsHistoryProvider =
    FutureProvider.autoDispose<LearnerSettingsHistory?>((ref) async {
      final scope = await ref.watch(activeLearnerScopeProvider.future);
      if (scope == null) return null;
      return ref.watch(learnerLockSettingsProvider(scope).future);
    }, retry: (retryCount, error) => null);

/// How long the erev window may go without a re-check when no boundary is
/// near (inside a lock, or no lock within the look-ahead).
const Duration erevRecheckInterval = Duration(minutes: 5);

/// The erev window at the commands' clock ([learningCommandClockProvider],
/// the instant `CaptureGate` judges), or null outside it (AC-1).
///
/// It re-evaluates itself at the next boundary (the erev start, then
/// `L.start`) and at least every [erevRecheckInterval], so the banner and
/// the planned sections disappear at `L.start` while the overlay takes
/// over (AC-8). A window computation that throws hides the view.
final erevWindowProvider = FutureProvider.autoDispose<ErevWindow?>((ref) async {
  final clock = ref.watch(learningCommandClockProvider);
  final history = await ref.watch(erevSettingsHistoryProvider.future);
  if (history == null) return null;
  final now = clock().toUtc();
  var delay = erevRecheckInterval;
  ErevWindow? window;
  try {
    window = erevWindowAt(history, now);
    final next = nextErevTransition(history, now);
    if (next != null) {
      final untilNext = next.difference(now);
      if (untilNext < delay) delay = untilNext;
    }
  } on Object {
    window = null; // fail closed: no erev view
  }
  // Fire just after the boundary, never in a tight loop.
  final wait = delay <= Duration.zero
      ? const Duration(milliseconds: 1)
      : delay + const Duration(milliseconds: 1);
  final timer = Timer(wait, ref.invalidateSelf);
  ref.onDispose(timer.cancel);
  return window;
}, retry: (retryCount, error) => null);

/// The planner's task list for each locked day of the erev lock, in
/// locked-day order (AC-2, AC-4, AC-5), or null outside the erev window.
///
/// Its loading and error states belong to the planned region only (AC-10):
/// today's list reads its own provider and is never gated by this one.
final erevPlannedDaysProvider =
    FutureProvider.autoDispose<List<ErevPlannedDay>?>((ref) async {
      final window = await ref.watch(erevWindowProvider.future);
      if (window == null) return null;
      final days = window.lockedDays;
      if (days.isEmpty) return const [];
      final planner = ref.watch(erevSequencePlannerProvider);
      final lists = await planner(ref, [for (final d in days) d.date]);
      return [
        for (var i = 0; i < days.length; i++)
          ErevPlannedDay(
            day: days[i],
            tasks: i < lists.length ? lists[i] : const [],
          ),
      ];
    }, retry: (retryCount, error) => null);
