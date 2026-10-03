/// The one performance budget file every benchmark imports (orchestrator
/// ruling B12). Budgets are provisional CI thresholds until the reference
/// device is named; the named-device run belongs to the release
/// verification sweep.
library;

import 'dart:io' show Platform;

/// The device the budgets are measured on.
const kReferenceDevice =
    'PROVISIONAL: CI ubuntu-latest x64 (release device TBD)';

/// The proposed release reference device (B12, user decision deferred).
const kProposedReleaseDevice = 'Samsung Galaxy A54 / Pixel 6a class Android';

/// AD-54 / NFR-5: warm engine recompute plus `dailyTarget`, per learner.
const kRecomputeBudget = Duration(milliseconds: 1000);

/// Projection delta against the measured baseline.
const kProjectionDeltaBudget = Duration(milliseconds: 150);

/// One UI frame.
const kFrameBudget = Duration(milliseconds: 100);

/// Why a wall-clock benchmark is skipped in this environment, or null when
/// it runs and gates on its budget.
///
/// Ruling B12: the budgets are gated in the CI `perf` job (`CI` is set on
/// every CI runner) or on demand with `LT_PERF=1`. Everywhere else — a
/// developer machine or a shared, loaded build host running plain
/// `flutter test` — the benchmark skips, so host load never fails an
/// unrelated run. The budget itself is never relaxed.
String? perfGateSkipReason([Map<String, String>? environment]) {
  final env = environment ?? Platform.environment;
  if (env['LT_PERF'] == '1' || (env['CI'] ?? '').isNotEmpty) return null;
  return 'wall-clock perf gate (ruling B12): runs only in CI or with '
      'LT_PERF=1';
}
