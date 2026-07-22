/// R5 reactivity-contract helper (Release Reassurance campaign).
///
/// ## Why this exists
///
/// R5 found 63 separate escapes where a derived Riverpod provider did NOT
/// re-execute when the data it derives from changed — a stale
/// `ref.watch(completionCommittedProvider)` (or an equivalent invalidation
/// signal) missing from a provider body, surfacing as a screen that only
/// updated after a manual pull-to-refresh. Each was fixed one-off, and each
/// fix grew its own bespoke regression test with a hand-rolled fixture (see
/// e.g. `curriculum_breakdown_staleness_test.dart`'s "count AsyncLoading
/// transitions before/after a tick" pattern, or
/// `curriculum_progress_reactivity_test.dart`'s "read the settled value
/// before/after a DB write + tick" pattern) — there was no shared, reusable
/// assertion. This file is that shared assertion.
///
/// ## The contract
///
/// A "derived" provider re-executes and reflects new state whenever the
/// data/signal it watches changes. [expectRebuildsOn] verifies this
/// mechanically: it subscribes to [derived], invokes [mutate] (which must
/// perform the underlying data change AND/OR tick whatever invalidation
/// signal the provider is expected to watch — the helper deliberately does
/// not assume which signal that is, since "watches the right signal" is
/// exactly what's under test), then asserts the provider re-executed.
///
/// "Re-executed" is satisfied by EITHER of two signals, matching the two
/// idioms already used across the bespoke R5 fixes:
///   - **build-count incremented** — [derived] notified at least one
///     listener between `mutate()`'s start and end (mirrors the
///     "AsyncLoading transition count increased" idiom). This fires even
///     when the recomputed value happens to equal the previous one.
///   - **value changed** — the settled value read after `mutate()` differs
///     from the value read before it (mirrors the "assert the DB-backed
///     value changed" idiom).
///
/// ## Sync vs. async providers
///
/// Works uniformly for both:
///   - **Synchronous** providers (`Provider<T>`, `NotifierProvider<T>`, a
///     plain family, …): the "current value" is read directly via the
///     subscription.
///   - **Asynchronous** providers (`FutureProvider<T>`, `StreamProvider<T>`,
///     `AsyncNotifierProvider<T>`, and their generated `@riverpod`
///     equivalents): detected via the `AsyncProviderListenable` interface
///     they all implement. The "current value" is the SETTLED value —
///     `container.read(derived.future)` — so a transient `AsyncLoading`
///     never gets misread as "the new value", and callers never need to
///     manually drain the async gap.
///
/// ## Usage
///
/// ```dart
/// final container = ProviderContainer(overrides: [...]);
/// addTearDown(container.dispose);
///
/// await expectRebuildsOn(
///   container,
///   curriculumProgressProvider(curriculumKey),
///   () async {
///     await db.completionEventDao.appendEvent(...);
///     container.read(completionCommittedProvider.notifier).increment();
///   },
///   reason: 'curriculumProgressProvider must watch completionCommittedProvider',
/// );
/// ```
///
/// [derived] is watched for the DURATION of this call (via an internal
/// `container.listen`) so an autoDispose provider cannot tear down between
/// the "before" read and `mutate()` and mask a missing `ref.watch` —
/// mirroring the "keep the provider alive across the DB mutation + tick"
/// discipline the bespoke fixtures already required callers to remember by
/// hand.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart'
    show AsyncProviderListenable, ProviderListenable;
import 'package:flutter_test/flutter_test.dart';

/// Asserts that [derived] re-executes (and reflects updated state) when
/// [mutate] runs. See the library doc comment for the full contract.
///
/// [reason] is appended to the failure message — use it to name the
/// invalidation signal [derived] is expected to watch, so a failing CI run
/// points straight at the missing `ref.watch(...)` line.
Future<void> expectRebuildsOn<T>(
  ProviderContainer container,
  ProviderListenable<T> derived,
  Future<void> Function() mutate, {
  String? reason,
}) async {
  var notifyCount = 0;
  final sub = container.listen<T>(derived, (_, _) => notifyCount++);
  try {
    final before = await _settledValueOf(container, derived, sub);
    // Reset the counter here, not at `listen(...)` time: an async provider's
    // very first Loading -> Data settle happens AFTER the listener is
    // attached (it is not part of `listen`'s synchronous "first build") and
    // would otherwise notify our listener once before `mutate()` ever runs,
    // producing a false-positive "it rebuilt" for a provider that never
    // watches anything.
    notifyCount = 0;
    await mutate();
    final after = await _settledValueOf(container, derived, sub);

    final rebuilt = notifyCount > 0 || after != before;
    expect(
      rebuilt,
      isTrue,
      reason:
          reason ??
          'Reactivity contract violated: expected the derived provider to '
              're-execute (build-count incremented or value changed) after '
              'mutate() ran, but it neither notified a listener nor changed '
              'value. The provider is likely missing a ref.watch(...) of the '
              'invalidation signal mutate() ticks.',
    );
  } finally {
    sub.close();
  }
}

/// Reads the CURRENT settled value of [derived] — awaiting through any
/// transient `AsyncLoading` for `FutureProvider`/`StreamProvider`-shaped
/// listenables (detected via [AsyncProviderListenable]), or the direct
/// value for a synchronous listenable.
Future<Object?> _settledValueOf<T>(
  ProviderContainer container,
  ProviderListenable<T> derived,
  ProviderSubscription<T> sub,
) {
  if (derived is AsyncProviderListenable) {
    return container.read((derived as AsyncProviderListenable).future);
  }
  return Future.value(sub.read());
}
