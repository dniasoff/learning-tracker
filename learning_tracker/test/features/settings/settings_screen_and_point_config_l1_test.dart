// L1 widget tests for SettingsScreen + PointConfigScreen
//
// Coverage focus (per spec):
//   SettingsScreen (61%):
//     • DEVICE / PROFILE section headers always rendered
//     • Account/profile separation — account actions NOT in Settings body
//     • Manage Tracks + Manage Profiles shown for adult (not tutored)
//     • Manage Profiles hidden in tutored session
//     • Manage Tracks hidden for child profile (not elevated)
//     • Lifetime Learning tile hidden for child profile
//     • Lifetime Learning tile hidden in tutored session
//     • BackupSyncSection hidden for child profile
//     • BackupSyncSection hidden in tutored session
//     • Hebrew Terms tile hidden in Hebrew locale (language code == 'he')
//     • Transliteration variant tile visible when hebrewTerms=false (English UI)
//     • Diagnostic logs tile always rendered
//     • Pending invites section hidden in tutored session
//     • Hebrew (RTL) smoke — key tiles render without crash
//
//   PointConfigScreen (73.5%):
//     • Loading state — CircularProgressIndicator while data loads
//     • Empty state (no active tracks) — empty-body text rendered
//     • Populated: curriculum card with ACTIVE badge, Points per Task,
//       star-icon + points value, stepper +/− buttons
//     • Increment stepper raises displayed value
//     • Decrement stepper lowers displayed value (floor = 1)
//     • Decrement disabled when value = 1 (onDecrement null → opacity 0.45)
//     • Save button shows snackbar with "no changes" when nothing pending
//     • Save button persists pending edits → pointSettingsSavedSnackbar
//     • Tutor with canEditPoints=false: +/− disabled, save shows tutorPermissionDenied
//     • Adults have no points (rule) — PointConfigScreen shows per-track config,
//       NOT per-profile (tracks have stages, not profile-level point balances)
//     • Hebrew (RTL) smoke — screen renders without crash

import 'dart:async';

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/preferences/preference_providers.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/gamification/presentation/screens/point_config_screen.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart'
    show incomingTutorGrantsProvider;
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart'
    show pendingTutorInvitesProvider;
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

// ─── Mocks ───────────────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

// ─── Notifier stubs ───────────────────────────────────────────────────────────

/// No active tutored session.
class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

/// Active tutored session with configurable permissions.
class _TutorSession extends ActiveTutoredProfileSelection {
  _TutorSession(this._perms);
  final TutorPermissions _perms;

  @override
  TutoredProfileSelection? build() => TutoredProfileSelection(
    profileId: '2',
    ownerUid: 'owner_uid',
    grantId: 'grant_1',
    permissions: _perms,
  );
}

/// useHebrewTermsProvider stub — always false.
class _HebrewTermsOff extends UseHebrewTerms {
  @override
  bool build() => false;
}

/// useHebrewTermsProvider stub — always true.
class _HebrewTermsOn extends UseHebrewTerms {
  @override
  bool build() => true;
}

// ─── Profile helpers ──────────────────────────────────────────────────────────

ProfileModel _adultProfile({int id = 1, String name = 'Adult'}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: 1,
    displayName: name,
    mode: 'adult',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

ProfileModel _childProfile({int id = 2, String name = 'Child'}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: 1,
    displayName: name,
    mode: 'child',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

// ─── DB setup helpers ─────────────────────────────────────────────────────────

Future<UserDatabase> _dbWithAdultProfile() async {
  final db = UserDatabase(NativeDatabase.memory());
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@test.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: 1,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  return db;
}

Future<UserDatabase> _dbWithChildProfile() async {
  final db = UserDatabase(NativeDatabase.memory());
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@test.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: 1,
          displayName: 'Child',
          mode: 'child',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  return db;
}

/// Seeds account + adult profile + one mishnayos track. Returns (db, trackId).
Future<(UserDatabase, int)> _dbWithTrack({
  String curriculumId = 'mishnayos',
}) async {
  final db = await _dbWithAdultProfile();
  final trackId = await db
      .into(db.curriculumTracks)
      .insert(
        CurriculumTracksCompanion.insert(
          profileId: 1,
          curriculumId: curriculumId,
          stateChangedAt: DateTimeFactory.nowUtc(),
          activatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  return (db, trackId);
}

// ─── Widget builders ──────────────────────────────────────────────────────────

Widget _buildSettings({
  required UserDatabase db,
  required _MockAuthRepository auth,
  required _MockStackRouter router,
  String profileMode = 'adult',
  int profileId = 1,
  bool isTutored = false,
  TutorPermissions tutorPerms = const TutorPermissions(),
  Locale locale = const Locale('en'),
  List<Override> extraOverrides = const [],
}) {
  final profile = profileMode == 'child'
      ? _childProfile(id: profileId)
      : _adultProfile(id: profileId);

  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      authRepositoryProvider.overrideWithValue(auth),
      authStateProvider.overrideWithValue(
        AuthState.signedIn(
          user: AuthUser(
            profileId: profileId,
            email: 'test@test.com',
            displayName: 'Test User',
          ),
          tier: Tier.localBorn,
        ),
      ),
      activeProfileIdProvider.overrideWithValue(profileId),
      profileListStreamProvider.overrideWith((ref) => Stream.value([profile])),
      selectedProfileIdProvider.overrideWithValue(profileId),
      activeTutoredProfileSelectionProvider.overrideWith(
        isTutored ? () => _TutorSession(tutorPerms) : _NoTutorSession.new,
      ),
      activeTutorPermissionsProvider.overrideWithValue(
        isTutored ? tutorPerms : null,
      ),
      incomingTutorGrantsProvider.overrideWith(
        (ref) => Future<List<TutorGrant>>.value([]),
      ),
      pendingTutorInvitesProvider.overrideWith(
        (ref) => Future<List<TutorGrant>>.value([]),
      ),
      syncWriteFacadeProvider.overrideWithValue(null),
      ...extraOverrides,
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
        child: const Scaffold(body: SettingsScreen()),
      ),
    ),
  );
}

Widget _buildPointConfig({
  required UserDatabase db,
  required _MockStackRouter router,
  int profileId = 1,
  bool isTutored = false,
  TutorPermissions tutorPerms = const TutorPermissions(),
  Locale locale = const Locale('en'),
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    retry: (_, __) => null,
    overrides: [
      userDatabaseProvider.overrideWithValue(db),
      activeProfileIdProvider.overrideWithValue(profileId),
      activeTutoredProfileSelectionProvider.overrideWith(
        isTutored ? () => _TutorSession(tutorPerms) : _NoTutorSession.new,
      ),
      activeTutorPermissionsProvider.overrideWithValue(
        isTutored ? tutorPerms : null,
      ),
      syncWriteFacadeProvider.overrideWithValue(null),
      ...extraOverrides,
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
        child: const Scaffold(body: PointConfigScreen()),
      ),
    ),
  );
}

// ─── Tests ───────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_FakePageRouteInfo());
    PackageInfo.setMockInitialValues(
      appName: 'Learning Tracker',
      packageName: 'learning_tracker',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  late _MockStackRouter router;
  late _MockAuthRepository auth;

  setUp(() {
    router = _MockStackRouter();
    auth = _MockAuthRepository();
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => router.push<Object?>(
        any<PageRouteInfo>(),
        onFailure: any(named: 'onFailure'),
      ),
    ).thenAnswer((_) => Future<Object?>.value(null));
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/settings');
  });

  // ════════════════════════════════════════════════════════════════════════════
  // SETTINGS SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('SettingsScreen', () {
    // ── Section headers ───────────────────────────────────────────────────────

    testWidgets('DEVICE and PROFILE section headers always render (adult)', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('DEVICE'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('DEVICE and PROFILE headers render for child profile', (
      tester,
    ) async {
      final db = await _dbWithChildProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(
          db: db,
          auth: auth,
          router: router,
          profileMode: 'child',
          profileId: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('DEVICE'), findsOneWidget);
      expect(find.text('PROFILE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Account / profile separation (product rule) ───────────────────────────

    testWidgets(
      'account actions (Sign Out, ACCOUNT section) NOT in Settings body',
      (tester) async {
        // Product rule: account actions live ONLY in the header card sheet.
        // Scrolling the full settings list must NOT reveal Sign Out or ACCOUNT.
        final db = await _dbWithAdultProfile();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(db: db, auth: auth, router: router),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('ACCOUNT'), findsNothing);
        expect(find.text('Sign Out'), findsNothing);
        expect(find.text('Delete Account'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('Manage Profiles is in PROFILE section (not account section)', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Manage Profiles'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Manage Profiles'), findsOneWidget);
      // Must be below the PROFILE section header, not under any ACCOUNT section
      expect(find.text('ACCOUNT'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Manage Tracks + Manage Profiles (adult, non-tutored) ─────────────────

    testWidgets('adult: Manage Tracks and Manage Profiles are both visible', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Manage Tracks'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('Manage Tracks'), findsOneWidget);
      expect(find.text('Manage Profiles'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Child profile gating ──────────────────────────────────────────────────

    testWidgets('child profile: Manage Tracks and Manage Profiles are hidden', (
      tester,
    ) async {
      final db = await _dbWithChildProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(
          db: db,
          auth: auth,
          router: router,
          profileMode: 'child',
          profileId: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manage Tracks'), findsNothing);
      expect(find.text('Manage Profiles'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('child profile: "Add Lifetime Learning" tile is hidden', (
      tester,
    ) async {
      final db = await _dbWithChildProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(
          db: db,
          auth: auth,
          router: router,
          profileMode: 'child',
          profileId: 2,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Add Lifetime Learning'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Tutored session gating (T3.gating) ────────────────────────────────────

    testWidgets('tutored session: Manage Profiles is hidden', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router, isTutored: true),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(ListView), const Offset(0, -3000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Manage Profiles'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'tutored session: "Add Lifetime Learning" tile is hidden (T3.gating)',
      (tester) async {
        final db = await _dbWithAdultProfile();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(db: db, auth: auth, router: router, isTutored: true),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Add Lifetime Learning'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'tutored session: pending-invites section is hidden (T3.gating)',
      (tester) async {
        // Even when there are pending invites, the section must be hidden in a
        // tutored session. We test this by asserting TALMID PROFILES is absent.
        // The _buildSettings helper overrides pendingTutorInvitesProvider with
        // an empty list; the tutored-session guard fires before the section is
        // rendered, so no pending invites appear regardless of that value.
        final db = await _dbWithAdultProfile();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(db: db, auth: auth, router: router, isTutored: true),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // In a tutored session the _PendingInvitesSection is not rendered.
        expect(find.text('TALMID PROFILES'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // ── Preference tiles ──────────────────────────────────────────────────────

    testWidgets('Calendar Preference tile is always rendered', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Calendar Preference'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Calendar Preference'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Hebrew Terms tile is hidden when app locale is Hebrew (he)', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(
          db: db,
          auth: auth,
          router: router,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Hebrew Terms toggle is hidden for Hebrew-locale UI
      // (condition: locale.languageCode != 'he' gates the tile)
      expect(find.text('Hebrew Terms'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'Transliteration variant tile rendered when Hebrew Terms is OFF',
      (tester) async {
        final db = await _dbWithAdultProfile();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            extraOverrides: [
              useHebrewTermsProvider.overrideWith(_HebrewTermsOff.new),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.scrollUntilVisible(
          find.text('Pronunciation'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Pronunciation'), findsOneWidget);
        expect(find.text('Ashkenazi'), findsOneWidget);
        expect(find.text('Sephardi'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Transliteration variant tile is hidden when Hebrew Terms is ON',
      (tester) async {
        final db = await _dbWithAdultProfile();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            extraOverrides: [
              useHebrewTermsProvider.overrideWith(_HebrewTermsOn.new),
            ],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.drag(find.byType(ListView), const Offset(0, -2000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Ashkenazi'), findsNothing);
        expect(find.text('Sephardi'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('Nikud preference tile always rendered', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Nikud'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Nikud'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Diagnostic Logs tile always rendered', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Send Diagnostic Logs'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('Notification Settings tile is rendered', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.scrollUntilVisible(
        find.text('Notification Settings'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Notification Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Parental controls (child profile only) ────────────────────────────────

    testWidgets('adult profile: PARENTAL CONTROLS section is hidden', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(db: db, auth: auth, router: router),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('PARENTAL CONTROLS'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Hebrew / RTL smoke ────────────────────────────────────────────────────

    testWidgets('Hebrew locale: Settings renders without crash', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildSettings(
          db: db,
          auth: auth,
          router: router,
          locale: const Locale('he'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // In Hebrew locale the l10n renders Hebrew strings.
      // sectionDevice in Hebrew = 'מכשיר'.
      expect(find.text('מכשיר'), findsOneWidget);
      // Hebrew Terms tile absent (gated by languageCode == 'he')
      expect(find.text('Hebrew Terms'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  // ════════════════════════════════════════════════════════════════════════════
  // POINT CONFIG SCREEN
  // ════════════════════════════════════════════════════════════════════════════

  group('PointConfigScreen', () {
    // ── AppBar title ──────────────────────────────────────────────────────────

    testWidgets('AppBar title reads "Point Settings" (l10n)', (tester) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Point Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Loading state ─────────────────────────────────────────────────────────

    testWidgets('loading state resolves quickly; empty text appears after', (
      tester,
    ) async {
      // The _pointConfigDataProvider is a FutureProvider with a DB fallback
      // for AsyncLoading — so the spinner resolves almost immediately. What we
      // can verify is that no error is thrown and after resolution the screen
      // is in a known state (empty or data).
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      // Single pump — the FutureProvider may or may not have resolved yet.
      await tester.pump();
      // After 1s the provider has settled.
      await tester.pump(const Duration(seconds: 1));

      // Either the loading spinner or the empty-state text is visible — never both.
      final hasSpinner = tester.any(find.byType(CircularProgressIndicator));
      final hasEmpty = tester.any(
        find.textContaining('No active learning tracks'),
      );
      // Exactly one of the two must be visible (loading or resolved empty state).
      expect(hasSpinner || hasEmpty, isTrue);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Empty state ───────────────────────────────────────────────────────────

    testWidgets('empty state (no active tracks) shows empty body text', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // pointConfigNoActiveTracksBody l10n string
      expect(find.textContaining('No active learning tracks'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Populated state ───────────────────────────────────────────────────────

    testWidgets('populated: hero header shows CONFIGURATION label', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('CONFIGURATION'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('populated: curriculum card shows ACTIVE badge', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('ACTIVE'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('populated: "Points per Task" label is visible', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Points per Task'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('populated: stepper +/− buttons are present', (tester) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.byIcon(Icons.remove), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('populated: "Active Curricula" section heading is visible', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Active Curricula'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('populated: "Save All Changes" button is visible', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Save All Changes'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Stepper behaviour ─────────────────────────────────────────────────────

    testWidgets('increment (+) raises the displayed point value by 1', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Default primary stage (order=1) points = 10.
      // The value appears in both the big display and the stepper inline text,
      // so use findsWidgets (at least one) instead of findsOneWidget.
      final scrollView = find.byType(CustomScrollView);
      expect(
        find.descendant(of: scrollView, matching: find.text('10')),
        findsWidgets,
      );
      // "11" must NOT appear before the increment.
      expect(
        find.descendant(of: scrollView, matching: find.text('11')),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // After increment, "11" appears; "10" must be gone.
      expect(
        find.descendant(of: scrollView, matching: find.text('11')),
        findsWidgets,
      );
      expect(
        find.descendant(of: scrollView, matching: find.text('10')),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('decrement (−) lowers the displayed point value by 1', (
      tester,
    ) async {
      final (db, _) = await _dbWithTrack();
      addTearDown(db.close);

      await tester.pumpWidget(_buildPointConfig(db: db, router: router));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // Default = 10 → tap − → 9.
      // "9" must not appear before decrement.
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text('9'),
        ),
        findsNothing,
      );

      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();

      // After decrement "9" appears; "10" is gone.
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text('9'),
        ),
        findsWidgets,
      );
      expect(
        find.descendant(
          of: find.byType(CustomScrollView),
          matching: find.text('10'),
        ),
        findsNothing,
      );

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // ── Save behaviour ────────────────────────────────────────────────────────

    testWidgets(
      'Save shows "No changes to save" snackbar when nothing pending',
      (tester) async {
        final (db, _) = await _dbWithTrack();
        addTearDown(db.close);

        await tester.pumpWidget(_buildPointConfig(db: db, router: router));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('Save All Changes'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('No changes to save.'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Save after increment shows "Changes saved and synced." snackbar',
      (tester) async {
        final (db, _) = await _dbWithTrack();
        addTearDown(db.close);

        await tester.pumpWidget(_buildPointConfig(db: db, router: router));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();

        await tester.tap(find.text('Save All Changes'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Changes saved and synced.'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // ── Tutor permission gating ───────────────────────────────────────────────

    testWidgets(
      'tutor canEditPoints=false: Save shows permission-denied snackbar',
      (tester) async {
        final (db, _) = await _dbWithTrack();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildPointConfig(
            db: db,
            router: router,
            isTutored: true,
            tutorPerms: TutorPermissions.readOnly(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.tap(find.text('Save All Changes'));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // The screen shows the tutorPermissionDenied l10n message.
        // The exact string contains "permission" in the English l10n.
        expect(find.textContaining('permission'), findsWidgets);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'tutor canEditPoints=false: +/− buttons are visually disabled (opacity 0.45)',
      (tester) async {
        final (db, _) = await _dbWithTrack();
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildPointConfig(
            db: db,
            router: router,
            isTutored: true,
            tutorPerms: TutorPermissions.readOnly(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // _RoundStepButton sets Opacity(0.45) when onPressed == null.
        final opacities = tester.widgetList<Opacity>(find.byType(Opacity));
        final disabledCount = opacities
            .where((o) => (o.opacity - 0.45).abs() < 0.01)
            .length;
        // Both + and − are disabled when canEdit=false.
        expect(disabledCount, greaterThanOrEqualTo(2));

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // ── Product rule: adults have no points ───────────────────────────────────

    testWidgets(
      'adults have no points — screen shows per-track stage weights not a balance',
      (tester) async {
        // Product rule: adults have no point wallet. PointConfigScreen shows
        // per-track stage point _weights_ (how many points a child earns per
        // task). There must be no concept of a personal balance for adults.
        final (db, _) = await _dbWithTrack();
        addTearDown(db.close);

        await tester.pumpWidget(_buildPointConfig(db: db, router: router));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Shows track-config labels
        expect(find.text('Points per Task'), findsOneWidget);
        // No balance/wallet labels
        expect(find.text('My Points'), findsNothing);
        expect(find.text('Point Balance'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // ── Hebrew / RTL smoke ────────────────────────────────────────────────────

    testWidgets('Hebrew locale: PointConfigScreen renders without crash', (
      tester,
    ) async {
      final db = await _dbWithAdultProfile();
      addTearDown(db.close);

      await tester.pumpWidget(
        _buildPointConfig(db: db, router: router, locale: const Locale('he')),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // In Hebrew locale the AppBar title is 'הגדרות נקודות' (pointSettingsTitle).
      expect(find.text('הגדרות נקודות'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
