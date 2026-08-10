// Unit tests for RestoreGuard — all routing branches.
//
// Branch 1: _isNewDevice already false (cached) → resolver.next().
// Branch 2: no cloud account             → resolver.next()  (local-only user).
// Branch 3: cloud account + empty DB     → router.replace(DeviceRestoreRoute)
//                                          + resolver.next(false)  (new device).
// Branch 4: cloud account + non-empty DB → resolver.next()  (existing device).
// Branch 5: markRestoreComplete() flips cache → subsequent guard call passes.
// Non-empty-via-profiles: accounts table has rows → resolver.next().
// Non-empty-via-completions: completion_events rows → resolver.next().
// No-dead-end assertion: every branch calls next() or [replace + next(false)].
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/router/app_router.dart'
    show DeviceRestoreRoute;
import 'package:learning_tracker/core/analytics/parent_analytics_repository.dart';
import 'package:learning_tracker/core/database/daos/completion_dao.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/cross_profile_scope.dart';
import 'package:learning_tracker/core/navigation/guards/restore_guard.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/test_database.dart';

class MockNavigationResolver extends Mock implements NavigationResolver {}

class MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

/// Fake [ParentAnalyticsRepository] for AUD-core-navigation-04 (SM-7): proves
/// [RestoreGuard] can have its analytics dependency substituted via the
/// constructor seam without also faking the completion rows in
/// [UserDatabase] — mirroring the `local_data_upload_service_test.dart`
/// precedent (AUD-sync-05).
///
/// Only [getAllCompletions] is exercised by [RestoreGuard.onNavigation] —
/// the remaining methods are unused by that path and throw if ever called,
/// so an accidental new dependency on them fails loudly instead of silently
/// returning empty data.
class _FakeParentAnalyticsRepository implements ParentAnalyticsRepository {
  _FakeParentAnalyticsRepository(this._completions);

  final List<Completion> _completions;
  int getAllCompletionsCallCount = 0;

  @override
  Future<List<Completion>> getAllCompletions({
    required CrossProfileScope scope,
  }) async {
    getAllCompletionsCallCount++;
    return _completions;
  }

  @override
  Future<List<Completion>> getCompletionsByCurriculum(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<List<Completion>> getCompletionsForContent(
    String sefariaRef, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<List<Completion>> getCompletionsByDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<bool> hasCompletionsInDateRange(
    DateTime start,
    DateTime end, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<int> getAggregateCount(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();

  @override
  Future<Map<String, int>> getTrackBreakdown(
    String curriculumId, {
    required CrossProfileScope scope,
  }) => throw UnimplementedError();
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Inserts a learner profile (with an account row for FK) into [db].
/// Returns the inserted profile id.
Future<int> _insertProfile(UserDatabase db) async {
  final accountId = await seedAccount(db);
  return db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Alice',
          mode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

/// Inserts one completion event for [profileId].
Future<void> _insertCompletionEvent(
  UserDatabase db, {
  required int profileId,
  required int trackId,
}) async {
  await db.completionEventDao.appendEvent(
    CompletionEventsCompanion.insert(
      profileId: profileId,
      curriculumId: 'talmud_bavli',
      sefariaRef: 'Berakhot.1.1',
      stageId: 1,
      trackType: 'personal',
      trackId: Value(trackId),
      points: const Value(0),
      eventTimestamp: DateTimeFactory.nowUtc(),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late UserDatabase db;
  late MockNavigationResolver resolver;
  late MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() async {
    db = createTestDatabase();
    resolver = MockNavigationResolver();
    router = MockStackRouter();
    when(
      () => router.replace(any<PageRouteInfo>()),
    ).thenAnswer((_) async => null);
  });

  tearDown(() async {
    await db.close();
  });

  // ── Branch 1: already-resolved (cached _isNewDevice = false) ──────────────

  group('already-resolved cache (_isNewDevice == false)', () {
    test('calls resolver.next() without touching DB or router', () async {
      var dbCalls = 0;
      final guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () {
          dbCalls++;
          return db;
        },
        hasCloudAccount: () => true,
      );
      // Pre-warm the cache via markRestoreComplete().
      guard.markRestoreComplete();

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
      // Short-circuit — DB factory must NOT have been invoked.
      expect(dbCalls, 0);
    });
  });

  // ── Branch 2: local-only user (no cloud account) ──────────────────────────

  group('no cloud account (local-only user)', () {
    late RestoreGuard guard;

    setUp(() {
      guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () => db,
        hasCloudAccount: () => false,
      );
    });

    test('calls resolver.next() and does not redirect', () async {
      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });

    test('caches result — second navigation also passes through', () async {
      await guard.onNavigation(resolver, router);
      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(2);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 3: cloud account + empty DB → new-device redirect ─────────────

  group('cloud account + empty DB (new device)', () {
    test('replaces with DeviceRestoreRoute and calls next(false)', () async {
      // DB is completely empty — no completions, no profiles.
      final guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () => db,
        hasCloudAccount: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(
        () => router.replace(
          any<PageRouteInfo>(
            that: isA<PageRouteInfo>().having(
              (r) => r.routeName,
              'routeName',
              'DeviceRestoreRoute',
            ),
          ),
        ),
      ).called(1);
      verify(() => resolver.next(false)).called(1);
      verifyNever(() => resolver.next());
    });

    test(
      'no-dead-end: next(false) is always called alongside replace()',
      () async {
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );

        await guard.onNavigation(resolver, router);

        // Every navigation MUST call either next() or next(false) — no lockout.
        verify(() => resolver.next(false)).called(1);
      },
    );

    test('AUD-core-navigation-01: replaces with exactly the route returned by '
        'the injected deviceRestoreRoute builder, not a route the guard '
        'builds itself', () async {
      // Regression for the app→core→app import cycle: RestoreGuard used
      // to hardcode `const DeviceRestoreRoute()` internally (importing the
      // app-layer route class directly). Prove the redirect route is now
      // fully caller-controlled by injecting a distinctive marker route
      // that the guard could not possibly have constructed on its own.
      final guard = RestoreGuard(
        deviceRestoreRoute: () =>
            const PageRouteInfo('AUD_CORE_NAV_01_MARKER_ROUTE'),
        getDatabase: () => db,
        hasCloudAccount: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(
        () => router.replace(
          any<PageRouteInfo>(
            that: isA<PageRouteInfo>().having(
              (r) => r.routeName,
              'routeName',
              'AUD_CORE_NAV_01_MARKER_ROUTE',
            ),
          ),
        ),
      ).called(1);
      verify(() => resolver.next(false)).called(1);
    });
  });

  // ── Branch 4a: cloud account + non-empty via profiles ─────────────────────

  group('cloud account + profiles present (existing device)', () {
    test('resolver.next() — no redirect', () async {
      await _insertProfile(db);
      final guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () => db,
        hasCloudAccount: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });

    test(
      'caches non-empty result — second call short-circuits even if DB cleared',
      () async {
        await _insertProfile(db);
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );

        await guard.onNavigation(resolver, router);
        // Simulate row deletion between navigations.
        await db.delete(db.learnerProfiles).go();
        await db.delete(db.accounts).go();

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(2);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );
  });

  // ── Branch 4b: cloud account + non-empty via completion events only ────────

  group('cloud account + completion events present (existing device)', () {
    test('resolver.next() — no redirect', () async {
      // Need a profile + track for FK integrity, but the key signal is the
      // completion_events row (the guard checks completions.isEmpty first).
      final profileId = await _insertProfile(db);
      final trackId = await db
          .into(db.curriculumTracks)
          .insert(
            CurriculumTracksCompanion.insert(
              profileId: profileId,
              curriculumId: 'talmud_bavli',
              stateChangedAt: DateTimeFactory.nowUtc(),
              activatedAt: DateTimeFactory.nowUtc(),
              state: const Value('active'),
            ),
          );
      await _insertCompletionEvent(db, profileId: profileId, trackId: trackId);

      final guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () => db,
        hasCloudAccount: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next()).called(1);
      verifyNever(() => resolver.next(false));
      verifyNever(() => router.replace(any<PageRouteInfo>()));
    });
  });

  // ── Branch 5: markRestoreComplete() effect ────────────────────────────────

  group('markRestoreComplete()', () {
    test(
      'prevents redirect on subsequent navigation after restore screen',
      () async {
        // Guard starts with empty DB + cloud account → would redirect.
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );

        // First navigation: new device, redirects.
        await guard.onNavigation(resolver, router);
        verify(() => resolver.next(false)).called(1);
        verify(() => router.replace(any<PageRouteInfo>())).called(1);

        // Mark restore complete (called from restore screen on finish).
        guard.markRestoreComplete();

        // Subsequent navigation: must pass through without redirect.
        final resolver2 = MockNavigationResolver();
        final router2 = MockStackRouter();
        when(
          () => router2.replace(any<PageRouteInfo>()),
        ).thenAnswer((_) async => null);

        await guard.onNavigation(resolver2, router2);

        verify(() => resolver2.next()).called(1);
        verifyNever(() => resolver2.next(false));
        verifyNever(() => router2.replace(any<PageRouteInfo>()));
      },
    );

    test(
      'markRestoreComplete on fresh guard (never ran) → next() on first nav',
      () async {
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => true,
        );
        guard.markRestoreComplete();

        // Even with empty DB and cloud account, the pre-set cache wins.
        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );
  });

  // ── hasCloudAccount toggled between sessions ──────────────────────────────

  group('hasCloudAccount toggled after first navigation', () {
    test(
      'no-cloud-account path caches false; '
      'subsequent nav respects cache even if cloud account appears',
      () async {
        var hasCloud = false;
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => hasCloud,
        );

        // First nav: no cloud account, passes through and caches.
        await guard.onNavigation(resolver, router);
        verify(() => resolver.next()).called(1);

        // Cloud account arrives (e.g. sign-in happens), but cache already set.
        hasCloud = true;
        final resolver2 = MockNavigationResolver();
        final router2 = MockStackRouter();
        when(
          () => router2.replace(any<PageRouteInfo>()),
        ).thenAnswer((_) async => null);

        await guard.onNavigation(resolver2, router2);

        // Must still pass through — no redirect because _isNewDevice == false.
        verify(() => resolver2.next()).called(1);
        verifyNever(() => resolver2.next(false));
        verifyNever(() => router2.replace(any<PageRouteInfo>()));
      },
    );
  });

  // ── AUD-core-navigation-04 (SM-7): injected analytics repository seam ─────
  //
  // RestoreGuard must read completions from an injectable
  // ParentAnalyticsRepository dependency rather than hand-constructing
  // ParentAnalyticsRepositoryImpl(db) inline in onNavigation() — mirroring
  // the LocalDataUploadService precedent (AUD-sync-05). Proven by starting
  // from a completely empty real DB (which on its own signals "new device")
  // and injecting a fake repository whose non-empty completions list must be
  // the thing that flips the outcome — that can only happen if onNavigation
  // is actually calling through the injected seam.
  group('injected analyticsRepository (AUD-core-navigation-04, SM-7)', () {
    test(
      'onNavigation reads completions from the injected buildAnalyticsRepository, '
      'not from a self-constructed ParentAnalyticsRepositoryImpl',
      () async {
        // Real DB is completely empty — no completions, no profiles — so
        // without the injected seam this would be treated as a new device.
        final fakeRepo = _FakeParentAnalyticsRepository([
          Completion(
            id: 999,
            profileId: 1,
            curriculumId: 'talmud_bavli',
            sefariaRef: 'Injected Ref 1:1',
            stageId: 1,
            trackType: 'personal',
            trackId: 0,
            completedAt: DateTimeFactory.nowUtc(),
            points: 5,
          ),
        ]);

        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => db,
          hasCloudAccount: () => true,
          buildAnalyticsRepository: (_) => fakeRepo,
        );

        await guard.onNavigation(resolver, router);

        expect(
          fakeRepo.getAllCompletionsCallCount,
          1,
          reason: 'onNavigation must call the injected repository',
        );
        // The fake's non-empty completion is the ONLY thing that could
        // prevent a redirect here (the real DB has zero rows of either
        // kind) — proving onNavigation used the injected seam instead of
        // constructing its own ParentAnalyticsRepositoryImpl.
        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );

    test('defaults to the real ParentAnalyticsRepositoryImpl when '
        'buildAnalyticsRepository is omitted', () async {
      // No override supplied — production behaviour (real, empty DB ⇒ new
      // device) must be unchanged.
      final guard = RestoreGuard(
        deviceRestoreRoute: () => const DeviceRestoreRoute(),
        getDatabase: () => db,
        hasCloudAccount: () => true,
      );

      await guard.onNavigation(resolver, router);

      verify(() => resolver.next(false)).called(1);
      verify(() => router.replace(any<PageRouteInfo>())).called(1);
    });
  });

  // ── Fail-safe: unexpected throw → fail OPEN (restore is optional), no hang ─
  //
  // The DB read (or the hasCloudAccount closure) can throw — a corrupt/locked
  // DB, a disposed provider lambda. Restore is an optimisation (the user can
  // also restore from Settings), so the guard wraps onNavigation in a try/catch
  // that fails OPEN (next()) — letting navigation proceed rather than hang.
  group('unexpected throw (fail-open, no dead-end)', () {
    test(
      'throwing database lambda → resolver.next(), allows through',
      () async {
        when(() => resolver.isResolved).thenReturn(false);
        final guard = RestoreGuard(
          deviceRestoreRoute: () => const DeviceRestoreRoute(),
          getDatabase: () => throw StateError('provider disposed mid-flight'),
          hasCloudAccount: () => true,
        );

        await guard.onNavigation(resolver, router);

        verify(() => resolver.next()).called(1);
        verifyNever(() => resolver.next(false));
        verifyNever(() => router.replace(any<PageRouteInfo>()));
      },
    );
  });
}
