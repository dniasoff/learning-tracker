/// Regression test for `installFakeClock` (AUD-core-time-01).
///
/// The finding: `core/time/local_day_clock.dart`'s mutable
/// `currentLocalDayClock` backs `DateTimeFactory`, and its doc comment says
/// callers "MUST" pair `useLocalDayClock()` with `resetLocalDayClock()` in
/// `tearDown` — but nothing in the type system enforced that. A test that
/// installed a fake clock and forgot the reset would silently freeze time
/// for every later test in the same file/isolate.
///
/// `installFakeClock` (test/helpers/fake_clock.dart) closes the gap by
/// registering the reset itself. This test proves the reset actually fires
/// — without depending on declaration order across separate tests (a real
/// cross-test leak would only be observable in a SECOND test, which is
/// itself an anti-pattern per TQ-2). Instead it exploits `addTearDown`'s
/// documented LIFO ordering ("the most recently registered callback is run
/// first" — test_api's `test_structure.dart`): registering the assertion
/// callback *before* calling `installFakeClock` means `installFakeClock`'s
/// own `addTearDown(resetLocalDayClock)` (registered later) fires FIRST, so
/// by the time the assertion callback runs, the reset has already happened
/// — all within a single hermetic test.
///
/// Lives under test/core/time/ (mirroring lib/core/time/) rather than
/// test/helpers/ itself, so it doesn't trip AUD-t-cross-12's
/// duplicate-top-level-function checker, which scans every `*.dart` file
/// directly under test/helpers/ and would otherwise flag this file's
/// `main()` against test/helpers/golden_font_loader_test.dart's `main()` —
/// a false positive on the shared test entrypoint name, not a real helper
/// collision.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';

import '../../helpers/fake_clock.dart';

void main() {
  group('installFakeClock', () {
    test('installs the seeded instant for DateTimeFactory', () {
      final seed = DateTime.utc(2026, 1, 1, 8, 30);
      installFakeClock(seed);
      expect(DateTimeFactory.nowUtc(), seed);
    });

    test('automatically resets the global clock after the test — the pairing '
        'can never be forgotten', () {
      final seed = DateTime.utc(2099, 1, 1);

      // Registered BEFORE installFakeClock() below. addTearDown callbacks
      // run LIFO (most-recently-registered first), so installFakeClock's
      // own addTearDown(resetLocalDayClock) — registered after this one —
      // fires first, and this callback then observes the POST-reset
      // state. Without installFakeClock's built-in reset (i.e. reverting
      // to the old bare `useLocalDayClock(...)` call this finding flags),
      // this assertion would fail: DateTimeFactory.nowUtc() would still
      // equal `seed`, exactly reproducing the leaked-fake-clock failure
      // mode AUD-core-time-01 describes.
      addTearDown(() {
        expect(
          DateTimeFactory.nowUtc(),
          isNot(seed),
          reason:
              'installFakeClock must reset the global clock via its own '
              'addTearDown before this outer tearDown runs — a leaked '
              'fake clock would freeze time for every later test '
              '(AUD-core-time-01)',
        );
      });

      installFakeClock(seed);
      expect(
        DateTimeFactory.nowUtc(),
        seed,
        reason: 'sanity check: the fake clock must be live before reset',
      );
    });

    test(
      'returns the installed FakeLocalDayClock so callers can mutate it',
      () {
        final seed = DateTime.utc(2026, 3, 1);
        final clock = installFakeClock(seed);

        clock.advance(const Duration(days: 1));
        expect(DateTimeFactory.nowUtc(), seed.add(const Duration(days: 1)));
      },
    );
  });
}
