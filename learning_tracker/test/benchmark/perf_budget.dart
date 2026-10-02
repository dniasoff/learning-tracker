/// The one performance budget file every benchmark imports (orchestrator
/// ruling B12). Budgets are provisional CI thresholds until the reference
/// device is named; the named-device run belongs to the release
/// verification sweep.
library;

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
