// DNI-490 (Story 1.28) AC-5: the cutover benchmark's gate reads only the
// warm recompute; the cold first load is recorded in the run record and
// never fails the gate (AD-54 "Read cost"). Pure, untimed checks of
// engine_benchmark_record.dart, so they run in the main lane.
library;

import 'package:flutter_test/flutter_test.dart';

import 'engine_benchmark_record.dart';
import 'perf_budget.dart';

EngineBenchmarkRecord _record(List<LearnerTiming> timings) =>
    EngineBenchmarkRecord(
      corpus: 'arukh_hashulchan',
      corpusLeaves: 25097,
      leafEvents: 40000,
      nodeEvents: 200,
      device: kReferenceDevice,
      budget: kRecomputeBudget,
      timings: timings,
    );

LearnerTiming _t(int learner, int warmMs, int coldMs) => LearnerTiming(
  learner: learner,
  warm: Duration(milliseconds: warmMs),
  cold: Duration(milliseconds: coldMs),
  dailyTarget: 7,
);

void main() {
  test('the budget is the AD-54 one second per learner', () {
    expect(kRecomputeBudget, const Duration(seconds: 1));
  });

  test('a slow cold first load is recorded but never fails the gate', () {
    final record = _record([_t(0, 400, 9000), _t(1, 350, 2500)]);
    expect(record.gateFailures(), isEmpty);
    final json = record.toJson();
    expect(json['passed'], isTrue);
    expect(json['cold_gated'], isFalse);
    expect(json['worst_cold_ms'], 9000);
    expect(
      (json['learner_timings']! as List).map((t) => (t as Map)['cold_ms']),
      [9000, 2500],
    );
  });

  test('a warm recompute at or over the budget fails the gate, '
      'naming the learner', () {
    final record = _record([_t(0, 400, 100), _t(1, 1000, 100), _t(2, 1200, 1)]);
    expect(record.gateFailures(), hasLength(2));
    expect(record.gateFailures().first, contains('learner 1'));
    expect(record.toJson()['passed'], isFalse);
    expect(record.worstWarm, const Duration(milliseconds: 1200));
  });

  test('the record names the workload and the device', () {
    final json = _record([_t(0, 1, 1)]).toJson();
    expect(json['learners'], 1);
    expect(json['leaf_events_per_learner'], 40000);
    expect(json['node_events_per_learner'], 200);
    expect(json['device'], kReferenceDevice);
    expect(json['budget_ms'], 1000);
  });
}
