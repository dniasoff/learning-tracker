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
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/features/tracks/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

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

  Widget createTestWidget({List<CurriculumId> initialActive = const []}) {
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
    testWidgets('renders Device and Profile scope section headers (WS4.settings)', (tester) async {
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
    });

    // WS4.login-sect (DEC-26): No empty Login scope group is rendered.
    // The Login section is omitted entirely (debug toggle not yet built).
    testWidgets('does not render an empty Login section (WS4.login-sect)', (tester) async {
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

    testWidgets('renders lower sections when scrolled', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      await tester.drag(find.byType(ListView), const Offset(0, -1300));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });

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
}
