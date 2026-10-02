// DNI-504 T2/T8 (AC-2, AC-4, AC-5, AC-7 and the partial-plan / recompute
// edges): the erev planned sections are the shared planner's task lists
// for the locked dates, laid out in sequence after today's list over the
// live LearnerState, and recompute when the state changes.
//
// Mirrors `lib/features/learning/presentation/providers/
// erev_planned_tasks_provider.dart` and the DNI-504 additions to
// `lib/features/scheduler/domain/services/daily_task_projection_service.dart`
// (`buildPlannedSequence`, `mainTrackAfter`, `laidOut`).
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/erev_window.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/features/learning/presentation/providers/erev_planned_tasks_provider.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/scheduler/domain/models/daily_task.dart';
import 'package:learning_tracker/features/scheduler/domain/services/daily_task_projection_service.dart';
import 'package:learning_tracker/features/tracks/setup/domain/entities/curriculum_track.dart';

import '../../../helpers/learner_state/engine_fixtures.dart';
import '../../../helpers/learner_state/fake_learner_state.dart';
import '../../../helpers/learner_state/lock_fixtures.dart';

const _c = CurriculumId.mishnayos;

// Pesach 2027 in Lakewood: Wednesday 04-21 is erev; Thursday 04-22 and
// Friday 04-23 are yom tov (diaspora) and Shabbos 04-24 follows.
const _wed = '2027-04-21';
const _thu = '2027-04-22';
const _fri = '2027-04-23';
const _sat = '2027-04-24';

// The engine fixture corpus: Berakhot (1:1, 1:2, 1:3, 2:1, 2:2), Peah
// (1:1, 1:2), Shabbat (1:1, 1:2).
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';
const _b13 = 'Mishnah Berakhot 1:3';
const _b21 = 'Mishnah Berakhot 2:1';
const _b22 = 'Mishnah Berakhot 2:2';
const _p11 = 'Mishnah Peah 1:1';
const _p12 = 'Mishnah Peah 1:2';
const _s11 = 'Mishnah Shabbat 1:1';
const _s12 = 'Mishnah Shabbat 1:2';

final Corpus _corpus = mishnayosCorpus();

const _stages = {1: 'Learn', 2: 'Chazara A'};

final _tracks = [
  CurriculumTrackEntity(
    curriculumId: _c,
    state: 'active',
    stateChangedAt: DateTime.utc(2026),
    activatedAt: DateTime.utc(2026),
  ),
];

CurriculumTaskPresentation _presentation({
  bool studyDay = true,
  Map<String, ProgramDayLabel>? labels,
}) => CurriculumTaskPresentation(
  trackLabel: 'Mishnayos',
  stageNames: _stages,
  studyDay: studyDay,
  programDayLabels: labels,
);

/// A Berakhot 2 learner: [schedulable] in engine order, [pace] leaves a
/// day, [reviews] by date.
FakeCurriculumState _learner({
  List<String> schedulable = const [_b21, _b22, _p11, _p12, _s11, _s12],
  Set<String> learnt = const {},
  double pace = 2,
  Map<String, List<ReviewDue>> reviews = const {},
  Map<String, List<String>> assignments = const {},
  Map<String, List<String>> backlog = const {},
}) => FakeCurriculumState(
  curriculumId: _c.storageKey,
  learntLeaves: learnt,
  currentUnit: schedulable.isEmpty ? null : _unitFor(schedulable.first),
  mainTrackPosition: schedulable.isEmpty ? null : schedulable.first,
  schedulableRefs: schedulable,
  mainTrackRemaining: schedulable.length,
  paceRate: pace,
  reviews: reviews,
  assignments: assignments,
  backlog: backlog,
);

NodeEntry _unitFor(String leaf) => leaf.startsWith('Mishnah Berakhot')
    ? berakhot
    : leaf.startsWith('Mishnah Peah')
    ? peah
    : shabbat;

LearnerState _state(FakeCurriculumState c) =>
    fakeLearnerState(curricula: {_c.storageKey: c}, today: _wed);

Future<List<List<DailyTask>>> _sequence(
  LearnerState state, {
  List<String> dates = const [_wed, _thu, _fri, _sat],
  bool Function(String date)? studyDay,
  Map<String, ProgramDayLabel>? labels,
}) => buildPlannedSequence(
  state: state,
  corpora: {_c.storageKey: _corpus},
  dates: dates,
  activeCurricula: const [_c],
  activeTracks: _tracks,
  presentationFor: (_, date) async =>
      _presentation(studyDay: studyDay?.call(date) ?? true, labels: labels),
);

List<String> _refs(List<DailyTask> tasks) =>
    tasks.map((t) => t.contentItemSefariaRef).toList();

void main() {
  group('AC-2 / AC-4: sequential planner lists, no leaf in two sections', () {
    test(
      'today, Thursday, Friday and Shabbos continue in engine order',
      () async {
        final lists = await _sequence(_state(_learner()));
        expect(lists.map(_refs).toList(), [
          [_b21, _b22], // today
          [_p11, _p12], // Thursday: the next masechta begins (FR-12a)
          [_s11, _s12], // Friday
          <String>[], // Shabbos: the corpus is used up
        ]);
        final all = [for (final l in lists) ...l.map(plannedTaskKey)];
        expect(all.toSet(), hasLength(all.length), reason: 'no duplicates');
      },
    );

    test('each section is the shared planner list for its date, given what '
        'the earlier dates hold', () async {
      final state = _state(_learner(pace: 1));
      final lists = await _sequence(state);
      final laidOut = <PlannedTaskKey>{};
      for (final (i, date) in [_wed, _thu, _fri, _sat].indexed) {
        final expected = await buildPlannedTasks(
          state: state,
          corpora: {_c.storageKey: _corpus},
          date: date,
          activeCurricula: const [_c],
          activeTracks: _tracks,
          presentationFor: (_) async => _presentation(),
          laidOut: {...laidOut},
        );
        final list = [...expected.learning, ...expected.reviews];
        expect(lists[i], list, reason: date);
        laidOut.addAll(list.map(plannedTaskKey));
      }
      // Today's list is exactly plannedTasksForDate(today): nothing laid
      // out before it.
      final today = await buildPlannedTasks(
        state: state,
        corpora: {_c.storageKey: _corpus},
        date: _wed,
        activeCurricula: const [_c],
        activeTracks: _tracks,
        presentationFor: (_) async => _presentation(),
      );
      expect(lists.first, [...today.learning, ...today.reviews]);
    });

    test('the quantity is the engine\'s: a dailyTarget lays out that many '
        'per date, never a view count', () async {
      final state = _state(
        FakeCurriculumState(
          curriculumId: _c.storageKey,
          currentUnit: berakhot,
          mainTrackPosition: _b21,
          schedulableRefs: const [_b21, _b22, _p11, _p12, _s11, _s12],
          dailyTarget: 1,
          paceRate: 5,
        ),
      );
      final lists = await _sequence(state);
      expect(lists.map(_refs).toList(), [
        [_b21],
        [_b22],
        [_p11],
        [_p12],
      ]);
    });
  });

  group('AC-2: reviewsDue chazara tasks and calendar programAssignments', () {
    test(
      'reviews due on each locked date show once, at their first date',
      () async {
        final state = _state(
          _learner(
            pace: 0,
            reviews: {
              _wed: [const ReviewDue(_b11, 2, dueFrom: _wed)],
              // Still due (overdue) on Thursday, plus a new one.
              _thu: [
                const ReviewDue(_b11, 2, dueFrom: _wed),
                const ReviewDue(_b12, 2, dueFrom: _thu),
              ],
              _sat: [const ReviewDue(_b13, 2, dueFrom: _sat)],
            },
          ),
        );
        final lists = await _sequence(state);
        expect(lists.map(_refs).toList(), [
          [_b11],
          [_b12],
          <String>[],
          [_b13],
        ]);
        expect(
          lists[1].single.priority,
          DailyTaskPriority.scheduledChazara,
          reason: 'a chazara task with its stage',
        );
        expect(lists[1].single.stageOrder, 2);
      },
    );

    test('calendar program: each date shows programAssignments(date); the '
        'backlog never repeats an earlier date\'s leaves', () async {
      final state = _state(
        _learner(
          assignments: {
            _wed: [_b11],
            _thu: [_b12],
            _fri: [_b13],
            _sat: [_b21],
          },
          // The engine's backlog before a future date includes the
          // still-unlearnt assignments of today and the earlier dates.
          backlog: {
            _thu: [_b11],
            _fri: [_b11, _b12],
            _sat: [_b11, _b12, _b13],
          },
        ),
      );
      final lists = await _sequence(state, labels: const {});
      expect(lists.map(_refs).toList(), [
        [_b11],
        [_b12],
        [_b13],
        [_b21],
      ]);
      expect(lists[1].single.priority, DailyTaskPriority.todayProgram);
    });
  });

  group('AC-7 / partial plans', () {
    test('nothing planned for any locked date gives empty lists', () async {
      final lists = await _sequence(
        _state(_learner(schedulable: const [], pace: 0)),
      );
      expect(lists.skip(1), everyElement(isEmpty));
    });

    test('a review-only Shabbos is empty while the other dates show', () async {
      final lists = await _sequence(
        _state(_learner(pace: 1)),
        studyDay: (date) => date != _sat,
      );
      expect(lists.map(_refs).toList(), [
        [_b21],
        [_b22],
        [_p11],
        <String>[],
      ]);
    });
  });

  group('mainTrackAfter', () {
    test('moves the position past the laid-out leaves, keeping the unit only '
        'while the position is unchanged', () {
      final start = MainTrackDayStart(
        schedulableRefs: const [_b21, _b22, _p11, _p12],
        currentUnit: berakhot,
        position: _b21,
      );
      expect(mainTrackAfter(start, const {}), same(start));
      final after = mainTrackAfter(start, const {_b21, _b22});
      expect(after.schedulableRefs, [_p11, _p12]);
      expect(after.position, _p11);
      expect(after.currentUnit, isNull);
      final unmoved = mainTrackAfter(start, const {_p11});
      expect(unmoved.position, _b21);
      expect(unmoved.currentUnit, berakhot);
      expect(unmoved.schedulableRefs, [_b21, _b22, _p12]);
    });

    test('everything laid out leaves nothing to schedule', () {
      final after = mainTrackAfter(
        MainTrackDayStart(schedulableRefs: const [_b21], position: _b21),
        const {_b21},
      );
      expect(after.schedulableRefs, isEmpty);
      expect(after.position, isNull);
    });
  });

  group(
    'erevPlannedDaysProvider (AC-2 live, AC-4/AC-5 days, Edge recompute)',
    () {
      late ProviderContainer container;
      late DateTime now;
      final stateProvider = NotifierProvider<_StateHolder, LearnerState>(
        _StateHolder.new,
      );

      ProviderContainer build(LearnerSettingsHistory history) {
        final c = ProviderContainer(
          overrides: [
            erevSettingsHistoryProvider.overrideWith((ref) async => history),
            learningCommandClockProvider.overrideWithValue(() => now),
            erevSequencePlannerProvider.overrideWithValue((ref, dates) async {
              final state = ref.watch(stateProvider);
              final lists = await _sequence(
                state,
                dates: [state.today, ...dates],
              );
              return lists.sublist(1);
            }),
          ],
        );
        addTearDown(c.dispose);
        return c;
      }

      Future<List<ErevPlannedDay>?> read() async {
        final sub = container.listen(erevPlannedDaysProvider, (_, _) {});
        addTearDown(sub.close);
        return container.read(erevPlannedDaysProvider.future);
      }

      setUp(() {
        now = LearnerZone.of(
          'America/New_York',
        ).at(DateTime.utc(2027, 4, 21), hour: 12);
      });

      test(
        'diaspora: three sections Thursday, Friday, Shabbos in sequence',
        () async {
          container = build(constantHistory(lakewood));
          final days = (await read())!;
          expect([for (final d in days) d.day.date], [_thu, _fri, _sat]);
          expect(
            [for (final d in days) _refs(d.tasks)],
            [
              [_p11, _p12],
              [_s11, _s12],
              <String>[],
            ],
          );
          expect(days.first.day.kind, LockedDayKind.yomTov);
        },
      );

      test('Israel: one section, Thursday', () async {
        container = build(
          constantHistory(
            lockSettings(
              latitude: 40.0821,
              longitude: -74.2097,
              inIsrael: true,
            ),
          ),
        );
        final days = (await read())!;
        expect([for (final d in days) d.day.date], [_thu]);
      });

      test('outside the erev window there are no planned days', () async {
        now = LearnerZone.of(
          'America/New_York',
        ).at(DateTime.utc(2027, 4, 20), hour: 12);
        container = build(constantHistory(lakewood));
        expect(await read(), isNull);
      });

      test('a capture recomputes every planned section, with no frozen '
          'snapshot (Edge: a later date loses a leaf learnt now)', () async {
        container = build(constantHistory(lakewood));
        final sub = container.listen(erevPlannedDaysProvider, (_, _) {});
        addTearDown(sub.close);
        final before = (await container.read(erevPlannedDaysProvider.future))!;
        expect(_refs(before.first.tasks), [_p11, _p12]);

        // The child ticks Thursday's Peah 1:1 today: the engine's state no
        // longer schedules it.
        final sw = Stopwatch()..start();
        container
            .read(stateProvider.notifier)
            .set(
              _state(
                _learner(
                  schedulable: const [_b21, _b22, _p12, _s11, _s12],
                  learnt: const {_p11},
                ),
              ),
            );
        final after = (await container.read(erevPlannedDaysProvider.future))!;
        sw.stop();
        expect(
          [for (final d in after) _refs(d.tasks)],
          [
            [_p12, _s11],
            [_s12],
            <String>[],
          ],
        );
        final all = [for (final d in after) ...d.tasks.map(plannedTaskKey)];
        expect(all.toSet(), hasLength(all.length));
        expect(sw.elapsed, lessThan(const Duration(seconds: 1)));
      });

      test(
        'the banner flips off at L.start (the window re-evaluates)',
        () async {
          container = build(constantHistory(lakewood));
          final sub = container.listen(erevWindowProvider, (_, _) {});
          addTearDown(sub.close);
          final window = (await container.read(erevWindowProvider.future))!;
          now = window.lock.startUtc;
          container.invalidate(erevWindowProvider);
          expect(await container.read(erevWindowProvider.future), isNull);
          expect(await container.read(erevPlannedDaysProvider.future), isNull);
        },
      );
    },
  );
}

/// The fake engine output the provider test's planner watches.
class _StateHolder extends Notifier<LearnerState> {
  @override
  LearnerState build() => _state(_learner());

  void set(LearnerState next) => state = next;
}
