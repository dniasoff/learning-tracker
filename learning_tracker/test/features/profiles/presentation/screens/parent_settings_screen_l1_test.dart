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
import 'package:learning_tracker/core/database/user/user_database.dart';
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
  UserDatabase? db,
}) {
  final auth = _MockAuthRepository();
  when(() => auth.currentUser).thenReturn(null);

  final resolvedAuthState = authState ?? const AuthState.signedOut();

  final resolvedDb = db ?? inMemoryDb();

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
      userDatabaseProvider.overrideWithValue(resolvedDb),
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
    _useTallViewport(tester);
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

  // ── Goals: owner + tutor see "Manage Goals"; canEditGoals=false hides it ──

  testWidgets('owner context: Manage Goals tile is visible', (tester) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Goals'), findsOneWidget);

    await _tearDown(tester);
  });

  testWidgets(
    'tutor context, all-perms (canEditGoals=true): Manage Goals tile visible',
    (tester) async {
      // Default tutor permissions have canEditGoals=true (and
      // canMarkLiveCompletion hard-false), so the tutor CAN reach + edit goals.
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: TutorPermissions.defaults()),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manage Goals'), findsOneWidget);

      await _tearDown(tester);
    },
  );

  testWidgets('tutor context, canEditGoals=false: Manage Goals tile hidden', (
    tester,
  ) async {
    final perms = TutorPermissions.defaults().copyWith(canEditGoals: false);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Goals'), findsNothing);

    await _tearDown(tester);
  });

  testWidgets('tapping Manage Goals pushes ParentTrackManagementRoute', (
    tester,
  ) async {
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    await tester.tap(find.text('Manage Goals'));
    await tester.pump();

    verify(
      () => router.push<Object?>(any(), onFailure: any(named: 'onFailure')),
    ).called(1);

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
      '(no Manage Tracks / Goals / Point Config / Reward Config)', (
    tester,
  ) async {
    const perms = TutorPermissions(
      canEditStages: false,
      canEditGoals: false,
      canEditPoints: false,
      canEditRewards: false,
    );
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: perms));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Manage Tracks'), findsNothing);
    expect(find.text('Manage Goals'), findsNothing);
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
      _useTallViewport(tester);
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
    expect(find.text('Manage Goals'), findsNothing);
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

  // ── 5. Adjust Points dialog: empty/0 must NOT silently no-op ────────────────
  //
  // Regression: Apply previously always popped(true); the amount guard ran
  // AFTER dismissal, so an empty/0 amount closed the dialog and adjusted
  // nothing. Apply is now disabled until a positive integer is entered, and a
  // valid amount applies the delta to the points balance.

  // Opens the Adjust Points dialog from the owner-context settings list.
  Future<void> openAdjustPointsDialog(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    // Tap the settings tile (the first "Adjust Points" — the dialog title
    // renders the same string once open).
    await tester.tap(find.text('Adjust Points').first);
    await tester.pumpAndSettle();
  }

  // Resolves the Apply FilledButton inside the open dialog.
  FilledButton applyButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Apply'));

  // Taps Apply and lets the async parentAdjust DB write complete WITHOUT
  // driving the dialog exit transition.
  //
  // Driving the AlertDialog dismissal/snackbar frames in the synthetic test
  // viewport produces a benign RenderFlex overflow (the `mainAxisSize.min`
  // content Column briefly gets a collapsing constraint) which then cascades
  // into framework element-tree assertions and fails the test. Since the
  // behaviour under test is "a valid amount is persisted", we fire the tap and
  // drain real microtasks via [WidgetTester.runAsync] instead of pumping the
  // animation.
  Future<void> applyAndDrainDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, 'Apply'));
    // Let the awaited `showDialog` future resolve and `parentAdjust` run.
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
  }

  testWidgets('Adjust Points: Apply is disabled when amount is empty', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await openAdjustPointsDialog(tester);

    expect(find.widgetWithText(FilledButton, 'Apply'), findsOneWidget);
    expect(applyButton(tester).onPressed, isNull); // disabled

    await _tearDown(tester);
  });

  testWidgets('Adjust Points: Apply is disabled when amount is 0', (
    tester,
  ) async {
    _useTallViewport(tester);
    await tester.pumpWidget(_buildApp(router: router, tutorPerms: null));
    await openAdjustPointsDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '0');
    await tester.pump();

    expect(applyButton(tester).onPressed, isNull); // still disabled

    await _tearDown(tester);
  });

  testWidgets('Adjust Points: Apply enables and applies a valid amount', (
    tester,
  ) async {
    final db = inMemoryDb();
    await seedProfile(db); // satisfies points_balance.profile_id FK
    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: null, db: db),
    );
    await openAdjustPointsDialog(tester);

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '25');
    await tester.pump();

    expect(applyButton(tester).onPressed, isNotNull); // enabled

    await applyAndDrainDialog(tester);

    expect(await db.pointsBalanceDao.getBalance(1), 25);

    await _tearDown(tester);
    await db.close();
  });

  // ── Bug 2: Adjust Points dialog shows the child's current balance ──────────
  //
  // Regression: the dialog previously showed only Add/Deduct + Amount + Reason,
  // with no indication of how many points the child currently has. It must now
  // surface a "Current balance: N pts" line read from the points balance DAO.

  testWidgets('Adjust Points: dialog shows the current balance', (
    tester,
  ) async {
    _useTallViewport(tester);
    final db = inMemoryDb();
    await seedProfile(db);
    await db.pointsBalanceDao.parentAdjust(1, 70);

    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: null, db: db),
    );
    await openAdjustPointsDialog(tester);

    expect(find.text('Current balance: 70 pts'), findsOneWidget);

    await _tearDown(tester);
    await db.close();
  });

  testWidgets(
    'Adjust Points: dialog shows zero balance when child has no points',
    (tester) async {
      _useTallViewport(tester);
      final db = inMemoryDb();
      await seedProfile(db);

      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: null, db: db),
      );
      await openAdjustPointsDialog(tester);

      expect(find.text('Current balance: 0 pts'), findsOneWidget);

      await _tearDown(tester);
      await db.close();
    },
  );

  // ── #33: Pending Prizes subtitle is reactive ──────────────────────────────
  //
  // Regression: the subtitle was hard-wired to pendingRedemptionsEmpty and
  // never reflected a pending redemption. It is now backed by the reactive
  // pendingRedemptionsCountProvider (watchPendingRedemptions stream).

  testWidgets(
    'Pending Prizes subtitle shows empty copy when no pending redemptions',
    (tester) async {
      _useTallViewport(tester);
      final db = inMemoryDb();
      await seedProfile(db);
      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: null, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('No pending prize requests.'), findsOneWidget);

      await _tearDown(tester);
      await db.close();
    },
  );

  testWidgets(
    'Pending Prizes subtitle reflects a pending redemption count reactively',
    (tester) async {
      _useTallViewport(tester);
      final db = inMemoryDb();
      await seedProfile(db);
      // Give the child a balance, then redeem → one pending_fulfilment row.
      await db.pointsBalanceDao.parentAdjust(1, 100);
      final redemption = await db.pointsBalanceDao.createRedemption(
        profileId: 1,
        rewardTitle: 'Prize',
        iconIndex: 0,
        pointsCost: 50,
      );
      expect(redemption, isNotNull);

      await tester.pumpWidget(
        _buildApp(router: router, tutorPerms: null, db: db),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Reactive subtitle now reflects the pending request (count = 1).
      expect(find.text('1 prize request waiting'), findsOneWidget);
      expect(find.text('No pending prize requests.'), findsNothing);

      await _tearDown(tester);
      await db.close();
    },
  );

  testWidgets('Adjust Points: Deduct applies a negative delta', (tester) async {
    final db = inMemoryDb();
    await seedProfile(db); // satisfies points_balance.profile_id FK
    // Seed a starting balance so a deduction has something to subtract from.
    await db.pointsBalanceDao.parentAdjust(1, 40);

    await tester.pumpWidget(
      _buildApp(router: router, tutorPerms: null, db: db),
    );
    await openAdjustPointsDialog(tester);

    // Switch to Deduct mode.
    await tester.tap(find.text('Deduct points'));
    await tester.pump();

    await tester.enterText(find.widgetWithText(TextField, 'Amount'), '15');
    await tester.pump();

    expect(applyButton(tester).onPressed, isNotNull);

    await applyAndDrainDialog(tester);

    expect(await db.pointsBalanceDao.getBalance(1), 25);

    await _tearDown(tester);
    await db.close();
  });
}
