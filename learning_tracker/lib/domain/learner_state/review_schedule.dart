/// Engine stage 6b: the AD-32 spaced-review schedule, the only review
/// scheduler (AD-35 "Review schedule").
///
/// * A cycle starts only from a counted `source = main` `dated`/`catch_up`
///   leaf event whose `stage` is the first stage order in force at its
///   `effectiveAt`. A leaf learnt only via a sub-track, a free tick (no
///   stage) or before-tracking has no cycle. One cycle per leaf: its
///   earliest qualifying event.
/// * Each step is computed under the `mainTrackStages` and
///   `mainTrackStudyDays` in force at the `effectiveAt` of the event that
///   completed the previous step: the next stage is the lowest stage order
///   above the previous one, and its schedule is read from that config.
/// * A step is completed by the first counted main event on the leaf, after
///   the previous step's event, carrying exactly that stage, even one made
///   before the step was due. [ReviewSchedule.dueForAttempt] (AD-50
///   earning) therefore judges an attempt without that completion marker,
///   so an early attempt never stops a later due one from earning.
library;

import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/main_track_config_history.dart';
import 'package:learning_tracker/domain/learner_state/study_days.dart';

/// One step of a review cycle: [leaf] at [stageOrder].
final class ReviewStep {
  /// Creates a step.
  const ReviewStep({
    required this.leaf,
    required this.stageOrder,
    required this.scheduleType,
    required this.openedOn,
    required this.openedAt,
    required this.openedBy,
    required this.dueFrom,
    this.daysOfWeek = const {},
    this.windowSize,
    this.completedOn,
  });

  /// The leaf.
  final LeafRef leaf;

  /// The stage this step reviews.
  final int stageOrder;

  /// How it is scheduled.
  final StageScheduleType scheduleType;

  /// Civil date the previous step was completed.
  final CivilDate openedOn;

  /// `effectiveAt` of the event that completed the previous step (rolling
  /// rank).
  final DateTime openedAt;

  /// Id of the event that completed the previous step (with [openedAt], its
  /// place in engine order).
  final String openedBy;

  /// First civil date the step can be due: for a delay stage,
  /// `openedOn + delay_days` moved to the next active study-days weekday;
  /// otherwise [openedOn].
  final CivilDate dueFrom;

  /// ISO weekdays of a weekly stage.
  final Set<int> daysOfWeek;

  /// Window size of a rolling stage.
  final int? windowSize;

  /// Civil date of the event that completed this step, if any.
  final CivilDate? completedOn;

  /// Whether the step is still open on [date]: opened by then and not
  /// completed before it (a step completed on [date] was due that day).
  bool openOn(CivilDate date) =>
      openedOn.compareTo(date) <= 0 &&
      (completedOn == null || completedOn!.compareTo(date) >= 0);

  @override
  bool operator ==(Object other) =>
      other is ReviewStep &&
      other.leaf == leaf &&
      other.stageOrder == stageOrder &&
      other.scheduleType == scheduleType &&
      other.openedOn == openedOn &&
      other.openedAt == openedAt &&
      other.openedBy == openedBy &&
      other.dueFrom == dueFrom &&
      other.daysOfWeek.length == daysOfWeek.length &&
      other.daysOfWeek.containsAll(daysOfWeek) &&
      other.windowSize == windowSize &&
      other.completedOn == completedOn;

  @override
  int get hashCode => Object.hash(
    leaf,
    stageOrder,
    scheduleType,
    openedOn,
    openedAt,
    openedBy,
    dueFrom,
    Object.hashAllUnordered(daysOfWeek),
    windowSize,
    completedOn,
  );

  @override
  String toString() => 'ReviewStep($leaf, $stageOrder, due $dueFrom)';
}

/// Every review step of one curriculum, queried by civil date.
final class ReviewSchedule {
  /// Creates a schedule over [steps] (in cycle-start order).
  ReviewSchedule(List<ReviewStep> steps) : steps = List.unmodifiable(steps);

  /// The steps, in cycle-start order.
  final List<ReviewStep> steps;

  late final Map<ReviewDue, ReviewStep> _byPair = {
    for (final s in steps) ReviewDue(s.leaf, s.stageOrder): s,
  };

  /// The step reviewing [leaf] at [stageOrder], or null when no cycle has
  /// opened it. A leaf has one cycle and a stage appears once in it.
  ReviewStep? stepFor(LeafRef leaf, int stageOrder) =>
      _byPair[ReviewDue(leaf, stageOrder)];

  /// Rolling-window rank: most recently opened first, then by leaf.
  static int _rollingRank(ReviewStep a, ReviewStep b) {
    final byTime = b.openedAt.compareTo(a.openedAt);
    return byTime != 0 ? byTime : a.leaf.compareTo(b.leaf);
  }

  /// Whether [step] (one of [steps]) is due on [date] for an attempt made
  /// that day (AD-50 earning).
  ///
  /// This is [dueOn] with [step] treated as still open on [date] once it
  /// has opened, whatever its completion marker says: the scheduler closes
  /// a step on the first event carrying its stage even when that event was
  /// made before the step was due, and such an early attempt must not stop
  /// a later due attempt from earning. The other steps' completions still
  /// decide a rolling window.
  bool dueForAttempt(ReviewStep step, CivilDate date) {
    if (step.openedOn.compareTo(date) > 0) return false;
    switch (step.scheduleType) {
      case StageScheduleType.delay:
        return step.dueFrom.compareTo(date) <= 0;
      case StageScheduleType.weekly:
        return step.daysOfWeek.contains(weekdayOf(date));
      case StageScheduleType.rolling:
        final size = step.windowSize;
        if (size == null) return false;
        var ahead = 0;
        for (final s in steps) {
          if (identical(s, step) ||
              s.scheduleType != StageScheduleType.rolling ||
              s.stageOrder != step.stageOrder ||
              !s.openOn(date)) {
            continue;
          }
          if (_rollingRank(s, step) < 0) ahead++;
        }
        return ahead < size;
    }
  }

  /// The (leaf, `stage_order`) pairs due on [date], in cycle-start order.
  ///
  /// * delay: due on every date from `dueFrom` while open (an overdue
  ///   review stays due until it is done);
  /// * weekly: due on the stage's weekdays while open;
  /// * rolling: due while open and among the `rolling_window_size` most
  ///   recently opened open steps of that stage on [date].
  ///
  /// A step completed on [date] still counts as due on [date], so the
  /// schedule for a past date is what was due that day (AD-50 earning).
  List<ReviewDue> dueOn(CivilDate date) {
    final rollingOpen = <int, List<ReviewStep>>{};
    for (final s in steps) {
      if (s.scheduleType == StageScheduleType.rolling && s.openOn(date)) {
        (rollingOpen[s.stageOrder] ??= []).add(s);
      }
    }
    final rollingDue = <ReviewStep>{};
    for (final list in rollingOpen.values) {
      final ranked = [...list]..sort(_rollingRank);
      for (var i = 0; i < ranked.length; i++) {
        final size = ranked[i].windowSize;
        if (size != null && i < size) rollingDue.add(ranked[i]);
      }
    }
    final weekday = weekdayOf(date);
    final out = <ReviewDue>[];
    for (final s in steps) {
      if (!s.openOn(date)) continue;
      final due = switch (s.scheduleType) {
        StageScheduleType.delay => s.dueFrom.compareTo(date) <= 0,
        StageScheduleType.weekly => s.daysOfWeek.contains(weekday),
        StageScheduleType.rolling => rollingDue.contains(s),
      };
      if (due) out.add(ReviewDue(s.leaf, s.stageOrder));
    }
    return List.unmodifiable(out);
  }

  @override
  bool operator ==(Object other) {
    if (other is! ReviewSchedule || other.steps.length != steps.length) {
      return false;
    }
    for (var i = 0; i < steps.length; i++) {
      if (other.steps[i] != steps[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(steps);
}

/// The review schedule of one curriculum.
///
/// [countedLearns] are its counted `learn` events in engine order
/// (`effectiveAt`, then id). [inScope] limits cycles to the learner's
/// corpus. [fallbackFirstStage] is the curriculum's first stage order when
/// no stage doc is in force at an event (see `firstStageOrder`); with no
/// stage in force there is no next step either.
ReviewSchedule deriveReviewSchedule({
  required List<LearningEvent> countedLearns,
  required Corpus corpus,
  required bool Function(LeafRef leaf) inScope,
  required MainTrackConfigHistory configHistory,
  required LearnerSettingsHistory settingsHistory,
  required int? fallbackFirstStage,
}) {
  final byLeaf = <LeafRef, List<LearningEvent>>{};
  for (final e in countedLearns) {
    final ref = e.ref;
    if (e.source != LearningEvent.sourceMain ||
        e.stage == null ||
        e.level != null ||
        ref == null ||
        (e.dateState != DateState.dated && e.dateState != DateState.catchUp)) {
      continue;
    }
    final node = corpus.nodeForRef(ref);
    if (node == null || !corpus.isLeaf(node) || !inScope(ref)) continue;
    (byLeaf[ref] ??= []).add(e);
  }

  CivilDate dayOf(LearningEvent e) =>
      e.learnedOn ?? civilDate(effectiveAt(e), settingsHistory);

  final cycles = <(LearningEvent, List<ReviewStep>)>[];
  for (final MapEntry(key: leaf, value: events) in byLeaf.entries) {
    var startIndex = -1;
    for (var i = 0; i < events.length; i++) {
      final first =
          configHistory.at(effectiveAt(events[i])).firstStageOrder ??
          fallbackFirstStage;
      if (first != null && events[i].stage == first) {
        startIndex = i;
        break;
      }
    }
    if (startIndex < 0) continue;
    final steps = <ReviewStep>[];
    var prevIndex = startIndex;
    while (true) {
      final prev = events[prevIndex];
      final config = configHistory.at(effectiveAt(prev));
      final next = config.stageAfter(prev.stage!);
      if (next == null) break;
      var doneIndex = -1;
      for (var i = prevIndex + 1; i < events.length; i++) {
        if (events[i].stage == next.stageOrder) {
          doneIndex = i;
          break;
        }
      }
      final openedOn = dayOf(prev);
      steps.add(
        ReviewStep(
          leaf: leaf,
          stageOrder: next.stageOrder,
          scheduleType: next.scheduleType,
          openedOn: openedOn,
          openedAt: effectiveAt(prev),
          openedBy: prev.id,
          dueFrom: next.scheduleType == StageScheduleType.delay
              ? config.studyDays.nextActiveOnOrAfter(
                  shiftCivilDate(openedOn, next.delayDays),
                )
              : openedOn,
          daysOfWeek: next.daysOfWeek,
          windowSize: next.rollingWindowSize,
          completedOn: doneIndex < 0 ? null : dayOf(events[doneIndex]),
        ),
      );
      if (doneIndex < 0) break;
      prevIndex = doneIndex;
    }
    cycles.add((events[startIndex], steps));
  }
  cycles.sort((a, b) {
    final byTime = effectiveAt(a.$1).compareTo(effectiveAt(b.$1));
    return byTime != 0 ? byTime : a.$1.id.compareTo(b.$1.id);
  });
  return ReviewSchedule([for (final c in cycles) ...c.$2]);
}
