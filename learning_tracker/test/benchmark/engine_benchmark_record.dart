/// The run record of the AD-54 cutover benchmark (DNI-490 AC-5,
/// `learner_state_engine_benchmark_test.dart`).
///
/// AD-54 "Read cost": the perf gate measures recompute from a warm
/// in-memory log; a cold first load is measured and recorded, not gated.
/// [EngineBenchmarkRecord.gateFailures] therefore reads only the warm
/// times, and [EngineBenchmarkRecord.toJson] carries the cold times as
/// data, for the release record.
library;

/// One learner's timings.
final class LearnerTiming {
  /// Creates a timing.
  const LearnerTiming({
    required this.learner,
    required this.warm,
    required this.cold,
    required this.dailyTarget,
  });

  /// The learner's index.
  final int learner;

  /// Best warm engine recompute plus `dailyTarget` (gated).
  final Duration warm;

  /// Cold first load: decoding the stored log plus the first engine run
  /// (recorded, never gated).
  final Duration cold;

  /// The `dailyTarget` the run produced.
  final int? dailyTarget;
}

/// The benchmark's run record.
final class EngineBenchmarkRecord {
  /// Creates a record.
  EngineBenchmarkRecord({
    required this.corpus,
    required this.corpusLeaves,
    required this.leafEvents,
    required this.nodeEvents,
    required this.device,
    required this.budget,
    required List<LearnerTiming> timings,
  }) : timings = List.unmodifiable(timings);

  /// The curriculum benchmarked (the largest bundled corpus).
  final String corpus;

  /// Its ContentIndex leaf count.
  final int corpusLeaves;

  /// Leaf events per learner.
  final int leafEvents;

  /// Node events per learner.
  final int nodeEvents;

  /// The device the budget applies to.
  final String device;

  /// The warm per-learner budget (AD-54: under one second).
  final Duration budget;

  /// Every learner's timings.
  final List<LearnerTiming> timings;

  /// The slowest warm recompute.
  Duration get worstWarm => _max(timings.map((t) => t.warm));

  /// The slowest cold first load.
  Duration get worstCold => _max(timings.map((t) => t.cold));

  /// The gate's failures, empty when it passes: a learner whose warm time
  /// is not under [budget]. Cold times never fail the gate (AD-54).
  List<String> gateFailures() => [
    for (final t in timings)
      if (t.warm >= budget) _overBudget(t),
  ];

  String _overBudget(LearnerTiming t) =>
      'learner ${t.learner}: warm ${t.warm.inMilliseconds} ms is not under '
      '${budget.inMilliseconds} ms';

  /// The record as JSON, for the CI artifact and the release record.
  Map<String, Object?> toJson() => {
    'story': 'DNI-490',
    'gate': 'AD-54 warm engine recompute + dailyTarget per learner',
    'device': device,
    'corpus': corpus,
    'corpus_leaves': corpusLeaves,
    'learners': timings.length,
    'leaf_events_per_learner': leafEvents,
    'node_events_per_learner': nodeEvents,
    'budget_ms': budget.inMilliseconds,
    'worst_warm_ms': worstWarm.inMicroseconds / 1000,
    'worst_cold_ms': worstCold.inMicroseconds / 1000,
    'cold_gated': false,
    'passed': gateFailures().isEmpty,
    'failures': gateFailures(),
    'learner_timings': [
      for (final t in timings)
        {
          'learner': t.learner,
          'warm_ms': t.warm.inMicroseconds / 1000,
          'cold_ms': t.cold.inMicroseconds / 1000,
          'daily_target': t.dailyTarget,
        },
    ],
  };
}

Duration _max(Iterable<Duration> all) =>
    all.fold(Duration.zero, (a, b) => a > b ? a : b);
