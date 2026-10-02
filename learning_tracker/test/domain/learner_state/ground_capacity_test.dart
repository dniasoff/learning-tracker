// Story 2.7 (DNI-498) AC-5, the FR-19 fixture through the picker's own
// append (UJ-3 step 4): School (school-year, 10/wk, 39 weeks, groundless),
// every Berachos leaf unlearnt, a deadline; adding Berachos perakim 1–3
// through `groundToAppend` leaves the shared AD-44 daily target unchanged.
// Nothing special-cases the target: the engine's formula keeps it.
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/domain/learner_state/append_ground.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/goals.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/main_track_intent.dart';
import 'package:learning_tracker/domain/learner_state/node_entry.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';

import '../../helpers/learner_state/bundled_corpus.dart';
import '../../helpers/learner_state/engine_fixtures.dart';

const _today = '2026-10-01';
const _deadline = '2029-03-14';
final _schoolId = engineUlid(603);

NodeEntry _perek(int n) =>
    NodeEntry(level: 'chapter', ref: 'Mishnah Berakhot $n');

SubTrack _school(List<NodeEntry> ground) => SubTrack(
  id: _schoolId,
  curriculumId: engineCurriculum,
  name: 'School',
  type: SubTrackType.schoolYear,
  academicYear: 2026,
  windowStart: '2026-09-01',
  windowEnd: '2027-07-31',
  ratePerWeek: 10,
  weeksPerYear: 39,
  learnsOnShabbos: false,
  ground: ground,
  lastChangeId: engineUlid(700),
);

CurriculumState _run(SubTrack school, {CivilDate? deadline = _deadline}) =>
    const LearnerStateEngine().run(
      engineInputs(
        nowUtc: DateTime.parse('${_today}T12:00:00Z'),
        subTracks: [school],
        corpora: {engineCurriculum: bundledCorpus(engineCurriculum)},
        intents: {
          engineCurriculum: MainTrackIntent(
            curriculumId: engineCurriculum,
            track: MainTrack(
              curriculumId: engineCurriculum,
              state: MainTrackState.active,
            ),
          ),
        },
        goals: {
          engineCurriculum: CurriculumGoals(
            deadline: deadline == null
                ? null
                : DeadlineGoal(
                    curriculumId: engineCurriculum,
                    targetDate: deadline,
                  ),
          ),
        },
      ),
    )[engineCurriculum]!;

void main() {
  final corpus = bundledCorpus(engineCurriculum);

  test('AC-5: Berachos perakim 1–3 through the picker leave the target '
      'unchanged', () {
    final before = _run(_school(const []));
    final appended = groundToAppend(
      current: const [],
      selected: [_perek(3), _perek(1), _perek(2)],
      corpus: corpus,
    );
    expect(appended, [_perek(1), _perek(2), _perek(3)]);
    final after = _run(_school(appended));
    // The 19 leaves left the main track …
    expect(before.mainTrackRemaining - after.mainTrackRemaining, 19);
    expect(after.schedulableRefs, isNot(contains('Mishnah Berakhot 1:1')));
    // … and the target did not move.
    expect(before.dailyTarget, isNotNull);
    expect(after.dailyTarget, before.dailyTarget);
  });

  test('a second append of covered ground changes nothing', () {
    final ground = [_perek(1), _perek(2), _perek(3)];
    expect(
      groundToAppend(
        current: ground,
        selected: [
          _perek(2),
          const NodeEntry(level: 'mishnah', ref: 'Mishnah Berakhot 1:1'),
        ],
        corpus: corpus,
      ),
      isEmpty,
    );
  });

  test('with no deadline there is no target to move', () {
    final before = _run(_school(const []), deadline: null);
    final after = _run(_school([_perek(1)]), deadline: null);
    expect(before.dailyTarget, isNull);
    expect(after.dailyTarget, isNull);
  });
}
