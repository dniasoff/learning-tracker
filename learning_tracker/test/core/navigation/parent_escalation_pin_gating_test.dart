/// R3 privacy invariants (reassurance-plan.md, TEA-009) — the child-safety
/// -critical claim that "a child profile cannot reach parent-only surfaces
/// without the PIN" and "every escalation path is PIN-gated".
///
/// Two complementary, fully behavioral proofs (no `lib/` source-text
/// assertions — every check below executes the REAL production classes):
///
/// Group 1 — ROUTER WIRING: constructs the real [AppRouter] (the actual
/// production route table) and asserts, for every route enumerated from its
/// live `routes` config, that the parent-management escalation routes carry
/// [PinGuard] and the deliberately child-facing exceptions do not — closing
/// the "a new parent-only screen ships without pinGuard by accident" class.
/// The third test in that group makes the enumeration EXHAUSTIVE: any
/// `childModeGuard`-gated route not in one of the two known lists fails the
/// test, so a newly-added route must be explicitly classified here.
///
/// Group 2 — COMBINED GUARD CHAIN: chains the REAL [ChildModeGuard] +
/// [PinGuard] (the same two guards `app_router.dart` wires together on every
/// `/parent-mode/*` route) and proves the actual runtime decision: an adult
/// active profile is blocked before the PIN is ever considered; a child
/// active profile is blocked until the correct Parent PIN is supplied; and a
/// wrong/cancelled PIN still blocks.
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart';
import 'package:learning_tracker/app/router/guards/auth_guard.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/child_mode_guard.dart';
import 'package:learning_tracker/core/navigation/guards/pin_guard.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/navigation/pin_scope.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/drift_memory.dart' show inMemoryDb;
import '../../helpers/test_database.dart' show seedAccount;

// ─── Group 1 fixtures ───────────────────────────────────────────────────────

class _MockPinService extends Mock implements PinService {}

class _NeverError extends Error {
  _NeverError(this.message);
  final String message;
  @override
  String toString() => 'not exercised in this config-only test: $message';
}

Never _never(String label) => throw _NeverError(label);

/// Builds the REAL [AppRouter] with its 5 real guard TYPES (so `guards`
/// membership checks below compare against genuine [PinGuard]/
/// [ChildModeGuard] instances) but throwing closures for every dependency —
/// this group only reads the router's static `routes` config; none of these
/// guards' `onNavigation` bodies are ever invoked.
AppRouter _buildRouterForInspection() {
  return AppRouter(
    authGuard: AuthGuard(),
    restoreGuard: RestoreGuard(
      getDatabase: () => _never('RestoreGuard.getDatabase'),
      hasCloudAccount: () => _never('RestoreGuard.hasCloudAccount'),
      deviceRestoreRoute: () => _never('RestoreGuard.deviceRestoreRoute'),
    ),
    profileGuard: ProfileGuard(
      getDatabase: () => _never('ProfileGuard.getDatabase'),
      getSelectedProfileId: () => _never('ProfileGuard.getSelectedProfileId'),
      setSelectedProfileId: (_) => _never('ProfileGuard.setSelectedProfileId'),
      getAccountId: () => _never('ProfileGuard.getAccountId'),
      isTutoredSession: () => _never('ProfileGuard.isTutoredSession'),
      profilePickerRoute: () => _never('ProfileGuard.profilePickerRoute'),
    ),
    childModeGuard: ChildModeGuard(
      getDatabase: () => _never('ChildModeGuard.getDatabase'),
      getSelectedProfileId: () => _never('ChildModeGuard.getSelectedProfileId'),
    ),
    pinGuard: PinGuard(
      pinService: _MockPinService(),
      pinSetupRoute: () => _never('PinGuard.pinSetupRoute'),
      promptForPin: () => _never('PinGuard.promptForPin'),
      getScope: () => _never('PinGuard.getScope'),
    ),
  );
}

/// Recursively flattens [routes] (including nested `children`, e.g. the app
/// shell's dashboard/learn/progress/settings tabs) into one flat list.
List<AutoRoute> _flatten(List<AutoRoute> routes) {
  final result = <AutoRoute>[];
  for (final route in routes) {
    result.add(route);
    final children = route.children;
    if (children != null) result.addAll(_flatten(children));
  }
  return result;
}

/// Parent-management escalation routes — reachable ONLY while a child
/// profile is active (per [ChildModeGuard]'s doc: "a parent supervising a
/// child on a shared device"), and additionally MUST require the Parent PIN
/// before any parent-only mutation (rewards config, tracks, lifetime
/// marking, pending-redemption approval, settings) is reachable.
const _pinGatedEscalationPaths = <String>{
  '/parent-mode/pending-redemptions',
  '/parent-mode/settings',
  '/parent-mode/point-config',
  '/parent-mode/reward-config',
  '/parent-mode/tracks',
  '/settings/lifetime',
  '/settings/lifetime/:curriculumId',
};

/// Deliberately child-facing routes that carry [ChildModeGuard] but NOT
/// [PinGuard] — verified deliberate, not omissions (docs comments + git
/// history at their `app_router.dart` declarations):
///   - `/redeem` — WS7.child-ui: the CHILD'S OWN prize-redemption screen.
///   - `/gamification` — the child-facing points/rewards display.
///   - `/parent-mode/pin-setup` — the PIN-setup flow itself; gating PIN
///     *setup* on the PIN guard would be circular.
const _childFacingNoPinPaths = <String>{
  '/redeem',
  '/gamification',
  '/parent-mode/pin-setup',
};

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  group('R3 — router wiring: parent-only escalation routes are PIN-gated', () {
    test('every declared escalation route carries both childModeGuard and '
        'pinGuard', () {
      final router = _buildRouterForInspection();
      final flat = _flatten(router.routes);

      for (final path in _pinGatedEscalationPaths) {
        final matches = flat.where((r) => r.path == path).toList();
        expect(
          matches,
          hasLength(1),
          reason:
              'expected exactly one AppRouter route at path "$path" — update '
              '_pinGatedEscalationPaths if this route was renamed/removed.',
        );
        final route = matches.single;
        expect(
          route.guards.contains(router.childModeGuard),
          isTrue,
          reason:
              'R3: "$path" is a declared parent-management escalation route '
              'but is missing childModeGuard in AppRouter.',
        );
        expect(
          route.guards.contains(router.pinGuard),
          isTrue,
          reason:
              'R3: "$path" is a declared parent-management escalation route '
              'but is missing pinGuard in AppRouter — a child profile could '
              'reach it without a Parent PIN challenge.',
        );
      }
    });

    test('known child-facing routes intentionally carry NO pinGuard', () {
      final router = _buildRouterForInspection();
      final flat = _flatten(router.routes);

      for (final path in _childFacingNoPinPaths) {
        final matches = flat.where((r) => r.path == path).toList();
        expect(
          matches,
          hasLength(1),
          reason:
              'expected exactly one AppRouter route at path "$path" — '
              'update _childFacingNoPinPaths if this route was '
              'renamed/removed.',
        );
        final route = matches.single;
        expect(
          route.guards.contains(router.childModeGuard),
          isTrue,
          reason: 'R3: "$path" should still require child-mode context.',
        );
        expect(
          route.guards.contains(router.pinGuard),
          isFalse,
          reason:
              'R3: "$path" is documented as deliberately PIN-free '
              '(child-facing surface, or the PIN-setup flow itself) — if '
              'this now needs a PIN challenge, move it into '
              '_pinGatedEscalationPaths instead of just letting this test '
              'fail.',
        );
      }
    });

    test('enumeration is exhaustive — every childModeGuard-gated route is '
        'classified as either PIN-gated or a known child-facing exception', () {
      final router = _buildRouterForInspection();
      final flat = _flatten(router.routes);

      final actualChildGatedPaths = flat
          .where((r) => r.guards.contains(router.childModeGuard))
          .map((r) => r.path)
          .toSet();
      final knownPaths = {
        ..._pinGatedEscalationPaths,
        ..._childFacingNoPinPaths,
      };

      expect(
        actualChildGatedPaths,
        knownPaths,
        reason:
            'R3: a childModeGuard-gated route was added to/removed from '
            'AppRouter without updating this enumeration. A NEW '
            'parent-management route must be added to '
            '_pinGatedEscalationPaths (and will then be checked for '
            'pinGuard above); a genuinely child-facing addition belongs in '
            '_childFacingNoPinPaths with a documented reason — never '
            'silently left unclassified.',
      );
    });
  });

  group('R3 — combined guard chain: child cannot reach a parent-only surface '
      'without the correct PIN', () {
    late _MockPinService pinService;

    setUp(() {
      pinService = _MockPinService();
    });

    Future<int> insertProfile(UserDatabase db, String mode) async {
      final accountId = await seedAccount(db);
      return db
          .into(db.learnerProfiles)
          .insert(
            LearnerProfilesCompanion.insert(
              accountId: accountId,
              displayName: 'Test Profile',
              mode: mode,
              createdAt: DateTimeFactory.nowUtc(),
              updatedAt: DateTimeFactory.nowUtc(),
            ),
          );
    }

    /// Runs [guards] in sequence exactly as AutoRoute's real guarded
    /// navigation does: each guard's `onNavigation` is awaited in turn, and
    /// the FIRST one to resolve `false` aborts the whole chain immediately
    /// (later guards never run) — a faithful behavioral model of the
    /// sequential AND semantics `app_router.dart`'s
    /// `guards: [authGuard, childModeGuard, pinGuard]` lists rely on.
    Future<bool> runChain(List<AutoRouteGuard> guards) async {
      final router = _MockStackRouter();
      when(
        () => router.replace(any<PageRouteInfo>()),
      ).thenAnswer((_) async => null);
      when(
        () => router.push<bool>(any<PageRouteInfo>()),
      ).thenAnswer((_) async => null);

      for (final guard in guards) {
        bool? resolved;
        final resolver = _MockNavigationResolver();
        when(() => resolver.next()).thenAnswer((_) {
          resolved = true;
        });
        when(() => resolver.next(any<bool>())).thenAnswer((invocation) {
          resolved = invocation.positionalArguments.isEmpty
              ? true
              : invocation.positionalArguments[0] as bool;
        });

        await guard.onNavigation(resolver, router);
        if (resolved != true) return false;
      }
      return true;
    }

    test(
      'adult active profile is blocked before the PIN is ever considered',
      () async {
        final db = inMemoryDb();
        addTearDown(db.close);
        final adultId = await insertProfile(db, 'adult');
        final childGuard = ChildModeGuard(
          getDatabase: () => db,
          getSelectedProfileId: () => adultId,
        );
        final pinGuard = PinGuard(
          pinService: pinService,
          pinSetupRoute: () => _FakePageRouteInfo(),
          // Would succeed if ever reached — proves it is NOT reached.
          promptForPin: () async => true,
          getScope: () => PinScope.parent(adultId),
        );

        final allowed = await runChain([childGuard, pinGuard]);

        expect(
          allowed,
          isFalse,
          reason:
              'R3: an adult active profile must never reach a '
              'parent-management escalation route — ChildModeGuard alone '
              'must block it.',
        );
        verifyNever(() => pinService.hasProfilePin(any()));
      },
    );

    test('child active profile with correct PIN is allowed through', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      final childId = await insertProfile(db, 'child');
      when(
        () => pinService.hasProfilePin(childId),
      ).thenAnswer((_) async => true);
      final childGuard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => childId,
      );
      final pinGuard = PinGuard(
        pinService: pinService,
        pinSetupRoute: () => _FakePageRouteInfo(),
        promptForPin: () async => true, // correct PIN entered
        getScope: () => PinScope.parent(childId),
      );

      final allowed = await runChain([childGuard, pinGuard]);

      expect(
        allowed,
        isTrue,
        reason:
            'R3: a child active profile with the correct Parent PIN must '
            'reach the escalation route.',
      );
    });

    test('child active profile with wrong/cancelled PIN is blocked', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      final childId = await insertProfile(db, 'child');
      when(
        () => pinService.hasProfilePin(childId),
      ).thenAnswer((_) async => true);
      final childGuard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => childId,
      );
      final pinGuard = PinGuard(
        pinService: pinService,
        pinSetupRoute: () => _FakePageRouteInfo(),
        promptForPin: () async => false, // wrong / cancelled
        getScope: () => PinScope.parent(childId),
      );

      final allowed = await runChain([childGuard, pinGuard]);

      expect(
        allowed,
        isFalse,
        reason:
            'R3: passing ChildModeGuard is NOT sufficient — a wrong or '
            'cancelled PIN must still block the escalation route.',
      );
    });

    test('child active profile with no PIN configured yet still gates '
        'through the setup flow — never bypasses', () async {
      final db = inMemoryDb();
      addTearDown(db.close);
      final childId = await insertProfile(db, 'child');
      when(
        () => pinService.hasProfilePin(childId),
      ).thenAnswer((_) async => false);
      final childGuard = ChildModeGuard(
        getDatabase: () => db,
        getSelectedProfileId: () => childId,
      );
      var setupRoutePushed = false;
      final pinGuard = PinGuard(
        pinService: pinService,
        pinSetupRoute: () {
          setupRoutePushed = true;
          return _FakePageRouteInfo();
        },
        promptForPin: () async => false, // must not be reached
        getScope: () => PinScope.parent(childId),
      );

      // router.push<bool> must return the setup outcome, not skip it.
      final router = _MockStackRouter();
      when(
        () => router.push<bool>(any<PageRouteInfo>()),
      ).thenAnswer((_) async => true);

      bool? childResolved;
      final childResolver = _MockNavigationResolver();
      when(() => childResolver.next(any<bool>())).thenAnswer((inv) {
        childResolved = inv.positionalArguments[0] as bool;
      });
      await childGuard.onNavigation(childResolver, router);
      expect(childResolved, isTrue);

      bool? pinResolved;
      final pinResolver = _MockNavigationResolver();
      when(() => pinResolver.next(any<bool>())).thenAnswer((inv) {
        pinResolved = inv.positionalArguments[0] as bool;
      });
      await pinGuard.onNavigation(pinResolver, router);

      expect(
        setupRoutePushed,
        isTrue,
        reason: 'no PIN configured yet must route through PIN setup.',
      );
      expect(
        pinResolved,
        isTrue,
        reason:
            'setup flow succeeding still gates the navigation (via '
            'the setup route itself), it never silently skips PIN '
            'protection.',
      );
    });
  });
}

class _MockStackRouter extends Mock implements StackRouter {}

class _MockNavigationResolver extends Mock implements NavigationResolver {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}
