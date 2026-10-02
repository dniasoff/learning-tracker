// Mirror test for
// `lib/features/progress/domain/services/chart_data_service.dart`
// (DNI-474: chart series bucket the engine's counted learn events).
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/domain/learner_state/points.dart';
import 'package:learning_tracker/features/progress/domain/services/chart_data_service.dart';

import '../../../../helpers/learner_state/engine_fixtures.dart';
import '../../../../helpers/learner_state/progress_fixtures.dart';

void main() {
  const service = ChartDataService();
  final corpus = progressCorpus();
  final start = DateTime(2026, 9, 1);
  final end = DateTime(2026, 9, 3);

  final state = progressState([
    progressGround(1, 'Mishnah Peah', 'masechta'),
    progressLearn(2, 'Mishnah Peah 1:1', minutes: 1, learnedOn: '2026-09-01'),
    progressLearn(
      3,
      'Mishnah Berakhot 1:1',
      minutes: 2,
      learnedOn: '2026-09-01',
    ),
    progressLearn(
      4,
      'Mishnah Berakhot 1:1',
      minutes: 3,
      learnedOn: '2026-09-02',
    ),
    progressLearn(
      5,
      'Mishnah Berakhot 1:2',
      minutes: 4,
      learnedOn: '2026-09-03',
    ),
    progressLearn(
      6,
      'Mishnah Shabbat 1:1',
      minutes: 5,
      learnedOn: '2026-09-03',
    ),
    engineVoid(7, 6, minutes: 6),
  ]);

  test('daily completions count counted events per learned_on day', () {
    final days = service.getDailyCompletions(
      state,
      startDate: start,
      endDate: end,
      corpusFor: (_) => corpus,
    );
    expect(days.map((d) => d.date), [start, DateTime(2026, 9, 2), end]);
    expect(days.map((d) => d.count), [2, 1, 1]);
  });

  test('a learn on an already-learnt leaf (including a before-tracking '
      'mark) is a chazara; a first learn is a limud', () {
    final days = service.getDailyLimudimAndChazaros(
      state,
      startDate: start,
      endDate: end,
      corpusFor: (_) => corpus,
    );
    expect(days.map((d) => d.limudCount), [1, 0, 1]);
    expect(days.map((d) => d.chazaraCount), [1, 1, 0]);
  });

  test('cumulative progress counts distinct newly learnt leaves', () {
    final points = service.getCumulativeProgress(
      state,
      startDate: DateTime(2026, 9, 2),
      endDate: end,
      corpusFor: (_) => corpus,
    );
    expect(points.map((p) => p.total), [1, 2]);
  });

  test('the streak calendar holds days with counted learning', () {
    expect(service.getStreakCalendar(state, startDate: start, endDate: end), {
      start,
      DateTime(2026, 9, 2),
      end,
    });
  });

  test('a long range is weekly from its first active day', () {
    final weeks = service.getDailyCompletions(
      state,
      startDate: DateTime(2026, 6, 1),
      endDate: DateTime(2026, 9, 30),
      corpusFor: (_) => corpus,
    );
    expect(weeks.first.date, start);
    expect(weeks.first.count, 4);
    expect(weeks[1].date, DateTime(2026, 9, 8));
  });

  test('daily points sum earning awards on their event day; adults get '
      'none', () {
    final awards = [
      for (final id in state.earningEventIds)
        PointsLedgerRow(id: 'pts_$id', amount: 5, eventId: id),
      const PointsLedgerRow(id: 'pts_x', amount: 99, eventId: 'not-earning'),
    ];
    final points = service.getDailyPoints(
      state,
      awards: awards,
      startDate: start,
      endDate: end,
      userMode: ProfileMode.child,
    )!;
    final total = points.fold<int>(0, (sum, p) => sum + p.points);
    expect(total, 5 * state.earningEventIds.length);
    expect(
      service.getDailyPoints(
        state,
        awards: awards,
        startDate: start,
        endDate: end,
        userMode: ProfileMode.adult,
      ),
      isNull,
    );
  });

  test('no state charts as empty days', () {
    expect(
      service
          .getDailyCompletions(null, startDate: start, endDate: end)
          .map((d) => d.count),
      [0, 0, 0],
    );
  });
}
