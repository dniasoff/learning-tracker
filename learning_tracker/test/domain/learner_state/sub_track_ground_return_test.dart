// Story 2.8 (DNI-499) AC-6: a sub-track whose window passes with no user
// action returns its ground by derivation alone (AD-33, AD-34): the engine
// recomputes on the learner's civil today (AD-41), with no `ended_at`
// stamp, repository write or change-log entry anywhere in the path.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

/// School: perek 2 of Berakhot and Peah, window Jan–6 Sep 2026.
final _school = SubTrack(
  id: engineUlid(10),
  curriculumId: engineCurriculum,
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: 2025,
  windowStart: '2026-01-01',
  windowEnd: '2026-09-06',
  ratePerWeek: 2,
  weeksPerYear: 36,
  learnsOnShabbos: false,
  ground: const [berakhot2, peah],
  lastChangeId: engineUlid(11),
);

/// A second, still-active holder of Peah 1:2.
final _rebbe = SubTrack(
  id: engineUlid(20),
  curriculumId: engineCurriculum,
  name: 'Rebbe',
  type: SubTrackType.ongoing,
  windowStart: '2026-09-01',
  ratePerWeek: 2,
  weeksPerYear: 40,
  learnsOnShabbos: false,
  ground: const [NodeEntry(level: 'mishnah', ref: 'Mishnah Peah 1:2')],
  lastChangeId: engineUlid(21),
);

/// Berakhot 2:1 was learnt through School before its window ended.
final _events = [engineLearn(1, 'Mishnah Berakhot 2:1', source: _school.id)];

LearnerSettingsHistory _zone(String timeZone) =>
    LearnerSettingsHistory.constant(
      LearnerSettings(profileId: profileUlid, timeZone: timeZone),
    );

CurriculumState _run(
  DateTime nowUtc, {
  String timeZone = 'UTC',
  List<SubTrack>? subTracks,
}) => const LearnerStateEngine().run(
  engineInputs(
    events: _events,
    subTracks: subTracks ?? [_school, _rebbe],
    nowUtc: nowUtc,
    settingsHistory: _zone(timeZone),
    goals: {
      engineCurriculum: const CurriculumGoals(
        deadline: DeadlineGoal(
          curriculumId: engineCurriculum,
          targetDate: '2026-09-20',
        ),
      ),
    },
  ),
)[engineCurriculum]!;

void main() {
  // 6 Sep is School's last (inclusive) day; 7 Sep is the first after it.
  final lastDay = DateTime.utc(2026, 9, 6, 12);
  final dayAfter = DateTime.utc(2026, 9, 7, 12);

  test('on window_end School still holds its ground (inclusive end)', () {
    final state = _run(lastDay);
    expect(state.subTracks[_school.id]!.holdsGround, isTrue);
    expect(state.schedulableRefs, [
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
    ]);
  });

  test('the day after, unlearnt unheld leaves return at their main-track '
      'order; the learnt leaf and the leaf Rebbe still holds do not', () {
    final before = _run(lastDay);
    final after = _run(dayAfter);
    final school = after.subTracks[_school.id]!;
    expect(school.holdsGround, isFalse);
    expect(school.onHome, isFalse, reason: 'absent from Learn (AD-34)');
    expect(after.subTracks[_rebbe.id]!.holdsGround, isTrue);
    expect(after.schedulableRefs, [
      'Mishnah Berakhot 1:1',
      'Mishnah Berakhot 1:2',
      'Mishnah Berakhot 1:3',
      'Mishnah Berakhot 2:2',
      'Mishnah Peah 1:1',
      'Mishnah Shabbat 1:1',
      'Mishnah Shabbat 1:2',
    ]);
    expect(after.schedulableRefs, isNot(contains('Mishnah Berakhot 2:1')));
    expect(after.schedulableRefs, isNot(contains('Mishnah Peah 1:2')));
    // The main schedule and the daily target recompute from the return.
    expect(after.mainTrackRemaining, before.mainTrackRemaining + 2);
    expect(before.dailyTarget, isNotNull);
    expect(after.dailyTarget, isNotNull);
    expect(after.dailyTarget, greaterThanOrEqualTo(before.dailyTarget!));
    // The learnt leaf keeps counting; School's events are untouched.
    expect(after.learntLeaves, contains('Mishnah Berakhot 2:1'));
  });

  test('an expired window derives the same return as an explicit end, with '
      'no ended_at stamped on the stored row', () {
    final expired = _run(dayAfter);
    final explicit = _run(
      dayAfter,
      subTracks: [
        SubTrack(
          id: _school.id,
          curriculumId: _school.curriculumId,
          name: _school.name,
          type: _school.type,
          academicYear: _school.academicYear,
          windowStart: _school.windowStart,
          windowEnd: '2026-12-31',
          ratePerWeek: _school.ratePerWeek,
          weeksPerYear: _school.weeksPerYear,
          learnsOnShabbos: _school.learnsOnShabbos,
          ground: _school.ground,
          lastChangeId: _school.lastChangeId,
          endedAt: engineAt(1),
          endReason: SubTrackEndReason.ended,
        ),
        _rebbe,
      ],
    );
    expect(expired.schedulableRefs, explicit.schedulableRefs);
    expect(expired.mainTrackRemaining, explicit.mainTrackRemaining);
    expect(_school.endedAt, isNull);
    expect(_school.endReason, isNull);
    expect(_school.toStorage().containsKey(SubTrack.kEndedAt), isFalse);
  });

  test("expiry follows the learner's civil date, not UTC (AD-41)", () {
    // 22:30 UTC on 6 Sep is 01:30 on 7 Sep in Jerusalem (UTC+3).
    final lateUtc = DateTime.utc(2026, 9, 6, 22, 30);
    expect(_run(lateUtc).subTracks[_school.id]!.holdsGround, isTrue);
    expect(
      _run(
        lateUtc,
        timeZone: 'Asia/Jerusalem',
      ).subTracks[_school.id]!.holdsGround,
      isFalse,
    );
  });

  test('the engine is pure: the inputs are not mutated by a recompute', () {
    final events = List<LearningEvent>.of(_events);
    final rows = [_school.toStorage(), _rebbe.toStorage()];
    _run(dayAfter);
    expect(_events, events);
    expect([_school.toStorage(), _rebbe.toStorage()], rows);
  });
}
