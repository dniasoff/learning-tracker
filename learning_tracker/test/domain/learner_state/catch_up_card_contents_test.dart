// DNI-505 (Story 3.2) T5: what a pending catch-up card lists (AC-7, AC-8,
// AC-9, AC-10, A-3, A-4, A-5, EC-2).
//
// The main-track rows are the shared planner's lists (Story 3.1), passed
// in; here they are plain (curriculum, leaf) records. Locks come from the
// canonical functions over fixed learner-zone instants; no wall clock.

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/catch_up_card_projection.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/report_projection.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/fake_learner_state.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

typedef _Task = (String curriculum, String leaf);

const _mishnayos = 'mishnayos';
const _bavli = 'bavli';

DateTime _day(int y, int m, int d) => DateTime.utc(y, m, d);

SubTrack _track(
  String id, {
  String name = 'Rebbe',
  String curriculumId = _mishnayos,
  bool learnsOnShabbos = true,
  double ratePerWeek = 7,
  String windowStart = '2026-09-01',
  String? windowEnd,
  List<NodeEntry> ground = const [
    NodeEntry(level: 'masechet', ref: 'Mishnah_Peah'),
  ],
  DateTime? endedAt,
}) => SubTrack(
  id: id,
  curriculumId: curriculumId,
  name: name,
  type: SubTrackType.ongoing,
  windowStart: windowStart,
  windowEnd: windowEnd,
  ratePerWeek: ratePerWeek,
  weeksPerYear: 40,
  learnsOnShabbos: learnsOnShabbos,
  ground: ground,
  lastChangeId: '01ARZ3NDEKTSV4RRFFQ69G5FAC',
  endedAt: endedAt,
  endReason: endedAt == null ? null : SubTrackEndReason.ended,
);

SubTrackState _state(
  String id,
  List<String> path, {
  Set<String> recordedAhead = const {},
}) => SubTrackState(
  subTrackId: id,
  holdsGround: true,
  inForecast: true,
  onHome: true,
  position: path.isEmpty ? null : path.first,
  remainingPath: path,
  recordedAhead: recordedAhead,
);

LearnerState _learner(
  Map<String, Map<String, SubTrackState>> subTracks, {
  List<LearningEvent> countedLearns = const [],
  Set<String> calendarCurricula = const {},
  Set<String> notEvaluated = const {},
}) => fakeLearnerState(
  curricula: {
    for (final MapEntry(key: c, value: tracks) in subTracks.entries)
      c: FakeCurriculumState(
        curriculumId: c,
        evaluated: !notEvaluated.contains(c),
        subTracks: tracks,
        report: calendarCurricula.contains(c)
            ? ReportProjection(
                curriculumId: c,
                distinctLearnt: 0,
                totalEvents: 0,
                sources: const {},
                calendarProgram: true,
              )
            : null,
      ),
  },
  countedLearns: countedLearns,
);

LearningEvent _learn(
  String id, {
  required DateState dateState,
  required String learnedOn,
  required DateTime at,
  String curriculumId = _mishnayos,
  String source = LearningEvent.sourceMain,
}) => LearningEvent.learn(
  id: id,
  curriculumId: curriculumId,
  ref: 'Mishnah_Berakhot_2.1',
  source: source,
  dateState: dateState,
  learnedOn: learnedOn,
  stage: 1,
  recordedAt: at,
  actor: parentActor,
);

void main() {
  final ny = LearnerZone.of('America/New_York');
  // A plain Shabbos (2026-10-10), no-location fallback, seen on Sunday.
  final shabbos = catchUpCardWindowsAt(
    constantHistory(newYorkNoLocation),
    ny.at(_day(2026, 10, 11), hour: 12),
  );
  final saturday = shabbos.single.lockedDays.single.date;

  List<CatchUpCard<_Task>> project({
    List<CatchUpCardWindow>? windows,
    List<List<_Task>> main = const [],
    required LearnerState state,
    List<SubTrack> subTracks = const [],
  }) => projectCatchUpCards<_Task>(
    windows: windows ?? shabbos,
    mainTasksByDay: main,
    curriculumOf: (t) => t.$1,
    state: state,
    subTracks: subTracks,
  );

  group('AC-7: main planner tasks and eligible sub-tracks only', () {
    test('lists the planner tasks for D and onHome, flagged sub-tracks', () {
      final cards = project(
        main: [
          [
            (_mishnayos, 'Mishnah_Berakhot_2.1'),
            (_mishnayos, 'Mishnah_Berakhot_2.2'),
          ],
        ],
        state: _learner({
          _mishnayos: {
            'rebbe': _state('rebbe', ['Mishnah_Peah_1.1', 'Mishnah_Peah_1.2']),
            'school': _state('school', ['Mishnah_Demai_1.1']),
            'ended': _state('ended', ['Mishnah_Kilayim_1.1']),
            'future': _state('future', ['Mishnah_Sheviit_1.1']),
            'bare': _state('bare', const []),
          },
        }),
        subTracks: [
          _track('rebbe', ratePerWeek: 10),
          _track('school', name: 'School', learnsOnShabbos: false),
          _track('ended', name: 'Ended', endedAt: DateTime.utc(2026, 10, 1)),
          _track('future', name: 'Future', windowStart: '2026-10-11'),
          _track('bare', name: 'Bare', ground: const []),
        ],
      );
      final card = cards.single;
      expect(card.mainTaskCount, 2);
      final group = card.groups.single;
      expect(group.curriculumId, _mishnayos);
      final day = group.days.single;
      expect(day.day.date, saturday);
      expect(day.mainTasks, hasLength(2));
      // ceil(10 / 7) = 2 leaves from the position (A-3).
      expect(day.subTracks.single.subTrackId, 'rebbe');
      expect(day.subTracks.single.leaves, [
        'Mishnah_Peah_1.1',
        'Mishnah_Peah_1.2',
      ]);
    });

    test('a sub-track whose window ended before D never appears', () {
      final card = project(
        main: [
          [(_mishnayos, 'Mishnah_Berakhot_2.1')],
        ],
        state: _learner({
          _mishnayos: {
            'rebbe': _state('rebbe', ['Mishnah_Peah_1.1']),
          },
        }),
        subTracks: [_track('rebbe', windowEnd: '2026-10-09')],
      ).single;
      expect(card.groups.single.days.single.subTracks, isEmpty);
    });

    test('skips leaves the sub-track already recorded ahead', () {
      final card = project(
        state: _learner({
          _mishnayos: {
            'rebbe': _state(
              'rebbe',
              ['Mishnah_Peah_1.1', 'Mishnah_Peah_1.2', 'Mishnah_Peah_1.3'],
              recordedAhead: {'Mishnah_Peah_1.2'},
            ),
          },
        }),
        subTracks: [_track('rebbe', ratePerWeek: 14)],
      ).single;
      expect(card.groups.single.days.single.subTracks.single.leaves, [
        'Mishnah_Peah_1.1',
        'Mishnah_Peah_1.3',
      ]);
      // Only a sub-track planned something: no main count.
      expect(card.mainTaskCount, 0);
    });
  });

  group('AC-8: the current learns_on_shabbos value decides', () {
    final state = _learner({
      _mishnayos: {
        'rebbe': _state('rebbe', ['Mishnah_Peah_1.1']),
      },
    });
    final main = [
      [(_mishnayos, 'Mishnah_Berakhot_2.1')],
    ];

    test('flag on: the group is listed; flag off: it is gone', () {
      final on = project(
        main: main,
        state: state,
        subTracks: [_track('rebbe')],
      ).single;
      expect(on.groups.single.days.single.subTracks, hasLength(1));
      final off = project(
        main: main,
        state: state,
        subTracks: [_track('rebbe', learnsOnShabbos: false)],
      ).single;
      expect(off.groups.single.days.single.subTracks, isEmpty);
      expect(off.window, on.window);
    });
  });

  group('AC-9: nothing planned', () {
    test('no main tasks and no flagged onHome sub-track: no card', () {
      expect(
        project(
          main: [const []],
          state: _learner({
            _mishnayos: {
              'school': _state('school', ['Mishnah_Demai_1.1']),
            },
          }),
          subTracks: [_track('school', learnsOnShabbos: false)],
        ),
        isEmpty,
      );
    });
  });

  group('A-5 / AC-10: completion from counted catch_up events', () {
    final lock = shabbos.single.lock;
    final main = [
      [(_mishnayos, 'Mishnah_Berakhot_2.1')],
    ];
    final afterLock = lock.endUtc.add(const Duration(hours: 10));

    test('a counted catch_up for a locked day hides the card', () {
      final state = _learner(
        {_mishnayos: const {}},
        countedLearns: [
          _learn(
            'e1',
            dateState: DateState.catchUp,
            learnedOn: saturday,
            at: afterLock,
          ),
        ],
      );
      expect(catchUpRecorded(shabbos.single, _mishnayos, state), isTrue);
      expect(project(main: main, state: state), isEmpty);
    });

    test(
      'undo: with the event voided (no longer counted) the card is back',
      () {
        final state = _learner({_mishnayos: const {}});
        expect(project(main: main, state: state), hasLength(1));
      },
    );

    test('a dated event, another day or another curriculum does not '
        'complete it', () {
      final state = _learner(
        {_mishnayos: const {}},
        countedLearns: [
          _learn(
            'e1',
            dateState: DateState.dated,
            learnedOn: '2026-10-11',
            at: afterLock,
          ),
          _learn(
            'e2',
            dateState: DateState.catchUp,
            learnedOn: '2026-10-03',
            at: afterLock,
          ),
          _learn(
            'e3',
            dateState: DateState.catchUp,
            learnedOn: saturday,
            at: afterLock,
            curriculumId: _bavli,
          ),
        ],
      );
      expect(project(main: main, state: state), hasLength(1));
    });

    test('a sub-track catch_up counts for its curriculum too', () {
      final state = _learner(
        {_mishnayos: const {}},
        countedLearns: [
          _learn(
            'e1',
            dateState: DateState.catchUp,
            learnedOn: saturday,
            at: afterLock,
            source: '01ARZ3NDEKTSV4RRFFQ69G5FAA',
          ),
        ],
      );
      expect(project(main: main, state: state), isEmpty);
    });
  });

  group('EC-2: curriculum scope', () {
    test('each curriculum keeps its own tasks and sub-track positions', () {
      final card = project(
        main: [
          [(_mishnayos, 'Mishnah_Berakhot_2.1'), (_bavli, 'Berakhot.4a')],
        ],
        state: _learner({
          _mishnayos: {
            'rebbe': _state('rebbe', ['Mishnah_Peah_1.1']),
          },
          _bavli: {
            'chavrusa': _state('chavrusa', ['Shabbat.2a']),
          },
        }),
        subTracks: [
          _track('rebbe'),
          _track('chavrusa', name: 'Chavrusa', curriculumId: _bavli),
        ],
      ).single;
      expect(card.groups.map((g) => g.curriculumId), [_mishnayos, _bavli]);
      expect(card.groups.last.days.single.subTracks.single.leaves, [
        'Shabbat.2a',
      ]);
      expect(card.groups.last.days.single.mainTasks, [(_bavli, 'Berakhot.4a')]);
    });

    test('a curriculum that is not evaluated or follows a calendar program '
        'contributes no sub-track', () {
      final cards = project(
        state: _learner(
          {
            _mishnayos: {
              'rebbe': _state('rebbe', ['Mishnah_Peah_1.1']),
            },
            _bavli: {
              'chavrusa': _state('chavrusa', ['Shabbat.2a']),
            },
          },
          notEvaluated: {_mishnayos},
          calendarCurricula: {_bavli},
        ),
        subTracks: [
          _track('rebbe'),
          _track('chavrusa', curriculumId: _bavli),
        ],
      );
      expect(cards, isEmpty);
    });
  });

  group('A-4: stacked cards continue in sequence', () {
    final h = constantHistory(jerusalem);
    final jlm = LearnerZone.of('Asia/Jerusalem');
    final stacked = catchUpCardWindowsAt(h, jlm.at(_day(2027, 4, 25), hour: 9));

    test('each card takes its own planner list; sub-tracks continue', () {
      final cards = project(
        windows: stacked,
        main: [
          [(_mishnayos, 'Mishnah_Berakhot_2.1')],
          [(_mishnayos, 'Mishnah_Berakhot_2.2')],
        ],
        state: _learner({
          _mishnayos: {
            'rebbe': _state('rebbe', ['Mishnah_Peah_1.1', 'Mishnah_Peah_1.2']),
          },
        }),
        subTracks: [_track('rebbe')],
      );
      expect(cards, hasLength(2));
      final [a, b] = cards;
      expect(
        a.groups.single.days.single.mainTasks.single.$2,
        'Mishnah_Berakhot_2.1',
      );
      expect(
        b.groups.single.days.single.mainTasks.single.$2,
        'Mishnah_Berakhot_2.2',
      );
      expect(a.groups.single.days.single.subTracks.single.leaves, [
        'Mishnah_Peah_1.1',
      ]);
      expect(b.groups.single.days.single.subTracks.single.leaves, [
        'Mishnah_Peah_1.2',
      ]);
    });
  });

  group('A-4 / A-5: a completed card before a pending one', () {
    final h = constantHistory(jerusalem);
    final jlm = LearnerZone.of('Asia/Jerusalem');
    final stacked = catchUpCardWindowsAt(h, jlm.at(_day(2027, 4, 25), hour: 9));

    test('the completed card takes no sub-track leaves; the pending card '
        'continues from the position', () {
      final [first, second] = stacked;
      final cards = project(
        windows: stacked,
        main: [
          const <_Task>[],
          [(_mishnayos, 'Mishnah_Berakhot_2.2')],
        ],
        state: _learner(
          {
            _mishnayos: {
              'rebbe': _state('rebbe', [
                'Mishnah_Peah_1.1',
                'Mishnah_Peah_1.2',
              ]),
            },
          },
          countedLearns: [
            _learn(
              'e1',
              dateState: DateState.catchUp,
              learnedOn: first.lockedDays.single.date,
              at: second.lock.endUtc.add(const Duration(minutes: 1)),
            ),
          ],
        ),
        subTracks: [_track('rebbe')],
      );
      final card = cards.single;
      expect(card.window, second);
      expect(card.groups.single.days.single.subTracks.single.leaves, [
        'Mishnah_Peah_1.1',
      ]);
    });
  });

  test('A-3: the daily amount is ceil(rate ÷ 7), 0 for a bad rate', () {
    expect(catchUpSubTrackDailyAmount(_track('a', ratePerWeek: 7)), 1);
    expect(catchUpSubTrackDailyAmount(_track('a', ratePerWeek: 8)), 2);
    expect(catchUpSubTrackDailyAmount(_track('a', ratePerWeek: 0.5)), 1);
    expect(catchUpSubTrackDailyAmount(_track('a', ratePerWeek: 0)), 0);
  });
}
