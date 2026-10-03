/// Catch-up cards (Story 3.2, DNI-505): which locks have a pending card at
/// an instant, and what each card lists.
///
/// Pure. Every lock, locked day and window comes from the AD-36 / AD-40
/// functions in `lock_windows.dart` ([lockWindows], [lockedDays],
/// [catchUpWindow]); nothing here computes a lock, a locked day or a window
/// any other way (AC-1).
///
/// ## Availability (AC-1, AC-2, AC-6)
///
/// A lock `L` has a card from just after `L.end` through the end of
/// `catchUpWindow(L)`, unless it is complete. The window counts only
/// non-locked time: while a later lock `B` is in force no card is pending
/// (the lock overlay covers the app, deviation #10), and after `B.end` the
/// card of `L` is pending again beside `B`'s. Cards are oldest first (A-4).
/// The window's end is the last instant of its last civil day, so a card
/// for a plain Shabbos is gone at 00:00 Monday learner-local.
///
/// ## Completion (A-5)
///
/// A curriculum's part of a card is complete once a counted `catch_up`
/// learn event of that curriculum, effective after `L.end`, has
/// `learned_on` on one of `L`'s locked days. It is derived from the
/// engine's counted events, never stored, so every device on the profile
/// agrees and a void (undo) brings the card back. A card with no
/// incomplete curriculum that plans anything is not shown (UX-DR-131).
///
/// ## At most three days (AC-5)
///
/// AD-40 caps a card at three consecutive locked days. A settings history
/// that yields more for one lock is inconsistent: the card keeps the three
/// latest days and reports the dropped ones as a [CatchUpHistoryGap]
/// (reason [CatchUpHistoryGap.reason]) for the caller to log. It never
/// throws and never yields an empty card.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_filter.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/predicates.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

/// The most locked days one catch-up card covers (AD-40).
const int maxCatchUpLockedDays = 3;

/// The locked-day function a card reads: [lockedDays] in production. Only
/// tests pass another one, to stand in for an inconsistent settings
/// history the real calendar cannot produce (AC-5).
typedef LockedDaysFunction =
    Set<CivilDate> Function(LockWindow lock, LearnerSettingsHistory history);

/// A lock whose locked days exceed [maxCatchUpLockedDays] (AC-5): the card
/// kept the latest three and dropped [droppedDays].
final class CatchUpHistoryGap {
  /// Creates the gap.
  CatchUpHistoryGap({required this.lock, required List<CivilDate> droppedDays})
    : droppedDays = List.unmodifiable(droppedDays);

  /// The structured-log reason for this gap (B13 default; no PII).
  static const String reason = 'catch_up_history_gap';

  /// The lock with too many locked days.
  final LockWindow lock;

  /// The earlier locked days the card does not cover, ascending.
  final List<CivilDate> droppedDays;

  @override
  String toString() => 'CatchUpHistoryGap($lock, dropped $droppedDays)';
}

/// One lock whose catch-up card is available at an instant: the lock, its
/// (at most three) locked days and its catch-up window.
final class CatchUpCardWindow {
  /// Creates the window.
  CatchUpCardWindow({
    required this.lock,
    required List<LockedDay> lockedDays,
    required Set<CivilDate> allLockedDays,
    required this.window,
    required this.lastDay,
    this.gap,
  }) : lockedDays = List.unmodifiable(lockedDays),
       allLockedDays = Set.unmodifiable(allLockedDays);

  /// The lock `L`, exactly as [lockWindows] returned it.
  final LockWindow lock;

  /// The locked days the card covers, ascending: [lockedDays] of `L`, at
  /// most the latest [maxCatchUpLockedDays]. Never empty.
  final List<LockedDay> lockedDays;

  /// Every locked day of `L`, including any the card dropped (AC-5): a
  /// `catch_up` event for one of them still completes the card.
  final Set<CivilDate> allLockedDays;

  /// `catchUpWindow(L)`: the card is available while it holds the instant
  /// and no lock does.
  final UtcInterval window;

  /// The last civil day of [window] (the `time_zone` in force at `L.end`):
  /// the card's "Available until the end of {day}".
  final CivilDate lastDay;

  /// Set when `L` has more than [maxCatchUpLockedDays] locked days.
  final CatchUpHistoryGap? gap;

  /// What the covered days are, for the card's day label (A-2).
  ErevKind get kind => lockKindOf(lockedDays);

  /// The first instant the card is gone: just after [window] ends.
  DateTime get expiresAtUtc => window.endUtc.add(civilTick);

  /// A stable key for the card: its lock's start.
  String get key => lock.startUtc.toIso8601String();

  @override
  bool operator ==(Object other) {
    if (other is! CatchUpCardWindow ||
        other.lock != lock ||
        other.window != window ||
        other.lastDay != lastDay ||
        other.lockedDays.length != lockedDays.length ||
        other.allLockedDays.length != allLockedDays.length ||
        !other.allLockedDays.containsAll(allLockedDays) ||
        (other.gap == null) != (gap == null)) {
      return false;
    }
    for (var i = 0; i < lockedDays.length; i++) {
      if (other.lockedDays[i] != lockedDays[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode =>
      Object.hash(lock, window, lastDay, Object.hashAll(lockedDays));

  @override
  String toString() =>
      'CatchUpCardWindow($lock, ${lockedDays.map((d) => d.date)}, '
      'until $lastDay)';
}

/// The catch-up cards available at [nowUtc], oldest lock first (AC-1,
/// AC-6, A-4): every lock that ended before [nowUtc] whose
/// `catchUpWindow` holds [nowUtc] and has at least one locked day. Empty
/// while [nowUtc] is inside a lock: each window pauses then.
///
/// Completion (A-5) is not applied here; [projectCatchUpCards] drops
/// complete curricula and empty cards. [lockedDaysOf] is for tests only
/// (see [LockedDaysFunction]).
List<CatchUpCardWindow> catchUpCardWindowsAt(
  LearnerSettingsHistory history,
  DateTime nowUtc, {
  LockedDaysFunction lockedDaysOf = lockedDays,
}) {
  final now = nowUtc.toUtc();
  final locks = lockWindows(history, now.subtract(catchUpReach), now);
  if (locks.any((l) => l.contains(now))) return const [];
  final out = <CatchUpCardWindow>[];
  for (final lock in locks) {
    if (!lock.endUtc.isBefore(now)) continue;
    final window = catchUpWindow(lock, history);
    if (!window.contains(now)) continue;
    final card = _cardWindow(lock, window, history, lockedDaysOf);
    if (card != null) out.add(card);
  }
  return out;
}

/// The next instant after [nowUtc] at which [catchUpCardWindowsAt] may
/// change because of time alone: a pending card's expiry, the start of
/// the next lock (cards pause), or the end of the lock [nowUtc] is inside
/// (cards resume or appear). Null when none falls within a week; callers
/// still re-check periodically.
DateTime? nextCatchUpTransition(
  LearnerSettingsHistory history,
  DateTime nowUtc,
) {
  final now = nowUtc.toUtc();
  final candidates = <DateTime>[];
  for (final card in catchUpCardWindowsAt(history, now)) {
    candidates.add(card.expiresAtUtc);
  }
  for (final lock in lockWindows(
    history,
    now,
    now.add(const Duration(days: 7)),
  )) {
    if (lock.contains(now)) {
      candidates.add(lock.endUtc.add(civilTick));
    } else if (lock.startUtc.isAfter(now)) {
      candidates.add(lock.startUtc);
    }
  }
  if (candidates.isEmpty) return null;
  candidates.sort();
  return candidates.first;
}

CatchUpCardWindow? _cardWindow(
  LockWindow lock,
  UtcInterval window,
  LearnerSettingsHistory history,
  LockedDaysFunction lockedDaysOf,
) {
  final all = lockedDaysOf(lock, history);
  if (all.isEmpty) return null; // never an empty card (AC-5)
  final sorted = all.toList()..sort();
  final kept = sorted.length > maxCatchUpLockedDays
      ? sorted.sublist(sorted.length - maxCatchUpLockedDays)
      : sorted;
  final dropped = sorted.sublist(0, sorted.length - kept.length);
  final inIsrael = history.at(lock.startUtc).inIsrael ?? false;
  final zone = LearnerZone.of(history.at(lock.endUtc).timeZone);
  return CatchUpCardWindow(
    lock: lock,
    lockedDays: [
      for (final d in kept)
        LockedDay(
          date: d,
          kind: lockedDayKindOf(d, inIsrael: inIsrael),
        ),
    ],
    allLockedDays: all,
    window: window,
    lastDay: formatCivilDay(zone.dayOf(window.endUtc)),
    gap: dropped.isEmpty
        ? null
        : CatchUpHistoryGap(lock: lock, droppedDays: dropped),
  );
}

/// Whether curriculum [curriculumId]'s part of [card] is complete (A-5):
/// [state] counts a `catch_up` learn event of that curriculum, effective
/// after the lock ended, whose `learned_on` is one of the lock's locked
/// days. A voided or lock-ignored event is not counted, so it never
/// completes a card.
bool catchUpRecorded(
  CatchUpCardWindow card,
  String curriculumId,
  LearnerState state,
) {
  for (final e in state.countedLearns) {
    if (e.curriculumId != curriculumId ||
        e.dateState != DateState.catchUp ||
        !card.allLockedDays.contains(e.learnedOn) ||
        !effectiveAt(e).isAfter(card.lock.endUtc)) {
      continue;
    }
    return true;
  }
  return false;
}

/// One sub-track's planned leaves for one locked day (A-3).
final class CatchUpSubTrackPlan {
  /// Creates the plan.
  CatchUpSubTrackPlan({
    required this.subTrackId,
    required this.name,
    required List<LeafRef> leaves,
  }) : leaves = List.unmodifiable(leaves);

  /// The sub-track ULID (the events' `source`).
  final String subTrackId;

  /// Its name.
  final String name;

  /// Its planned leaves for the day, in its path order. Never empty.
  final List<LeafRef> leaves;

  @override
  String toString() => 'CatchUpSubTrackPlan($subTrackId, $leaves)';
}

/// One locked day of one curriculum on a card: the main-track planner's
/// tasks for it and the planned leaves of each eligible sub-track.
final class CatchUpDayPlan<T> {
  /// Creates the day.
  CatchUpDayPlan({
    required this.day,
    required List<T> mainTasks,
    required List<CatchUpSubTrackPlan> subTracks,
  }) : mainTasks = List.unmodifiable(mainTasks),
       subTracks = List.unmodifiable(subTracks);

  /// The locked day.
  final LockedDay day;

  /// The planner's tasks of this curriculum for [day], in planner order.
  final List<T> mainTasks;

  /// The sub-tracks planned on [day], in hub order.
  final List<CatchUpSubTrackPlan> subTracks;

  /// Whether nothing is planned on [day] for this curriculum.
  bool get isEmpty => mainTasks.isEmpty && subTracks.isEmpty;
}

/// One evaluated curriculum's part of a card (AC-7, EC-2).
final class CatchUpCurriculumGroup<T> {
  /// Creates the group.
  CatchUpCurriculumGroup({
    required this.curriculumId,
    required List<CatchUpDayPlan<T>> days,
  }) : days = List.unmodifiable(days);

  /// The curriculum storage key.
  final String curriculumId;

  /// Its locked days that plan something, ascending.
  final List<CatchUpDayPlan<T>> days;

  /// Its main-track planner tasks over every day.
  int get mainTaskCount => days.fold(0, (sum, d) => sum + d.mainTasks.length);
}

/// A pending catch-up card and what it lists.
final class CatchUpCard<T> {
  /// Creates the card.
  CatchUpCard({
    required this.window,
    required List<CatchUpCurriculumGroup<T>> groups,
  }) : groups = List.unmodifiable(groups);

  /// The lock, its covered days and its window.
  final CatchUpCardWindow window;

  /// Each incomplete curriculum that plans something, in order. Never
  /// empty.
  final List<CatchUpCurriculumGroup<T>> groups;

  /// The main-track planner tasks of every group: the card question's
  /// `{n}` ([ASSUMPTION] main track only; sub-track amounts show under
  /// their own groups).
  int get mainTaskCount => groups.fold(0, (sum, g) => sum + g.mainTaskCount);

  @override
  String toString() =>
      'CatchUpCard(${window.key}, ${groups.map((g) => g.curriculumId)})';
}

/// A sub-track's planned amount per locked day (A-3):
/// `ceil(rate_per_week ÷ 7)`, 0 for a non-positive or non-finite rate.
int catchUpSubTrackDailyAmount(SubTrack track) {
  final rate = track.ratePerWeek;
  if (!rate.isFinite || rate <= 0) return 0;
  return (rate / 7).ceil();
}

/// The contents of the pending [windows] (oldest first), dropping complete
/// curricula (A-5) and cards that plan nothing (AC-9, UX-DR-131).
///
/// [mainTasksByDay] holds the shared planner's task list (AD-49, Story
/// 3.1) for every covered locked day of [windows], in order — the first
/// card's days, then the next card's — already laid out in sequence, so a
/// later card continues after an earlier one (A-4). [curriculumOf] names a
/// task's curriculum (storage key).
///
/// Per evaluated curriculum that does not follow a calendar program, each
/// sub-track of [subTracks] is planned on locked day `D` iff
/// `onHome(s, D)`, its current `learns_on_shabbos` is true, it has ground,
/// and the engine has its state: [catchUpSubTrackDailyAmount] leaves from
/// its position along its remaining path (skipping leaves it already
/// recorded ahead), continuing across the days and cards in order (A-3,
/// A-4). Ended, future-start, groundless and unflagged sub-tracks never
/// appear (AC-7).
List<CatchUpCard<T>> projectCatchUpCards<T>({
  required List<CatchUpCardWindow> windows,
  required List<List<T>> mainTasksByDay,
  required String Function(T task) curriculumOf,
  required LearnerState state,
  required List<SubTrack> subTracks,
}) {
  final tracks = [
    for (final s in subTracks)
      if (_plannable(s, state)) s,
  ]..sort(_hubOrder);
  // Each sub-track's unplanned path, consumed across days and cards.
  final cursors = <String, List<LeafRef>>{
    for (final s in tracks) s.id: _path(s, state),
  };
  final cards = <CatchUpCard<T>>[];
  var dayIndex = 0;
  for (final window in windows) {
    final mainByCurriculum = <String, Map<CivilDate, List<T>>>{};
    final curriculumOrder = <String>[];
    void seen(String c) {
      if (!curriculumOrder.contains(c)) curriculumOrder.add(c);
    }

    for (final day in window.lockedDays) {
      final tasks = dayIndex < mainTasksByDay.length
          ? mainTasksByDay[dayIndex]
          : <T>[];
      dayIndex++;
      for (final task in tasks) {
        final c = curriculumOf(task);
        seen(c);
        ((mainByCurriculum[c] ??= {})[day.date] ??= []).add(task);
      }
    }
    final subsByCurriculum =
        <String, Map<CivilDate, List<CatchUpSubTrackPlan>>>{};
    for (final day in window.lockedDays) {
      for (final s in tracks) {
        if (!s.learnsOnShabbos || !onHome(s, day.date)) continue;
        final amount = catchUpSubTrackDailyAmount(s);
        final path = cursors[s.id]!;
        if (amount == 0 || path.isEmpty) continue;
        final take = path.length < amount ? path.length : amount;
        final leaves = path.sublist(0, take);
        cursors[s.id] = path.sublist(take);
        seen(s.curriculumId);
        ((subsByCurriculum[s.curriculumId] ??= {})[day.date] ??= []).add(
          CatchUpSubTrackPlan(subTrackId: s.id, name: s.name, leaves: leaves),
        );
      }
    }
    final groups = <CatchUpCurriculumGroup<T>>[];
    for (final c in curriculumOrder) {
      if (catchUpRecorded(window, c, state)) continue;
      final days = <CatchUpDayPlan<T>>[
        for (final day in window.lockedDays)
          CatchUpDayPlan<T>(
            day: day,
            mainTasks: mainByCurriculum[c]?[day.date] ?? const [],
            subTracks: subsByCurriculum[c]?[day.date] ?? const [],
          ),
      ]..removeWhere((d) => d.isEmpty);
      if (days.isNotEmpty) {
        groups.add(CatchUpCurriculumGroup<T>(curriculumId: c, days: days));
      }
    }
    if (groups.isNotEmpty) {
      cards.add(CatchUpCard<T>(window: window, groups: groups));
    }
  }
  return cards;
}

/// Whether [s] can ever be planned on a card: live, with ground, of an
/// evaluated curriculum that does not follow a calendar program, with an
/// engine state. The per-day `onHome` and `learns_on_shabbos` checks are
/// separate.
bool _plannable(SubTrack s, LearnerState state) {
  if (s.isEnded || s.ground.isEmpty) return false;
  final curriculum = state.curricula[s.curriculumId];
  if (curriculum == null || !curriculum.evaluated) return false;
  if (curriculum.report.calendarProgram) return false;
  return curriculum.subTracks.containsKey(s.id);
}

/// [s]'s remaining path from its position, less what it recorded ahead.
List<LeafRef> _path(SubTrack s, LearnerState state) {
  final st = state.curricula[s.curriculumId]!.subTracks[s.id]!;
  return [
    for (final leaf in st.remainingPath)
      if (!st.recordedAhead.contains(leaf)) leaf,
  ];
}

/// Hub order: `window_start`, then name, then id (as the Learn rows).
int _hubOrder(SubTrack a, SubTrack b) {
  final byStart = a.windowStart.compareTo(b.windowStart);
  if (byStart != 0) return byStart;
  final byName = a.name.compareTo(b.name);
  return byName != 0 ? byName : a.id.compareTo(b.id);
}
