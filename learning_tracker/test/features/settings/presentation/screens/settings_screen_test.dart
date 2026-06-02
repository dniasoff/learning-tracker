import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/domain/repositories/auth_repository.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_providers.dart'
    show authRepositoryProvider;
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

/// Pins the active profile id to the talmid's synthetic local mirror (id 99).
class _MirrorActiveProfileId extends ActiveProfileId {
  @override
  int build() => 99;
}

/// A fixed non-null tutored selection → the screen treats this as a live tutor
/// session (full parent-equivalent permissions; only live-marking barred).
class _ActiveTutoredSelection extends ActiveTutoredProfileSelection {
  @override
  TutoredProfileSelection? build() => const TutoredProfileSelection(
    profileId: 'talmid-remote-id',
    ownerUid: 'owner-uid',
    grantId: 'grant-id',
    permissions: TutorPermissions(),
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    PackageInfo.setMockInitialValues(
      appName: 'Learning Tracker',
      packageName: 'learning_tracker',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  late UserDatabase database;
  late MockAuthRepository mockAuth;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
    mockAuth = MockAuthRepository();
    when(() => mockAuth.currentUser).thenReturn(null);
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget({
    List<CurriculumId> initialActive = const [],
    bool tutoredSession = false,
  }) {
    final talmidMirror = ProfileModel(
      id: 99,
      accountId: 1,
      displayName: 'Kid',
      mode: 'child',
      avatarIndex: 0,
      createdAt: DateTime(2024),
      updatedAt: DateTime(2024),
    );
    return FutureBuilder(
      future: Future(() async {
        for (final curriculum in initialActive) {
          await database.activeCurriculumDao.activate(curriculum);
        }
      }),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const MaterialApp(
            home: Scaffold(body: CircularProgressIndicator()),
          );
        }

        return ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
            userDatabaseProvider.overrideWithValue(database),
            authRepositoryProvider.overrideWithValue(mockAuth),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  profileId: 1,
                  email: 'test@test.com',
                  displayName: 'Test',
                ),
                tier: Tier.localBorn,
              ),
            ),
            curriculumActivationServiceProvider.overrideWith((ref) {
              return CurriculumActivationService(
                database: database,
                pushCurriculumTrack: (_) async {},
                trackRepository: TrackRepositoryImpl(database: database),
              );
            }),
            if (tutoredSession) ...[
              activeTutoredProfileSelectionProvider.overrideWith(
                _ActiveTutoredSelection.new,
              ),
              activeProfileIdProvider.overrideWith(_MirrorActiveProfileId.new),
              activeProfileProvider.overrideWith(
                (ref) => Future.value(talmidMirror),
              ),
              profileListStreamProvider.overrideWith(
                (ref) => Stream.value(<ProfileModel>[]),
              ),
            ],
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        );
      },
    );
  }

  Future<void> pumpUntilSettled(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('SettingsScreen Widget Tests', () {
    // WS4.settings (D2): Settings are grouped by scope (Device / Profile).
    // The old TRACKS/LEARNING feature-grouped headers are replaced.
    testWidgets(
      'renders Device and Profile scope section headers (WS4.settings)',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(initialActive: [CurriculumId.mishnayos]),
        );
        await pumpUntilSettled(tester);

        // DEVICE section (App Permissions) must be visible at top.
        expect(find.text('DEVICE'), findsOneWidget);
        // PROFILE section (per-learner settings) must be visible.
        expect(find.text('PROFILE'), findsOneWidget);
        // Old feature-based headers must be gone.
        expect(find.text('TRACKS'), findsNothing);
        expect(find.text('LEARNING'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    // WS4.login-sect (DEC-26): No empty Login scope group is rendered.
    // The Login section is omitted entirely (debug toggle not yet built).
    testWidgets('does not render an empty Login section (WS4.login-sect)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      // Scroll to make sure the full list is inspectable.
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // No "LOGIN" section heading must appear anywhere in the list.
      expect(find.text('LOGIN'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders Manage Tracks tile', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActive: [CurriculumId.mishnayos, CurriculumId.bavli],
        ),
      );
      await pumpUntilSettled(tester);

      // DEC-26: the Sacred Time card now sits under the DEVICE section, so the
      // Manage Tracks tile renders lower in the lazy ListView — scroll to it.
      await tester.scrollUntilVisible(
        find.text('Manage Tracks'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Manage Tracks'), findsOneWidget);
      expect(find.text('Create and edit your learning tracks'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders learning section tiles', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      await tester.scrollUntilVisible(
        find.text('Manage Tracks'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Manage Tracks'), findsOneWidget);
      expect(find.text('Calendar Preference'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets('renders Notification Settings tile', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -700));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Notification Settings'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'account actions are NOT in the Settings body (moved to header sheet)',
      (tester) async {
        // Account/profile separation: ACCOUNT actions (Sign Out, Delete
        // account, Change password, Add account) live ONLY in the account
        // sheet opened from the profile header card — never duplicated in the
        // Settings body. Scrolling the whole list must not reveal them.
        await tester.pumpWidget(
          createTestWidget(initialActive: [CurriculumId.mishnayos]),
        );
        await pumpUntilSettled(tester);

        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pumpAndSettle();

        expect(find.text('ACCOUNT'), findsNothing);
        expect(find.text('Sign Out'), findsNothing);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets('displays app version when scrolled to bottom', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      // Scroll far enough to reveal the version widget at the bottom of the
      // list (after ACCOUNT section and all other content).
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(find.text('v1.0.0 (1)'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });

  group('Tutored (talmid) session — scope filtering', () {
    // Bug 12: a tutored session shows ONLY student/profile-scope items and
    // hides everything tied to the tutor's own account/device.
    testWidgets('hides the DEVICE section (App Permissions / Sacred Time)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActive: [CurriculumId.mishnayos],
          tutoredSession: true,
        ),
      );
      await pumpUntilSettled(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      // The whole DEVICE section — the tutor's own device/account scope — is
      // gone: no section header, no App Permissions tile.
      expect(find.text('DEVICE'), findsNothing);
      expect(find.text('App Permissions'), findsNothing);
      // The diagnostic-logs tile (tutor's own account/device) is hidden too.
      expect(find.text('Send Diagnostic Logs'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

    // Bug 10: a tutor has full parent-equivalent powers — the management hub
    // entry must advertise the broader scope (tracks, points, rewards, goals),
    // not tracks only, and route into the parent-management hub.
    testWidgets(
      'shows the parent-management hub with the broad-scope subtitle',
      (tester) async {
        await tester.pumpWidget(
          createTestWidget(
            initialActive: [CurriculumId.mishnayos],
            tutoredSession: true,
          ),
        );
        await pumpUntilSettled(tester);

        await tester.scrollUntilVisible(
          find.text('Parent Settings'),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Parent Settings'), findsOneWidget);
        // Broadened subtitle (not the tracks-only one).
        expect(
          find.text('Manage tracks, points, rewards, and goals'),
          findsOneWidget,
        );
        expect(
          find.text("Add, edit, or archive your child's tracks"),
          findsNothing,
        );

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(Duration.zero);
      },
    );
  });
}
