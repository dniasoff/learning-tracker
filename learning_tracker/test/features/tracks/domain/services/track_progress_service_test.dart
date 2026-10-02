// Mirror test for
// `lib/features/tracks/domain/services/track_progress_service.dart`
// (DNI-474: progress percentages and series over LearnerState).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/tracks/domain/services/track_progress_service.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  const service = TrackProgressService();

  group('completionPercent', () {
    test('is the distinct learnt count over the scoped total: repeats '
        'count once, before-tracking counts', () {
      final state = progressState([
        progressLearn(1, 'Mishnah Berakhot 1:1'),
        progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 5),
        progressGround(3, 'Mishnah Peah', 'masechta'),
      ]);
      expect(
        service.completionPercent(
          state: state,
          curriculumId: CurriculumId.mishnayos,
          totalItems: 10,
        ),
        closeTo(0.3, 1e-9),
      );
    });

    test('with since, counts leaves first learnt by tracked learning at or '
        'after the instant', () {
      final state = progressState([
        progressGround(1, 'Mishnah Peah', 'masechta'),
        progressLearn(2, 'Mishnah Berakhot 1:1', minutes: 5),
        progressLearn(3, 'Mishnah Berakhot 1:2', minutes: 20),
      ]);
      expect(
        service.completionPercent(
          state: state,
          curriculumId: CurriculumId.mishnayos,
          totalItems: 10,
          since: engineAt(10),
        ),
        closeTo(0.1, 1e-9),
      );
    });

    test('is 0 without a state, a curriculum or items', () {
      expect(
        service.completionPercent(
          state: null,
          curriculumId: CurriculumId.mishnayos,
          totalItems: 10,
        ),
        0,
      );
      expect(
        service.completionPercent(
          state: progressState(const []),
          curriculumId: CurriculumId.bavli,
          totalItems: 10,
        ),
        0,
      );
      expect(
        service.completionPercent(
          state: progressState([progressLearn(1, 'Mishnah Peah 1:1')]),
          curriculumId: CurriculumId.mishnayos,
          totalItems: 0,
        ),
        0,
      );
    });
  });

  test('dailyCounts buckets counted events by learned_on day; voided '
      'events drop out', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', learnedOn: '2026-09-02'),
      progressLearn(2, 'Mishnah Peah 1:2', learnedOn: '2026-09-02'),
      progressLearn(3, 'Mishnah Shabbat 1:1', learnedOn: '2026-09-03'),
      engineVoid(4, 3),
    ]);
    final days = service.dailyCounts(
      state: state,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
    );
    expect(days.map((d) => d.count), [0, 2, 0]);
  });

  test('cumulativeProgress accumulates distinct newly learnt leaves', () {
    final state = progressState([
      progressLearn(1, 'Mishnah Peah 1:1', learnedOn: '2026-09-01'),
      progressLearn(2, 'Mishnah Peah 1:1', learnedOn: '2026-09-02'),
      progressLearn(3, 'Mishnah Peah 1:2', learnedOn: '2026-09-03'),
      engineLearn(4, 'Mishnah Shabbat 1:1', dateState: DateState.catchUp),
    ]);
    final points = service.cumulativeProgress(
      state: state,
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 3),
      curriculumId: CurriculumId.mishnayos,
    );
    expect(points.map((p) => p.total), [2, 2, 3]);
  });
}
