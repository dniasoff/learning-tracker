/// `LocalDayClock` — the single source of truth for "what time is it"
/// and "what is today's local date" across the app.
///
/// Story 25.10 (DNI-331) consolidates every `DateTime.now()` callsite into
/// this one provider so day-boundary semantics (streak, scheduler,
/// dashboard) are deterministic in tests and consistent across timezones.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Read "today's local date" or "the current UTC instant" through this
/// interface only — never through `DateTime.now()` outside `core/time/`.
abstract interface class LocalDayClock {
  /// Current instant as a UTC `DateTime`. Use for audit/event timestamps.
  DateTime nowUtc();

  /// Midnight at the start of today's local day, as a local `DateTime`
  /// with `hour == 0` and zeroed sub-second fields. Use for day-boundary
  /// comparisons (e.g. streak day, scheduler "is today").
  DateTime today();
}

/// Production implementation — delegates to the system clock.
class SystemLocalDayClock implements LocalDayClock {
  const SystemLocalDayClock();

  @override
  // ignore: avoid_dynamic_calls
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  DateTime today() {
    final local = DateTime.now();
    return DateTime(local.year, local.month, local.day);
  }
}

/// Test double — returns a seeded instant; mutable via [advance] / [setNow].
class FakeLocalDayClock implements LocalDayClock {
  FakeLocalDayClock(DateTime seed) : _now = seed.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  @override
  DateTime today() {
    final local = _now.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  /// Replace the current instant. Accepts any `DateTime` (converted to UTC).
  void setNow(DateTime instant) {
    _now = instant.toUtc();
  }

  /// Advance the clock by [delta]. Use to simulate elapsed time in tests.
  void advance(Duration delta) {
    _now = _now.add(delta);
  }
}

/// The single Riverpod provider every consumer reads from. Override in
/// tests with `localDayClockProvider.overrideWithValue(FakeLocalDayClock(…))`.
final localDayClockProvider = Provider<LocalDayClock>(
  (ref) => const SystemLocalDayClock(),
);

/// Internal accessor used by `DateTimeFactory` (non-Riverpod consumers) to
/// read the same clock the rest of the app uses. Lives here (not in
/// `date_utils.dart`) so the clock is owned by `core/time/`.
LocalDayClock currentLocalDayClock = const SystemLocalDayClock();

/// Install a custom clock for the duration of a test. Affects every
/// non-Riverpod consumer via `DateTimeFactory.nowUtc()`. Callers MUST
/// reset to the default in `tearDown`.
void useLocalDayClock(LocalDayClock clock) {
  currentLocalDayClock = clock;
}

/// Reset the global clock to the production system clock.
void resetLocalDayClock() {
  currentLocalDayClock = const SystemLocalDayClock();
}
