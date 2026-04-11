// Epic 20 Story 20.1 — argon2id parameter benchmark spike.
//
// Measures hash time for a matrix of argon2id parameter sets so we
// can pick a production config that hits the OWASP minimum
// throughput without making sign-in feel broken on low-end devices.
//
// Usage:
//   cd learning_tracker
//   dart run tool/argon2id_benchmark.dart [--target-ms 500] [--iterations 5]
//
// On the Android API 21 target device (the low-end floor for this
// app), run this via `flutter test integration_test/argon2_bench_test.dart`
// — the integration harness reports the same numbers but from the
// actual device's CPU. This host-run version is for tuning on a dev
// laptop before the device run.
//
// Output is a table of (memory, iterations, parallelism) → median
// hash time, marked with ✓/✗ against the target budget.

import 'dart:io';

import 'package:cryptography/cryptography.dart';

// ─── Parameter matrix under test ─────────────────────────────────
// Rows follow the OWASP 2024 guidance for argon2id on mobile:
//   min floor:  m=19 MiB, t=2, p=1  — minimum acceptable
//   balanced:   m=32 MiB, t=2, p=1  — recommended desktop baseline
//   strong:     m=46 MiB, t=1, p=1  — bigger memory, fewer passes
//   high-mem:   m=64 MiB, t=3, p=1  — only for fast hardware
// Add rows here to explore further.
const _paramMatrix = <_Params>[
  _Params(memoryKib: 19 * 1024, iterations: 2, parallelism: 1),
  _Params(memoryKib: 32 * 1024, iterations: 2, parallelism: 1),
  _Params(memoryKib: 46 * 1024, iterations: 1, parallelism: 1),
  _Params(memoryKib: 64 * 1024, iterations: 3, parallelism: 1),
];

const _defaultTargetMs = 500; // v2 §4.2 UX ceiling for signup
const _defaultRuns = 5;
const _testPassword = 'benchmark-password-42-correct-horse';
const _testSalt = <int>[
  0x9f, 0x1e, 0xa4, 0x2b, 0x6c, 0x7d, 0x88, 0x91,
  0x04, 0x5a, 0xbe, 0xf3, 0x11, 0x22, 0x33, 0x44,
];

class _Params {
  const _Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });
  final int memoryKib;
  final int iterations;
  final int parallelism;

  String get label =>
      'm=${(memoryKib / 1024).toStringAsFixed(0)}MiB t=$iterations p=$parallelism';
}

Future<int> _timeOnce(_Params p) async {
  final algorithm = Argon2id(
    memory: p.memoryKib,
    parallelism: p.parallelism,
    iterations: p.iterations,
    hashLength: 32,
  );
  final sw = Stopwatch()..start();
  await algorithm.deriveKeyFromPassword(
    password: _testPassword,
    nonce: _testSalt,
  );
  sw.stop();
  return sw.elapsedMilliseconds;
}

int _median(List<int> xs) {
  final sorted = [...xs]..sort();
  return sorted[sorted.length ~/ 2];
}

Future<void> main(List<String> args) async {
  var targetMs = _defaultTargetMs;
  var runs = _defaultRuns;

  for (var i = 0; i < args.length - 1; i++) {
    if (args[i] == '--target-ms') {
      targetMs = int.parse(args[i + 1]);
    } else if (args[i] == '--iterations') {
      runs = int.parse(args[i + 1]);
    }
  }

  stdout.writeln('Epic 20 Story 20.1 — argon2id parameter benchmark');
  stdout.writeln('Target: $targetMs ms per hash (v2 §4.2 UX ceiling)');
  stdout.writeln('Runs per cell: $runs (reporting median)');
  stdout.writeln('Platform: ${Platform.operatingSystem} '
      '${Platform.operatingSystemVersion}');
  stdout.writeln('');
  stdout.writeln(
    '| Params                          | Median  | Min    | Max    | Budget |'
        '\n'
        '| ------------------------------- | ------- | ------ | ------ | ------ |',
  );

  for (final p in _paramMatrix) {
    // Warm-up pass — first run is always slower due to JIT / memory allocation.
    await _timeOnce(p);

    final samples = <int>[];
    for (var i = 0; i < runs; i++) {
      samples.add(await _timeOnce(p));
    }

    final median = _median(samples);
    final minV = samples.reduce((a, b) => a < b ? a : b);
    final maxV = samples.reduce((a, b) => a > b ? a : b);
    final withinBudget = median <= targetMs ? '✓' : '✗';

    stdout.writeln(
      '| ${p.label.padRight(31)} '
      '| ${'${median}ms'.padLeft(7)} '
      '| ${'${minV}ms'.padLeft(6)} '
      '| ${'${maxV}ms'.padLeft(6)} '
      '| $withinBudget      |',
    );
  }

  stdout.writeln('');
  stdout.writeln('Notes:');
  stdout.writeln('  - Dev-laptop numbers are 5-15x faster than API 21 device.');
  stdout.writeln('  - Multiply medians by ~10 to estimate worst-case on-device.');
  stdout.writeln('  - Use the highest row that still fits the budget on-device.');
  stdout.writeln('  - Update Argon2idParams.production in');
  stdout.writeln('    lib/features/auth/domain/services/password_hasher.dart');
  stdout.writeln('    once the device run confirms a winning row.');
}
