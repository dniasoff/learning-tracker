/// Run-10 P0 regression — Parent Mode must NOT be re-enterable without a PIN
/// after a profile-switch round trip.
///
/// THE DEFECT (found on emulator-5560, API 34, reproduced twice):
/// A child who watched a parent unlock Parent Mode once could return to full
/// admin controls later in the same session with **no PIN prompt** — while the
/// UI still showed a lock icon, a "PIN-guarded" subtitle and a CHILD MODE badge.
///
/// Repro that mattered:
///   child → Parent Mode (PIN correct, elevates)
///        → switch to ADULT profile (correctly re-prompts)
///        → switch BACK to the same child (never gated — selecting a child is
///          deliberately un-gated, and the badge resets to CHILD MODE)
///        → tap Parent Mode → **straight in, no PIN**.
///
/// ROOT CAUSE — two pieces of state that must move together, and didn't:
///   * [PinGuard._authenticatedScope] — the ACTUAL gate. Only `lock()` clears it.
///   * `parentPinAuthenticatedProfileIdProvider` — the reactive flag the badge
///     watches.
/// `ProfileSwitcherSheet._switchProfile()` cleared only the flag, reasoning that
/// the guard "re-prompts on the new profile automatically since the scope id
/// changes". That is true when switching TO A DIFFERENT profile — and false on a
/// ROUND TRIP back to the previously-elevated child, where the scope id is
/// *identical*, so `_authenticatedScope == scope` and the guard returns
/// `next(true)` (branch B2).
///
/// THE FIX: `_switchProfile` calls `pinGuard.lock()`, which clears the cached
/// scope AND (via `onSessionLocked`) the reactive flag.
///
/// ⚠️ SCOPE OF THIS FILE — READ BEFORE TRUSTING IT AS THE P0 GUARD.
///
/// This file pins the **PinGuard contract**: that `lock()` genuinely clears the
/// cached scope so a returning profile is re-challenged, that the cache still
/// short-circuits without a lock, and that `lock()` fires `onSessionLocked`.
///
/// It does **NOT** guard the actual defect. The bug was in the CALLER —
/// `ProfileSwitcherSheet._switchProfile()` failing to call `lock()` at all. This
/// was verified honestly: reverting the production fix and re-running this file
/// still yields **3/3 passing**. A test that cannot go red for the bug it is
/// named after is exactly the tautology class this campaign exists to remove
/// (see docs/test-artifacts/reassurance-report.md, R7), so it is labelled rather
/// than quietly relied upon.
///
/// **STILL REQUIRED:** a caller-level regression test that pumps
/// `ProfileSwitcherSheet`, taps a profile row, and asserts the guard ends up
/// locked — i.e. one that fails if `_switchProfile` reverts to clearing only the
/// reactive flag. Tracked as a run-10 follow-up.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockPinService extends Mock implements PinService {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

const _childProfileId = 'child-profile-7';
const _adultProfileId = 'adult-profile-9';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  late _MockPinService pinService;
  late _MockStackRouter router;
  var promptCount = 0;

  /// The scope the guard will resolve on the next navigation. Mutated between
  /// steps to model the user moving between profiles.
  late PinScope? currentScope;

  /// Builds a guard whose PIN prompt always succeeds, counting invocations so a
  /// test can assert the user was actually challenged.
  PinGuard buildGuard() => PinGuard(
    pinService: pinService,
    pinSetupRoute: () => _FakePageRouteInfo(),
    getScope: () => currentScope,
    promptForPin: () async {
      promptCount++;
      return true;
    },
  );

  setUp(() {
    pinService = _MockPinService();
    router = _MockStackRouter();
    promptCount = 0;
    // A PIN IS configured — so every guarded navigation must challenge unless a
    // valid cached session exists.
    when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => true);
  });

  Future<bool> navigate(PinGuard guard, PinScope scope) async {
    currentScope = scope;
    final resolver = _MockNavigationResolver();
    var allowed = false;
    when(() => resolver.next(any())).thenAnswer((invocation) {
      allowed = invocation.positionalArguments.first as bool;
    });
    await guard.onNavigation(resolver, router);
    return allowed;
  }

  test('P0: after elevating on a child, switching profiles and returning must '
      're-prompt for the PIN (lock() clears the cached scope)', () async {
    final guard = buildGuard();
    const childScope = PinScope.parent(_childProfileId);

    // 1. Parent elevates on the child profile — challenged once.
    expect(await navigate(guard, childScope), isTrue);
    expect(promptCount, 1, reason: 'first entry must challenge');

    // 2. Switching to the ADULT profile is a different scope, so it
    //    challenges independently. (This path always worked.)
    expect(
      await navigate(guard, const PinScope.parent(_adultProfileId)),
      isTrue,
    );
    expect(promptCount, 2);

    // 3. Switching BACK to the child. This is the step whose handling was
    //    wrong: the switcher must LOCK the guard, not merely clear the
    //    banner's reactive flag.
    guard.lock();

    // 4. Re-entering Parent Mode on the SAME child must challenge again.
    //    Pre-fix, the cached scope still matched and the guard returned
    //    next(true) here with promptCount stuck at 2 — the bypass.
    expect(await navigate(guard, childScope), isTrue);
    expect(
      promptCount,
      3,
      reason:
          'returning to a previously-elevated child MUST re-prompt; a stale '
          'cached scope would wave the child straight into admin controls '
          'while the UI still shows a lock icon and CHILD MODE badge',
    );
  });

  test(
    'the cached-session shortcut still works WITHOUT an intervening lock, so '
    'this guard does not simply prompt on every navigation',
    () async {
      // Guards against "fixing" the P0 by disabling the cache outright, which
      // would re-prompt constantly and push users toward disabling the PIN.
      final guard = buildGuard();
      const childScope = PinScope.parent(_childProfileId);

      expect(await navigate(guard, childScope), isTrue);
      expect(promptCount, 1);

      expect(await navigate(guard, childScope), isTrue);
      expect(
        promptCount,
        1,
        reason:
            'within one unlocked session the cached scope should still short-'
            'circuit — the fix is to LOCK on profile switch, not to remove the '
            'cache',
      );
    },
  );

  test('lock() fires onSessionLocked, which is what clears the banner flag in '
      'production (router_provider wires it to '
      'parentPinAuthenticatedProfileIdProvider.clear())', () async {
    var lockedCallbacks = 0;
    final guard = PinGuard(
      pinService: pinService,
      pinSetupRoute: () => _FakePageRouteInfo(),
      getScope: () => const PinScope.parent(_childProfileId),
      promptForPin: () async => true,
      onSessionLocked: () => lockedCallbacks++,
    );

    await navigate(guard, const PinScope.parent(_childProfileId));
    guard.lock();

    expect(
      lockedCallbacks,
      1,
      reason:
          'lock() must notify listeners so the reactive flag clears too — this '
          'is why calling lock() strictly supersedes the old clear()-only call '
          'rather than duplicating it',
    );
  });
}
