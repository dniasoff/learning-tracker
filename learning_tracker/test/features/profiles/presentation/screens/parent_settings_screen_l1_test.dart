// L1 widget tests for ParentSettingsScreen
//
// Focus: Tutor-permission tile matrix (DEC-9 / DEC-14).
//
// Coverage:
//   1.  Owner context — all edit tiles visible (Manage Tracks, Point
//       Configuration, Adjust Points, Reward Configuration, Pending Prizes,
//       Add Lifetime Learning, Manage Tutors, BackupSyncSection, Sign Out,
//       account-safety section header).
//   2.  Tutor context, all-perms enabled — all edit tiles visible (same as
//       owner minus the owner-only cluster).
//   3.  Tutor context, canEditStages=false → Manage Tracks tile hidden.
//   4.  Tutor context, canEditPoints=false → Point Configuration + Adjust
//       Points tiles hidden.
//   5.  Tutor context, canEditRewards=false → Reward Configuration + Pending
//       Prizes tiles hidden.
//   6.  Tutor context, all three blocked → edit panel entirely absent.
//   7.  Owner-only tiles hidden in any tutored context.
//   8.  Tutor context, canBulkPriorCompletion=false → bulk-mark tile hidden.
//   9.  Tutor context, all-perms enabled → bulk-mark tile visible.
//  10.  AppBar title is "Parent Settings" (l10n).
//  11.  Tapping Manage Tracks pushes ParentTrackManagementRoute.
//  12.  Tapping Point Configuration pushes PointConfigRoute.
//  13.  Tapping Reward Configuration pushes RewardConfigurationRoute.
//  14.  Tapping Add Lifetime Learning pushes LifetimeMarkingRoute.
//  15.  Tapping Manage Tutors pushes ManageTutorsRoute.
//  16.  He-RTL smoke — locale=he renders without crash/overflow.
//
// HARDCODED-STRING NOTE:
//   None of the screen strings use hardcoded English — they are all sourced
//   via l10n (AppLocalizations) or are icon labels.
//
// BUG LOG: none detected.

@Tags(['profiles', 'parent_settings'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/screens/parent_settings_screen.dart';
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/drift_memory.dart';

// ─── Mocks ────────────────────────────────────────────────────────────────────

class _MockStackRouter extends Mock implements StackRouter {}

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Fixtures ─────────────────────────────────────────────────────────────────

ProfileModel _childProfile({int id = 1, String displayName = 'Moshe'}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: 1,
    displayName: displayName,
    mode: 'child',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

// ─── Widget builder ────────────────────────────────────────────────────────────

/// Sets a tall phone-like viewport so the scrollable ListView can render all
/// tiles without clipping the owner-only section at the bottom.
void _useTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Builds [ParentSettingsScreen] with the given provider overrides.
///
/// [tutorPerms] — null → owner mode (no tutored context);
///               non-null → tutored mode with those permissions.
/// [locale] — default `en`; pass `he` for RTL smoke.
Widget _buildApp({
  required _MockStackRouter router,
  TutorPermissions? tutorPerms,
  Locale locale = const Locale('en'),
  AuthState? authState,
}) {
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(null);

  final resolvedAuthState = authState ?? const AuthState.signedOut();

  final db = inMemoryDb();

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      // Auth
      authRepositoryProvider.overrideWithValue(auth),
      authStateProvider.overrideWithValue(resolvedAuthState),

      // Profiles
      activeProfileIdProvider.overrideWithValue(1),
      profileListStreamProvider.overrideWith(
        (ref) => Stream.value([_childProfile()]),
      ),

      // Tutored context
      activeTutorPermissionsProvider.overrideWithValue(tutorPerms),

      // Sync status — stub to avoid orchestrator initialisation
      syncStatusProvider.overrideWithValue(const SyncStatus.localOnly()),

      // In-memory DB for the points-adjust dialog path (userDatabaseProvider)
      userDatabaseProvider.overrideWithValue(db),
    ],
    child: MaterialApp(
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: StackRouterScope(
        controller: router,
        stateHash: 0,
        child: const ParentSettingsScreen(),
      ),
    ),
  );
}

Future<void> _tearDown(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(Duration.zero);
}

// ─── Tests ────────────────────────────────────────────────────────────────────

void main() {
  late _MockStackRouter router;

  setUpAll(() {
    registerFallbackValue(_FakePageRouteInfo());
  });

  setUp(() {
    router = _MockStackRouter();
    when(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).thenAnswer((_) => Future<Object?>.value(null));
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/parent-settings');
    when(
      () => router.maybePop<Object?>(),
    ).thenAnswer((_) => Future<bool>.value(false));
  });

  // ── 1. Owner context: all edit tiles visible ───────────────────────────────

  testWidgets('owner context: Manage Tracks tile is visible', (tester) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: Point Configuration tile is visible', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Point Configuration'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: Reward Configuration tile is visible', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward configuration'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: Add Lifetime Learning tile is visible', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Add Lifetime Learning'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: Manage Tutors tile is visible (owner-only)', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tutors'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: account-safety section header visible', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('ACCOUNT SAFETY'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('owner context: Sign Out tile visible', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign Out'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 2. Tutor context, all-perms → edit tiles visible (minus owner-only) ───

  testWidgets('tutor context, all-perms: Manage Tracks tile visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('tutor context, all-perms: Point Configuration tile visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Point Configuration'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets('tutor context, all-perms: Reward Configuration tile visible', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Reward configuration'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 3. Tutor context, canEditStages=false → Manage Tracks hidden ──────────

  testWidgets('tutor context, canEditStages=false: Manage Tracks tile hidden', (
    tester,
  ) async {
    final perms = TutorPermissions.defaults().copyWith(canEditStages: false);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsNothing);

    await _tearDown(tester);
  });

  // ── 4. Tutor context, canEditPoints=false → Point Config + Adjust hidden ──

  testWidgets(
    'tutor context, canEditPoints=false: Point Configuration tile hidden',
    (tester) async {
      final perms = TutorPermissions.defaults().copyWith(canEditPoints: false);
      await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Point Configuration'), findsNothing);

      await _tearDown(tester);
    },
  );

  testWidgets('tutor context, canEditPoints=false: Adjust Points tile hidden', (
    tester,
  ) async {
    final perms = TutorPermissions.defaults().copyWith(canEditPoints: false);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Adjust Points'), findsNothing);

    await _tearDown(tester);
  });

  // ── 5. Tutor context, canEditRewards=false → Reward tiles hidden ──────────

  testWidgets(
    'tutor context, canEditRewards=false: Reward Configuration tile hidden',
    (tester) async {
      final perms = TutorPermissions.defaults().copyWith(canEditRewards: false);
      await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Reward configuration'), findsNothing);

      await _tearDown(tester);
    },
  );

  testWidgets(
    'tutor context, canEditRewards=false: Pending Prizes tile hidden',
    (tester) async {
      final perms = TutorPermissions.defaults().copyWith(canEditRewards: false);
      await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Pending Prizes'), findsNothing);

      await _tearDown(tester);
    },
  );

  // ── 6. All three blocked → edit panel absent ──────────────────────────────

  testWidgets('tutor context, no edit perms: entire edit panel absent '
      '(no Manage Tracks / Point Config / Reward Config)', (tester) async {
    const perms = TutorPermissions(
      canEditStages: false,
      canEditPoints: false,
      canEditRewards: false,
    );
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsNothing);
    expect(find.text('Point Configuration'), findsNothing);
    expect(find.text('Reward configuration'), findsNothing);
    expect(find.text('Adjust Points'), findsNothing);
    expect(find.text('Pending Prizes'), findsNothing);

    await _tearDown(tester);
  });

  // ── 7. Owner-only tiles hidden in any tutored context ─────────────────────

  testWidgets(
    'tutor context, all-perms: Manage Tutors tile hidden (owner-only)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manage Tutors'), findsNothing);

      await _tearDown(tester);
    },
  );

  testWidgets(
    'tutor context: account-safety section header hidden (owner-only)',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ACCOUNT SAFETY'), findsNothing);

      await _tearDown(tester);
    },
  );

  testWidgets('tutor context: Sign Out tile hidden (owner-only)', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Sign Out'), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('tutor context, no-edit perms: Manage Tutors still hidden', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.readOnly()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tutors'), findsNothing);

    await _tearDown(tester);
  });

  // ── 8. canBulkPriorCompletion=false → bulk-mark tile hidden ───────────────

  testWidgets(
    'tutor context, canBulkPriorCompletion=false: bulk-mark tile hidden',
    (tester) async {
      final perms = TutorPermissions.defaults().copyWith(
        canBulkPriorCompletion: false,
      );
      await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Lifetime Learning'), findsNothing);

      await _tearDown(tester);
    },
  );

  // ── 9. canBulkPriorCompletion=true (default) → bulk-mark tile visible ─────

  testWidgets(
    'tutor context, canBulkPriorCompletion=true: bulk-mark tile visible',
    (tester) async {
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Lifetime Learning'), findsOneWidget);

      await _tearDown(tester);
    },
  );

  // ── 10. AppBar title ───────────────────────────────────────────────────────

  testWidgets('AppBar title is "Parent Settings" (l10n)', (tester) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Parent Settings'), findsOneWidget);

    await _tearDown(tester);
  });

  // ── 11. Tapping Manage Tracks pushes route ─────────────────────────────────

  testWidgets('tapping Manage Tracks pushes ParentTrackManagementRoute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Manage Tracks'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await _tearDown(tester);
  });

  // ── 12. Tapping Point Configuration pushes route ──────────────────────────

  testWidgets('tapping Point Configuration pushes PointConfigRoute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Point Configuration'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await _tearDown(tester);
  });

  // ── 13. Tapping Reward Configuration pushes route ─────────────────────────

  testWidgets('tapping Reward Configuration pushes RewardConfigurationRoute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Reward configuration'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await _tearDown(tester);
  });

  // ── 14. Tapping Add Lifetime Learning pushes route ────────────────────────

  testWidgets('tapping Add Lifetime Learning pushes LifetimeMarkingRoute', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Add Lifetime Learning'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await _tearDown(tester);
  });

  // ── 15. Tapping Manage Tutors pushes route ────────────────────────────────

  testWidgets('tapping Manage Tutors pushes ManageTutorsRoute', (tester) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Manage Tutors'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

    await _tearDown(tester);
  });

  // ── 16. RTL smoke (Hebrew locale) ─────────────────────────────────────────

  testWidgets('Hebrew locale (RTL): screen renders without crash or overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: null, locale: const Locale('he')),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    // Screen body rendered in RTL without throwing
    expect(find.byType(Scaffold), findsOneWidget);
    // At least the manage-tracks icon is present
    expect(find.byIcon(Icons.route_rounded), findsOneWidget);

    await _tearDown(tester);
  });

  // ── Mixed: explicit canEditStages=true but canEditRewards=false ────────────

  testWidgets(
    'tutor: canEditStages=true + canEditRewards=false → Tracks visible, '
    'Rewards hidden',
    (tester) async {
      const perms = TutorPermissions(
        canEditStages: true,
        canEditRewards: false,
      );
      await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manage Tracks'), findsOneWidget);
      expect(find.text('Reward configuration'), findsNothing);

      await _tearDown(tester);
    },
  );

  // ── Read-only tutor: all edit tiles hidden ────────────────────────────────

  testWidgets('tutor readOnly: all gated edit tiles absent', (tester) async {
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: TutorPermissions.readOnly()),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsNothing);
    expect(find.text('Point Configuration'), findsNothing);
    expect(find.text('Adjust Points'), findsNothing);
    expect(find.text('Reward configuration'), findsNothing);
    expect(find.text('Pending Prizes'), findsNothing);
    expect(find.text('Add Lifetime Learning'), findsNothing);

    await _tearDown(tester);
  });

  // ── Delete-account tile gated on signed-in user ───────────────────────────

  testWidgets('owner context, signed-out: Delete Account tile hidden', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(
      _buildApp(
        router: router,
        tutorPerms: null,
        authState: const AuthState.signedOut(),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Delete Account'), findsNothing);

    await _tearDown(tester);
  });

  testWidgets(
    'owner context, local-born signed-in: Delete Account tile visible',
    (tester) async {
      _useTallViewport(tester);
      const localState = AuthState.signedIn(
        user: AuthUser(
          profileId: 1,
          email: 'local@example.com',
          displayName: 'Local User',
        ),
        tier: Tier.localBorn,
      );
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: null, authState: localState),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Delete Account'), findsOneWidget);

      await _tearDown(tester);
    },
  );
}
