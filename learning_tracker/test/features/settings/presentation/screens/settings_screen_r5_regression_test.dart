// Regression tests for Round-5 bug-hunt findings R5-2, R5-7, R5-8, R5-9:
//
//   R5-7  'TALMID PROFILES' hardcoded → profilePickerTalmidProfiles
//   R5-8  'Pending — tap to accept' / 'Tutoring' hardcoded → statusPending /
//         tutoredChildrenStatusTutoring
//   R5-9  'Accept' hardcoded → acceptInviteAccept
//   R5-2  'Parent PIN' tile visible to child without parent-mode auth → hidden
//         until parentPinAuthenticatedProfileId matches activeProfileId
//
// Strategy:
//   L10N (R5-7/8/9): pump SettingsScreen under Hebrew locale with a non-empty
//   pending/active tutor grant; assert Hebrew strings appear and the old
//   English literals are absent.
//
//   PIN gate (R5-2): pump SettingsScreen for a child profile with
//   parentPinAuthenticatedProfileId = null (unauthenticated) and assert
//   the tile is hidden; then with it set to the active profile ID and assert
//   the tile is visible.

@Tags(['settings', 'l10n', 'regression', 'pin_gate'])
library;

import 'package:auto_route/auto_route.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/services/pin_service.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
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

// ─── Mocks / fakes ───────────────────────────────────────────────────────────

class _MockAuthRepository extends Mock implements AuthRepository {}

class _MockStackRouter extends Mock implements StackRouter {}

class _FakePageRouteInfo extends Fake implements PageRouteInfo {}

class _MockPinService extends Mock implements PinService {}

// ─── Notifier stubs ───────────────────────────────────────────────────────────

class _NoTutorSession extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => null;
}

class _NoPinAuth extends ParentPinAuthenticatedProfileId {
  @override
  int? build() => null;
}

class _PinAuthedForProfile extends ParentPinAuthenticatedProfileId {
  _PinAuthedForProfile(this._id);
  final int _id;

  @override
  int? build() => _id;
}

// ─── Test helpers ─────────────────────────────────────────────────────────────

ProfileModel _childProfile({int id = 2}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: 1,
    displayName: 'Child',
    mode: 'child',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

ProfileModel _adultProfile({int id = 1}) {
  final now = DateTime.utc(2026, 1, 1);
  return ProfileModel(
    id: id,
    accountId: 1,
    displayName: 'Adult',
    mode: 'adult',
    avatarIndex: 0,
    createdAt: now,
    updatedAt: now,
  );
}

TutorGrant _pendingGrant({String childName = 'Yosef'}) {
  final now = DateTime.utc(2026, 1, 1);
  return TutorGrant(
    doc: TutorGrantDoc(
      grantId: 'grant_pending_1',
      parentUid: 'parent_uid',
      childProfileId: '2',
      tutorEmail: 'tutor@test.com',
      state: TutorGrantState.pending,
      invitedAt: now,
      updatedAt: now,
      expiresAt: now.add(const Duration(days: 7)),
      childName: childName,
    ),
    grantState: PendingGrant(expiresAt: now.add(const Duration(days: 7))),
  );
}

TutorGrant _activeGrant({String childName = 'Avigail'}) {
  final now = DateTime.utc(2026, 1, 1);
  return TutorGrant(
    doc: TutorGrantDoc(
      grantId: 'grant_active_1',
      parentUid: 'parent_uid',
      childProfileId: '3',
      tutorEmail: 'tutor@test.com',
      state: TutorGrantState.active,
      invitedAt: now,
      updatedAt: now,
      acceptedAt: now,
      childName: childName,
    ),
    grantState: ActiveGrant(
      acceptedAt: now,
      permissions: TutorPermissions.defaults(),
    ),
  );
}

Future<UserDatabase> _dbWithProfile({required String mode}) async {
  final db = UserDatabase(NativeDatabase.memory());
  await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@test.com',
          tier: 'localBorn',
          displayName: 'Test',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: 1,
          displayName: mode == 'child' ? 'Child' : 'Adult',
          mode: mode,
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  return db;
}

Widget _buildSettings({
  required UserDatabase db,
  required _MockAuthRepository auth,
  required _MockStackRouter router,
  required ProfileModel profile,
  required _MockPinService pinService,
  Locale locale = const Locale('en'),
  List<TutorGrant> pendingGrants = const [],
  List<TutorGrant> activeGrants = const [],
  bool pinAuthForProfile = false,
  int profileId = 1,
}) {
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
            displayName: 'Test',
          ),
          tier: Tier.localBorn,
        ),
      ),
      activeProfileIdProvider.overrideWithValue(profileId),
      profileListStreamProvider.overrideWith((ref) => Stream.value([profile])),
      selectedProfileIdProvider.overrideWithValue(profileId),
      activeTutoredProfileSelectionProvider.overrideWith(_NoTutorSession.new),
      activeTutorPermissionsProvider.overrideWithValue(null),
      incomingTutorGrantsProvider.overrideWith(
        (ref) => Future.value(activeGrants),
      ),
      pendingTutorInvitesProvider.overrideWith(
        (ref) => Future.value(pendingGrants),
      ),
      parentPinAuthenticatedProfileIdProvider.overrideWith(
        pinAuthForProfile
            ? () => _PinAuthedForProfile(profileId)
            : _NoPinAuth.new,
      ),
      pinServiceProvider.overrideWithValue(pinService),
      syncWriteFacadeProvider.overrideWithValue(null),
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
  late _MockPinService pinService;

  setUp(() {
    router = _MockStackRouter();
    auth = _MockAuthRepository();
    pinService = _MockPinService();
    when(() => auth.currentUser).thenReturn(null);
    when(
      () => router.push<Object?>(
        any<PageRouteInfo>(),
        onFailure: any(named: 'onFailure'),
      ),
    ).thenAnswer((_) => Future<Object?>.value(null));
    when(() => router.canPop()).thenReturn(false);
    when(() => router.currentPath).thenReturn('/settings');
    // hasProfilePin returns false by default (no PIN set).
    when(() => pinService.hasProfilePin(any())).thenAnswer((_) async => false);
  });

  // ════════════════════════════════════════════════════════════════════════════
  // R5-7 / R5-8 / R5-9 — l10n: Hebrew strings in tutor-grant section
  // ════════════════════════════════════════════════════════════════════════════

  group('R5-7 TALMID PROFILES — l10n', () {
    // Hebrew locale: section header must read 'פרופילי תלמידים' (the l10n
    // value of profilePickerTalmidProfiles), NOT the old hardcoded English.
    testWidgets(
      'Hebrew locale: shows Hebrew section header, not hardcoded English',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
            locale: const Locale('he'),
            pendingGrants: [_pendingGrant()],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Hebrew label must appear.
        expect(
          find.text('פרופילי תלמידים'),
          findsOneWidget,
          reason:
              'R5-7: profilePickerTalmidProfiles must render in Hebrew locale',
        );
        // Old hardcoded English must not appear.
        expect(
          find.text('TALMID PROFILES'),
          findsNothing,
          reason: 'R5-7: hardcoded English TALMID PROFILES must be absent',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // English locale baseline: section header reads the English l10n value
    // (the ARB value for profilePickerTalmidProfiles is 'TALMID PROFILES', so
    // the text is the same — but it now comes from l10n, not a literal).
    testWidgets(
      'English locale: section header rendered via l10n (no regression)',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
            pendingGrants: [_pendingGrant()],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('TALMID PROFILES'), findsOneWidget);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('R5-8 status labels — l10n', () {
    // Hebrew + pending grant: status label should be Hebrew 'ממתין', not
    // English 'Pending — tap to accept'.
    testWidgets(
      'Hebrew locale + pending grant: shows Hebrew pending status, not English',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
            locale: const Locale('he'),
            pendingGrants: [_pendingGrant()],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.textContaining('ממתין'),
          findsOneWidget,
          reason:
              'R5-8: statusPendingTapToAccept ("ממתין — הקישו לאישור") must '
              'render in Hebrew for pending grants',
        );
        expect(
          find.textContaining('Pending'),
          findsNothing,
          reason:
              'R5-8: hardcoded English "Pending..." must be absent in Hebrew locale',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // Hebrew + active grant: status label should be Hebrew 'מדריך', not
    // English 'Tutoring'.
    testWidgets(
      'Hebrew locale + active grant: shows Hebrew tutoring status, not English',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
            locale: const Locale('he'),
            activeGrants: [_activeGrant()],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('מדריך'),
          findsOneWidget,
          reason:
              'R5-8: tutoredChildrenStatusTutoring must render in Hebrew for '
              'active grants',
        );
        expect(
          find.text('Tutoring'),
          findsNothing,
          reason:
              'R5-8: hardcoded English "Tutoring" must be absent in Hebrew locale',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('R5-9 Accept button — l10n', () {
    // Hebrew locale + pending grant: button label should be Hebrew 'אישור הזמנה',
    // not English 'Accept'.
    testWidgets(
      'Hebrew locale + pending grant: Accept button shows Hebrew label',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
            locale: const Locale('he'),
            pendingGrants: [_pendingGrant()],
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('אישור הזמנה'),
          findsOneWidget,
          reason:
              'R5-9: acceptInviteAccept must render in Hebrew on the Accept button',
        );
        expect(
          find.text('Accept'),
          findsNothing,
          reason:
              'R5-9: hardcoded English "Accept" must be absent in Hebrew locale',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });

  // ════════════════════════════════════════════════════════════════════════════
  // R5-2 — PIN tile gate: hidden for child without parent-mode auth
  // ════════════════════════════════════════════════════════════════════════════

  group('R5-2 Parent PIN tile — gate on parent-mode auth', () {
    // Child profile, no PIN auth → PIN tile must be HIDDEN (R5-2 fix).
    testWidgets(
      'child profile (no parent-mode auth): Parent PIN tile is hidden',
      (tester) async {
        final db = await _dbWithProfile(mode: 'child');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _childProfile(),
            pinService: pinService,
            profileId: 2,
            pinAuthForProfile: false,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        // Scroll to the bottom to ensure the full list is visible.
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(
          find.text('Parent PIN'),
          findsNothing,
          reason:
              'R5-2: "Parent PIN" tile must not appear for a child profile '
              'without parent-mode authentication',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // Child profile, parent-mode authenticated → PIN tile must be VISIBLE.
    testWidgets(
      'child profile (parent-mode authenticated): Parent PIN tile is visible',
      (tester) async {
        final db = await _dbWithProfile(mode: 'child');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _childProfile(),
            pinService: pinService,
            profileId: 2,
            pinAuthForProfile: true,
          ),
        );
        // Allow the async _load() in _ParentalControlsSection to complete.
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        await tester.pump(const Duration(seconds: 1));

        // Scroll far down to ensure the Parental Controls section is in view.
        await tester.drag(find.byType(ListView), const Offset(0, -3000));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          find.text('Parent PIN'),
          findsOneWidget,
          reason:
              'R5-2: "Parent PIN" tile must appear when parent-mode is '
              'authenticated for the active child profile',
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // Adult profile → Parental Controls section is hidden entirely (no change
    // from before, confirms the gate does not break adult flow).
    testWidgets(
      'adult profile: Parental Controls section (including PIN tile) is absent',
      (tester) async {
        final db = await _dbWithProfile(mode: 'adult');
        addTearDown(db.close);

        await tester.pumpWidget(
          _buildSettings(
            db: db,
            auth: auth,
            router: router,
            profile: _adultProfile(),
            pinService: pinService,
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('PARENTAL CONTROLS'), findsNothing);
        expect(find.text('Parent PIN'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
