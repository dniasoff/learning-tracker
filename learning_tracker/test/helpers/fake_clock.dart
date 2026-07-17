/// Shared fake-clock install/reset helper for tests (AUD-core-time-01).
///
/// `core/time/local_day_clock.dart`'s `currentLocalDayClock` is a mutable
/// top-level variable backing `DateTimeFactory` (the non-Riverpod clock
/// read by 15+ production sites, e.g. `TrackDao`). Its doc comment says
/// callers "MUST" pair `useLocalDayClock()` with `resetLocalDayClock()` in
/// `tearDown` — but nothing in the type system enforces that. A test that
/// installs a fake clock and forgets the reset silently freezes time for
/// every later test in the same file/isolate, producing flaky failures
/// unrelated to the code under test (TQ-6 hermetic tests).
///
/// [installFakeClock] closes that gap: it installs the fake clock AND
/// registers the reset via `addTearDown` in the same call, so the pairing
/// can't be forgotten. Call it from a running test (`test`/`setUp` body) —
/// `addTearDown` requires an active test zone.
///
/// This file re-exports `core/time/local_day_clock.dart` in full, so a test
/// that needs `FakeLocalDayClock`/`LocalDayClock` (e.g. for direct
/// dependency injection, or the rare case of a manual `resetLocalDayClock()`
/// call) can import just this helper instead of both files.
///
/// ```dart
/// setUp(() {
///   clock = installFakeClock(DateTime.utc(2026, 5, 14));
/// });
/// ```
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';

export 'package:learning_tracker/core/time/local_day_clock.dart';

/// Installs a [FakeLocalDayClock] seeded at [seed] as the active
/// `currentLocalDayClock` and registers `addTearDown(resetLocalDayClock)`
/// so the reset can never be forgotten by the caller. Returns the installed
/// clock so tests can still call `.setNow()` / `.advance()` on it.
FakeLocalDayClock installFakeClock(DateTime seed) {
  final clock = FakeLocalDayClock(seed);
  useLocalDayClock(clock);
  addTearDown(resetLocalDayClock);
  return clock;
}
