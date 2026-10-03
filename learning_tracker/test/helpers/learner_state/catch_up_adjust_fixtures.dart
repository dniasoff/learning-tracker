/// Fixtures for the Story 3.4 (DNI-507) *Adjust…* selection tests: pending
/// catch-up cards over one to three locked days, built directly from
/// planner-shaped tasks and sub-track plans (no engine, no providers).
library;

import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/features/learning/domain/models/catch_up_selection.dart';
import 'package:learning_tracker/features/learning/domain/services/catch_up_selection_service.dart';

/// A planner-shaped main-track task: its leaf, stage and kind.
typedef AdjustTask = ({LeafRef ref, int stage, bool review});

/// A new-learning task on [ref] at [stage].
AdjustTask newTask(LeafRef ref, {int stage = 1}) =>
    (ref: ref, stage: stage, review: false);

/// A review task on [ref] at [stage].
AdjustTask reviewTask(LeafRef ref, {int stage = 3}) =>
    (ref: ref, stage: stage, review: true);

/// The Rebbe sub-track's id (the events' `source`).
const adjustRebbe = '01ARZ3NDEKTSV4RRFFQ69G5FAB';

/// The School sub-track's id.
const adjustSchool = '01ARZ3NDEKTSV4RRFFQ69G5FAC';

/// The curriculum of every fixture card.
const adjustCurriculum = 'mishnayos';

/// Yom Tov Thursday, Friday and Shabbos (a chained three-day lock).
const adjustDays = ['2026-10-01', '2026-10-02', '2026-10-03'];

/// Beitzah [perek]:[mishna].
LeafRef beitzah(int perek, int mishna) => 'Mishnah Beitzah $perek:$mishna';

/// Beitzah [perek]:[from] through [perek]:[to].
List<LeafRef> beitzahRun(int perek, int from, int to) => [
  for (var m = from; m <= to; m++) beitzah(perek, m),
];

/// A card window over [days] (ascending; the last is Shabbos).
CatchUpCardWindow adjustWindow({List<String> days = const ['2026-10-03']}) {
  final start = DateTime.utc(2026, 9, 30, 22);
  final end = DateTime.utc(2026, 10, 3, 23);
  return CatchUpCardWindow(
    lock: LockWindow(start, end),
    lockedDays: [
      for (final (i, d) in days.indexed)
        LockedDay(
          date: d,
          kind: i == days.length - 1
              ? LockedDayKind.shabbos
              : LockedDayKind.yomTov,
        ),
    ],
    allLockedDays: days.toSet(),
    window: UtcInterval(end, DateTime.utc(2026, 10, 5, 3, 59)),
    lastDay: '2026-10-04',
  );
}

/// One day of a fixture card: its main tasks and sub-track plans.
typedef AdjustDay = ({List<AdjustTask> main, Map<String, List<LeafRef>> subs});

/// A day with [main] tasks and [subs] (sub-track id to planned leaves).
AdjustDay adjustDay({
  List<AdjustTask> main = const [],
  Map<String, List<LeafRef>> subs = const {},
}) => (main: main, subs: subs);

/// The sub-track names of the fixtures.
const adjustNames = {adjustRebbe: 'Rebbe', adjustSchool: 'School'};

/// A one-curriculum card whose [days] map a locked day to what it plans.
CatchUpCard<AdjustTask> adjustCard(Map<String, AdjustDay> days) {
  final window = adjustWindow(days: days.keys.toList()..sort());
  return CatchUpCard<AdjustTask>(
    window: window,
    groups: [
      CatchUpCurriculumGroup<AdjustTask>(
        curriculumId: adjustCurriculum,
        days: [
          for (final day in window.lockedDays)
            CatchUpDayPlan<AdjustTask>(
              day: day,
              mainTasks: days[day.date]!.main,
              subTracks: [
                for (final MapEntry(:key, :value)
                    in days[day.date]!.subs.entries)
                  CatchUpSubTrackPlan(
                    subTrackId: key,
                    name: adjustNames[key] ?? key,
                    leaves: value,
                  ),
              ],
            ),
        ],
      ),
    ],
  );
}

/// The opening selection of [card].
CatchUpSelection adjustSelectionOf(CatchUpCard<AdjustTask> card) =>
    catchUpSelectionOf<AdjustTask>(
      card,
      refOf: (t) => t.ref,
      stageOf: (t) => t.stage,
      isNewLearning: (t) => !t.review,
    );

/// The key of [source]'s group on [day].
CatchUpGroupKey adjustKey(String source, String day) => CatchUpGroupKey(
  curriculumId: adjustCurriculum,
  source: source,
  learnedOn: day,
);
