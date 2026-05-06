import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/auth/domain/models/auth_state.dart';
import 'package:learning_tracker/features/auth/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:learning_tracker/l10n/app_localizations.dart';
import 'package:mocktail/mocktail.dart';
import 'package:package_info_plus/package_info_plus.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

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
  late MockFirebaseAuth mockAuth;

  setUp(() {
    database = UserDatabase(NativeDatabase.memory());
    mockAuth = MockFirebaseAuth();
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
            firebaseAuthProvider.overrideWithValue(mockAuth),
            authStateProvider.overrideWithValue(
              const AuthState.signedIn(
                user: AuthUser(
                  profileId: 1,
                  email: 'test@test.com',
                  displayName: 'Test',
                  userMode: 'adult',
                ),
                tier: Tier.localBorn,
              ),
            ),
            curriculumActivationServiceProvider.overrideWith((ref) {
              return CurriculumActivationService(
                database: database,
                pushActiveCurricula: (_) async {},
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
    testWidgets('renders top section headers', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      expect(find.text('TRACKS'), findsOneWidget);
      expect(find.text('LEARNING'), findsOneWidget);

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

      await tester.drag(find.byType(ListView), const Offset(0, -200));
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

      await tester.drag(find.byType(ListView), const Offset(0, -800));
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

      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump();

      expect(find.text('v1.0.0'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    });
  });
}
