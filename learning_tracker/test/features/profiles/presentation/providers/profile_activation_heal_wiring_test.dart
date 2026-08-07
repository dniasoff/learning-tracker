/// WIRING test for T-40: proves the "heal a missing remote profile
/// document" path actually FIRES on a cold-start, single-profile
/// activation — not a unit test of
/// `FirestoreProfileRepositoryAdapter.ensureRemoteProfile` in isolation
/// (see `test/features/profiles/data/repositories/profile_repository_impl_test.dart`
/// for those; `grep -rn ensureRemoteProfile test/` found only that kind of
/// test before this file, which is exactly why the trigger shipped
/// unreachable twice without any test catching it).
///
/// This test drives the REAL [ProfileGuard]
/// (`lib/core/navigation/guards/profile_guard.dart`) wired with the SAME
/// closure shape `lib/app/router/router_provider.dart` uses in
/// production — `setSelectedProfileId` forwards straight into
/// `SelectedProfileId.select()` (`profile_providers.dart`), a real Riverpod
/// notifier over a real [ProviderContainer], never a bare test-double
/// callback. On the PRE-FIX tree (the heal trigger hooked into
/// `AppShellScreen`'s `ref.listen`, never built by this guard-only test)
/// this test fails: the guard resolves and selects the profile, but the
/// remote document is never created, because nothing here builds
/// `AppShellScreen`'s widget tree. On the FIXED tree (the trigger lives
/// inside `select()` itself) it passes.
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/navigation/guards/profile_guard.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    show activeAccountFirebaseProvider, activeAccountIdProvider;
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

class MockFirebaseAuthHandle extends Mock implements FirebaseAuth {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  test('T-40 WIRING: ProfileGuard\'s real cold-start, single-profile '
      'auto-select branch — wired exactly as router_provider.dart wires it '
      '(setSelectedProfileId forwards into SelectedProfileId.select()) — '
      'creates the missing Firestore learner_profiles document, with no '
      'direct ensureRemoteProfile call anywhere in this test', () async {
    const uid = 'uid-t40-wiring';
    final db = createTestDatabase();
    addTearDown(db.close);
    final accountId = await seedAccount(db);
    const ulid = 'ulid-t40-cold-start';
    final profileId = await db
        .into(db.learnerProfiles)
        .insert(
          LearnerProfilesCompanion.insert(
            accountId: accountId,
            displayName: 'Cold Start Learner',
            mode: 'adult',
            createdAt: DateTimeFactory.nowUtc(),
            updatedAt: DateTimeFactory.nowUtc(),
            // Simulates the exact D10/R4 scenario T-40 exists for: a
            // profile minted a real local ULID (e.g. created offline)
            // whose remote document never got created.
            ulid: const Value(ulid),
          ),
        );

    final firestore = FakeFirebaseFirestore();
    final docRef = firestore
        .collection('users')
        .doc(uid)
        .collection('learner_profiles')
        .doc(ulid);
    expect(
      (await docRef.get()).exists,
      isFalse,
      reason: 'precondition: the remote document must start out missing',
    );

    final container = ProviderContainer(
      overrides: [
        userDatabaseProvider.overrideWithValue(db),
        // localBorn/initializing keeps syncWriteFacadeProvider (a
        // dependency of profileRepositoryProvider, watched inside
        // SelectedProfileId.select()) returning null — this test's only
        // concern is the ACTIVATION heal, not the legacy sync-engine push.
        authStateProvider.overrideWithValue(const AuthState.initializing()),
        activeAccountFirebaseProvider.overrideWith(
          (ref) async => AccountFirebaseHandles(
            app: MockFirebaseApp(),
            firestore: firestore,
            auth: MockFirebaseAuthHandle(),
            uid: uid,
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    // Production sets this before any profile selection can happen —
    // bootstrap (cold start) and every sign-in/sign-up/account-switch flow
    // (`active_account_providers.dart`'s own doc comment: "wired into
    // production"). `SelectedProfileId.select()` gates the heal dispatch
    // on it being set (see that method's own doc comment) specifically so
    // a container that never established this seam doesn't pay the cost
    // of building `profileRepositoryProvider` (a real on-disk Drift
    // database) for nothing — this test establishes it deliberately,
    // matching what a real cold start already does.
    container.read(activeAccountIdProvider.notifier).set('device-acct-1');

    final resolver = MockNavigationResolver();
    final router = MockStackRouter();
    when(() => router.replace(any())).thenAnswer((_) async => null);

    // Wired EXACTLY as `lib/app/router/router_provider.dart` wires the
    // real ProfileGuard in production (see its `profileGuard:
    // ProfileGuard(...)` construction) — setSelectedProfileId forwards
    // straight into the real `SelectedProfileId.select()`.
    final guard = ProfileGuard(
      getDatabase: () => db,
      getSelectedProfileId: () => container.read(selectedProfileIdProvider),
      setSelectedProfileId: (id, {required String ulid}) {
        container
            .read(selectedProfileIdProvider.notifier)
            .select(id, ulid: ulid);
      },
      getAccountId: () => accountId,
      isTutoredSession: () => false,
      profilePickerRoute: () => _FakePageRouteInfo(),
    );

    // The real cold-start trigger: `app_router.dart` attaches
    // `profileGuard` to `AppShellRoute` ITSELF, so this resolves BEFORE
    // any shell widget (or a `ref.listen` mounted inside one) could ever
    // build — Branch 3, single own profile, none selected yet.
    await guard.onNavigation(resolver, router);

    // Cold start proceeds straight into the shell — not the picker.
    verify(() => resolver.next()).called(1);
    verifyNever(() => resolver.next(false));
    expect(
      container.read(selectedProfileIdProvider),
      profileId,
      reason: 'sanity: the guard did select the seeded profile',
    );

    // The heal is fire-and-forget (unawaited inside select()) — drain the
    // event queue so its Future actually completes before asserting.
    await pumpEventQueue();

    expect(
      (await docRef.get()).exists,
      isTrue,
      reason:
          'ProfileGuard\'s cold-start single-profile auto-select must '
          'reach ProfileRepository.ensureRemoteProfile via '
          'SelectedProfileId.select(). On the broken (pre-fix) wiring '
          'this document is never created, because the only heal '
          'trigger lived in a widget ref.listen that this guard-level '
          'cold-start path never builds — see '
          'docs/planning/firestore-cutover-log.md\'s T-40 entries.',
    );
  });
}
