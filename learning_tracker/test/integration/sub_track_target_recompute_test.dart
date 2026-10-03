// DNI-496 (Story 2.5) AC-4 / AC-5 / AC-6: what the ongoing form writes,
// run through the real `LearnerStateEngine` (Stories 2.2 / 2.3 derive it;
// the form computes none of it).
//
// - AC-4: a future start is off Learn (`onHome` false) yet holds its
//   ground now (`holdsGround`, prd-deviations #4); its capacity interval
//   starts at `window_start` (AD-44, Story 2.3): with a deadline before the
//   start it is not in the forecast and its capacity is 0; otherwise its
//   capacity is prorated over `[window_start, deadline]` against the
//   ongoing `windowLengthDays` of 365.
// - AC-6: an edit that sets an end date before today returns the unlearnt
//   ground to the main track and the daily target recomputes from the new
//   intent.
// - AC-5: two offline creates that both synced (six ongoing sub-tracks) are
//   tolerated by the engine without error (AD-45).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/sub_tracks/domain/ongoing_sub_track_form_validation.dart';

import '../helpers/learner_state/engine_fixtures.dart';

/// `engineAt(10000)` is 2026-09-07 (UTC learner).
const _today = '2026-09-07';

/// The row `createSubTrack` writes for the form's [values] (Story 2.1
/// stores the draft fields as they are; ground is added in Story 2.6).
SubTrack _created(
  int id,
  OngoingSubTrackValues values, {
  List<NodeEntry> ground = const [berakhot],
}) {
  final draft = values.toDraft(engineCurriculum);
  return SubTrack(
    id: engineUlid(id),
    curriculumId: draft.curriculumId,
    name: draft.name,
    type: draft.type,
    windowStart: draft.windowStart,
    windowEnd: draft.windowEnd,
    ratePerWeek: draft.ratePerWeek,
    weeksPerYear: draft.weeksPerYear,
    learnsOnShabbos: draft.learnsOnShabbos,
    ground: ground,
    lastChangeId: engineUlid(id + 1),
  );
}

/// [current] after `editSubTrack` applied the form's [values].
SubTrack _edited(SubTrack current, OngoingSubTrackValues values) {
  final edit = values.editFrom(current)!;
  return SubTrack(
    id: current.id,
    curriculumId: current.curriculumId,
    name: edit.name ?? current.name,
    type: current.type,
    windowStart: edit.windowStart ?? current.windowStart,
    windowEnd: edit.clearWindowEnd ? null : edit.windowEnd ?? current.windowEnd,
    ratePerWeek: edit.ratePerWeek ?? current.ratePerWeek,
    weeksPerYear: edit.weeksPerYear ?? current.weeksPerYear,
    learnsOnShabbos: edit.learnsOnShabbos ?? current.learnsOnShabbos,
    ground: current.ground,
    lastChangeId: engineUlid(900),
  );
}

OngoingSubTrackValues _form({
  String? start,
  String? end,
  String name = 'Rebbe',
}) => validateOngoingSubTrackForm(
  OngoingSubTrackFormInput(
    name: name,
    rateText: '5',
    weeksText: '52',
    start: start,
    end: end,
    learnsOnShabbos: false,
  ),
  today: _today,
).values!;

CurriculumState _run(List<SubTrack> subTracks, {String? deadline}) =>
    const LearnerStateEngine().run(
      engineInputs(
        subTracks: subTracks,
        goals: {
          if (deadline != null)
            engineCurriculum: CurriculumGoals(
              deadline: DeadlineGoal(
                curriculumId: engineCurriculum,
                targetDate: deadline,
              ),
            ),
        },
      ),
    )[engineCurriculum]!;

const _berakhotLeaves = [
  'Mishnah Berakhot 1:1',
  'Mishnah Berakhot 1:2',
  'Mishnah Berakhot 1:3',
  'Mishnah Berakhot 2:1',
  'Mishnah Berakhot 2:2',
];

void main() {
  test('fixture today is $_today', () {
    expect(engineAt(10000).toIso8601String(), startsWith(_today));
  });

  group('AC-4: a future-start ongoing sub-track', () {
    final future = _created(10, _form(start: '2026-10-01'));

    test('is off Learn but holds its ground at once', () {
      final baseline = _run(const []);
      final state = _run([future]);
      final s = state.subTracks[future.id]!;
      expect(s.onHome, isFalse);
      expect(s.holdsGround, isTrue);
      for (final leaf in _berakhotLeaves) {
        expect(state.schedulableRefs, isNot(contains(leaf)));
      }
      expect(
        state.mainTrackRemaining,
        baseline.mainTrackRemaining - _berakhotLeaves.length,
      );
    });

    test('its capacity interval starts at window_start', () {
      // Deadline before the start: empty interval, not in the forecast.
      expect(
        _run([future], deadline: '2026-09-30').subTracks[future.id]!.inForecast,
        isFalse,
      );
      // Deadline after the start: the interval is [start, deadline].
      expect(
        _run([future], deadline: '2026-12-31').subTracks[future.id]!.inForecast,
        isTrue,
      );
    });

    test('its capacity counts only from window_start (AD-44)', () {
      const deadline = '2026-12-31';
      // Empty interval: capacity 0, nothing credited to the main track.
      final before = _run([
        future,
      ], deadline: '2026-09-30').subTracks[future.id]!;
      expect(before.capacity, 0);
      expect(before.expectedNewGround, 0);

      // [2026-10-01, 2026-12-31] is 92 days, not the 116 from today:
      // floor(5 × 52 × 92 ÷ 365) = 65.
      final later = _run([future], deadline: deadline).subTracks[future.id]!;
      expect(later.capacity, 65);

      // The same track starting today counts from today:
      // [2026-09-07, 2026-12-31] is 116 days, floor(5 × 52 × 116 ÷ 365) = 82.
      final now = _created(12, _form());
      expect(_run([now], deadline: deadline).subTracks[now.id]!.capacity, 82);
    });

    test('a start of today is on Learn the same day', () {
      final now = _created(11, _form());
      expect(now.windowStart, _today);
      expect(_run([now]).subTracks[now.id]!.onHome, isTrue);
    });
  });

  group('AC-6: an end date before today', () {
    test(
      'leaves Learn, returns its unlearnt ground and recomputes the target',
      () {
        const deadline = '2026-12-31';
        final created = _created(20, _form(start: '2026-09-01'));
        final held = _run([created], deadline: deadline);
        expect(held.subTracks[created.id]!.onHome, isTrue);
        expect(held.subTracks[created.id]!.holdsGround, isTrue);

        final ended = _edited(
          created,
          _form(start: '2026-09-01', end: '2026-09-05', name: created.name),
        );
        expect(ended.windowEnd, '2026-09-05');
        final after = _run([ended], deadline: deadline);
        final s = after.subTracks[ended.id]!;
        expect(s.onHome, isFalse);
        expect(s.holdsGround, isFalse);
        for (final leaf in _berakhotLeaves) {
          expect(after.schedulableRefs, contains(leaf));
        }
        expect(
          after.mainTrackRemaining,
          held.mainTrackRemaining + _berakhotLeaves.length,
        );
        expect(held.dailyTarget, isNotNull);
        expect(after.dailyTarget, isNotNull);
        expect(after.dailyTarget, greaterThanOrEqualTo(held.dailyTarget!));
        expect(after, isNot(equals(held)));
      },
    );
  });

  group('AC-5: concurrent offline creates', () {
    test('six ongoing sub-tracks are tolerated by the engine', () {
      final six = [
        for (var i = 0; i < 6; i++)
          _created(
            100 + i * 2,
            _form(name: 'Rebbe $i'),
            ground: [if (i == 0) berakhot],
          ),
      ];
      expect(
        ongoingSubTracksInUse(
          six,
          curriculumId: engineCurriculum,
          today: _today,
        ),
        6,
      );
      final state = _run(six, deadline: '2026-12-31');
      expect(state.subTracks.keys, containsAll([for (final s in six) s.id]));
      expect(state.validationErrors, isEmpty);
    });
  });
}
