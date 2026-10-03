// DNI-506 (Story 3.3) T1 / AC-1: *Yes, all of it* expands a pending card
// into one action — one leaf per listed main task and sub-track leaf,
// dated to the locked day it is listed under, with the planner stage on
// main-track leaves only.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/features/learning/domain/commands/catch_up_commands.dart';
import 'package:learning_tracker/features/sub_tracks/domain/services/catch_up_action_builder.dart';

import '../../../../helpers/learner_state/catch_up_card_harness.dart';
import '../../../../helpers/learner_state_fixtures.dart';

typedef _Task = ({String ref, int stage});

CatchUpCardWindow _window() =>
    catchUpCardWindowsAt(catchUpHistory, catchUpSunday).single;

CatchUpDayPlan<_Task> _day(
  CatchUpCardWindow w, {
  List<_Task> main = const [],
  List<CatchUpSubTrackPlan> subs = const [],
}) => CatchUpDayPlan<_Task>(
  day: w.lockedDays.single,
  mainTasks: main,
  subTracks: subs,
);

CatchUpAction _build(CatchUpCard<_Task> card) => buildCatchUpAllAction<_Task>(
  card,
  refOf: (t) => t.ref,
  stageOf: (t) => t.stage,
);

void main() {
  test('every main task and sub-track leaf becomes one dated leaf', () {
    final w = _window();
    final card = CatchUpCard<_Task>(
      window: w,
      groups: [
        CatchUpCurriculumGroup<_Task>(
          curriculumId: 'mishnayos',
          days: [
            _day(
              w,
              main: [
                (ref: 'Mishnah Berakhot 2:1', stage: 1),
                (ref: 'Mishnah Berakhot 1:5', stage: 3),
              ],
              subs: [
                CatchUpSubTrackPlan(
                  subTrackId: ulidB,
                  name: 'Rebbe',
                  leaves: const ['Mishnah Peah 1:1', 'Mishnah Peah 1:2'],
                ),
              ],
            ),
          ],
        ),
        CatchUpCurriculumGroup<_Task>(
          curriculumId: 'bavli',
          days: [
            _day(w, main: [(ref: 'Berakhot 2a', stage: 1)]),
          ],
        ),
      ],
    );
    final action = _build(card);
    expect(action.lock, w.lock);
    expect(action.mode, CatchUpMode.all);
    expect(action.lockedDaysOffered, 1);
    expect(action.leaves, const [
      CatchUpLeaf(
        curriculumId: 'mishnayos',
        ref: 'Mishnah Berakhot 2:1',
        source: 'main',
        learnedOn: catchUpShabbos,
        stage: 1,
      ),
      CatchUpLeaf(
        curriculumId: 'mishnayos',
        ref: 'Mishnah Berakhot 1:5',
        source: 'main',
        learnedOn: catchUpShabbos,
        stage: 3,
      ),
      CatchUpLeaf(
        curriculumId: 'mishnayos',
        ref: 'Mishnah Peah 1:1',
        source: ulidB,
        learnedOn: catchUpShabbos,
      ),
      CatchUpLeaf(
        curriculumId: 'mishnayos',
        ref: 'Mishnah Peah 1:2',
        source: ulidB,
        learnedOn: catchUpShabbos,
      ),
      CatchUpLeaf(
        curriculumId: 'bavli',
        ref: 'Berakhot 2a',
        source: 'main',
        learnedOn: catchUpShabbos,
        stage: 1,
      ),
    ]);
    expect(action.curricula, ['mishnayos', 'bavli']);
  });

  test('each leaf takes the locked day it is listed under', () {
    final w = _window();
    // A yom tov + Shabbos card stands in with three hand-made days.
    const days = [
      LockedDay(date: '2026-10-08', kind: LockedDayKind.yomTov),
      LockedDay(date: '2026-10-09', kind: LockedDayKind.yomTov),
      LockedDay(date: '2026-10-10', kind: LockedDayKind.shabbos),
    ];
    final card = CatchUpCard<_Task>(
      window: w,
      groups: [
        CatchUpCurriculumGroup<_Task>(
          curriculumId: 'mishnayos',
          days: [
            for (final (i, d) in days.indexed)
              CatchUpDayPlan<_Task>(
                day: d,
                mainTasks: [(ref: 'Mishnah Berakhot 1:${i + 1}', stage: 1)],
                subTracks: const [],
              ),
          ],
        ),
      ],
    );
    expect(
      [for (final l in _build(card).leaves) (l.ref, l.learnedOn)],
      [
        ('Mishnah Berakhot 1:1', '2026-10-08'),
        ('Mishnah Berakhot 1:2', '2026-10-09'),
        ('Mishnah Berakhot 1:3', '2026-10-10'),
      ],
    );
  });

  test('a leaf listed twice for one day, source and stage is kept once', () {
    final w = _window();
    final card = CatchUpCard<_Task>(
      window: w,
      groups: [
        CatchUpCurriculumGroup<_Task>(
          curriculumId: 'mishnayos',
          days: [
            _day(
              w,
              main: [
                (ref: 'Mishnah Berakhot 2:1', stage: 1),
                (ref: 'Mishnah Berakhot 2:1', stage: 1),
                (ref: 'Mishnah Berakhot 2:1', stage: 2),
              ],
            ),
          ],
        ),
      ],
    );
    expect([for (final l in _build(card).leaves) l.stage], [1, 2]);
  });
}
