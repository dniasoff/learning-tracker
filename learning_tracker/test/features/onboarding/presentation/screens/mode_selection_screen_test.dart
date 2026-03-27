import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/onboarding/domain/services/user_profile_service.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/onboarding/presentation/screens/mode_selection_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

void main() {
  late AppDatabase database;
  late MockFirebaseAuth mockAuth;
  late MockUser mockUser;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    mockAuth = MockFirebaseAuth();
    mockUser = MockUser();

    when(() => mockAuth.currentUser).thenReturn(mockUser);
    when(() => mockUser.uid).thenReturn('test-uid');
    when(() => mockUser.displayName).thenReturn('Test User');
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget() {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        firebaseAuthProvider.overrideWithValue(mockAuth),
        userProfileServiceProvider.overrideWith((ref) {
          return UserProfileService(
            userProfileDao: database.userProfileDao,
            pushUserProfile:
                ({
                  required String firebaseUid,
                  required String displayName,
                  required String userMode,
                }) async {},
          );
        }),
      ],
      child: const MaterialApp(home: ModeSelectionScreen()),
    );
  }

  group('ModeSelectionScreen Widget Tests', () {
    testWidgets('displays two mode options per V1 roadmap', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Add myself as a learner'), findsOneWidget);
      expect(find.text('Add a child'), findsOneWidget);
    });

    testWidgets('displays add-myself mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Track your personal learning, set goals, and celebrate milestones.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays add-child mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Set up learning for your child with rewards, progress tracking, and parental controls.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('does not display tutor option (V2)', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Tutor / Rebbi'), findsNothing);
    });

    testWidgets('Continue button disabled when no mode selected', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      final continueInkWell = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(InkWell),
        ),
      );
      expect(continueInkWell.onTap, isNull);
    });

    testWidgets('Continue button enabled after selecting a mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      await tester.tap(find.text('Add myself as a learner'));
      await tester.pump(const Duration(milliseconds: 500));

      final continueInkWell = tester.widget<InkWell>(
        find.ancestor(
          of: find.text('Continue'),
          matching: find.byType(InkWell),
        ),
      );
      expect(continueInkWell.onTap, isNotNull);
    });

    testWidgets('shows Skip button', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Skip for now'), findsOneWidget);
    });

    testWidgets('shows header prompt', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.textContaining("Let's get"), findsOneWidget);
    });
  });
}
