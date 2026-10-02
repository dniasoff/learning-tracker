/// DNI-481 (1.19) AC-6: an event whose `effectiveAt` falls inside a lock —
/// e.g. a capture that reached the store in the seconds before the overlay
/// rendered, or an offline write synced later — stays stored but derives
/// nothing, judged with the settings in force at that instant (AD-36,
/// deviation #2). The engine exclusion itself is DNI-466's (ruling B4(d));
/// these pin the lock-surface scenarios 1.19 names.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';

import '../../helpers/learner_state/engine_fixtures.dart';
import '../../helpers/learner_state/lock_fixtures.dart';
import '../../helpers/learner_state_fixtures.dart';

const _engine = LearnerStateEngine();
const _b11 = 'Mishnah Berakhot 1:1';
const _b12 = 'Mishnah Berakhot 1:2';

LearningEvent _learn(int id, String ref, DateTime recordedAt) =>
    LearningEvent.learn(
      id: engineUlid(id),
      curriculumId: engineCurriculum,
      ref: ref,
      source: LearningEvent.sourceMain,
      dateState: DateState.dated,
      learnedOn: '2026-09-04',
      stage: 1,
      recordedAt: recordedAt,
      actor: parentActor,
    );

void main() {
  final lakewoodH = constantHistory(lakewood);
  final shabbos = lockWindows(
    lakewoodH,
    DateTime.utc(2026, 9, 5, 12),
    DateTime.utc(2026, 9, 5, 12),
  ).single;

  test('a capture stamped seconds after the lock opened (before the overlay '
      'rendered) is stored but counted nowhere', () {
    final raced = _learn(
      2,
      _b12,
      shabbos.startUtc.add(const Duration(seconds: 5)),
    );
    final before = _learn(
      1,
      _b11,
      shabbos.startUtc.subtract(const Duration(seconds: 5)),
    );
    final state = _engine.run(
      engineInputs(events: [before, raced], settingsHistory: lakewoodH),
    );
    expect(state.lockIgnoredEventIds, {engineUlid(2)});
    expect(state.countedEventIds, {engineUlid(1)});
    expect(state[engineCurriculum]!.learntLeaves, {_b11});
  });

  test('judged by the settings in force at effectiveAt: a later move does '
      'not un-ignore it, and a learner elsewhere then is not locked', () {
    // Saturday 20:00Z: inside Lakewood's Shabbos, after Jerusalem's.
    final event = _learn(1, _b11, DateTime.utc(2026, 9, 5, 20));
    final moveAt = DateTime.utc(2026, 9, 9);

    final lakewoodThen = movedHistory(lakewood, moveAt, jerusalem);
    expect(
      _engine
          .run(engineInputs(events: [event], settingsHistory: lakewoodThen))
          .lockIgnoredEventIds,
      {engineUlid(1)},
    );

    final jerusalemThen = movedHistory(jerusalem, moveAt, lakewood);
    final state = _engine.run(
      engineInputs(events: [event], settingsHistory: jerusalemThen),
    );
    expect(state.lockIgnoredEventIds, isEmpty);
    expect(state.countedEventIds, {engineUlid(1)});
  });

  test('a learner with no location is judged by the fail-closed fallback: '
      'a Friday 13:00 capture is ignored', () {
    final state = _engine.run(
      engineInputs(
        events: [_learn(1, _b11, DateTime.utc(2026, 9, 4, 17))],
        settingsHistory: LearnerSettingsHistory.constant(newYorkNoLocation),
      ),
    );
    expect(state.lockIgnoredEventIds, {engineUlid(1)});
  });
}
