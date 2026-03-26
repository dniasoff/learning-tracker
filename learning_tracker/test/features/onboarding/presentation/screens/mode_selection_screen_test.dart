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
    testWidgets('displays three mode options', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.text('Self-Learner'), findsOneWidget);
      expect(find.text('Parent'), findsOneWidget);
      expect(find.text('Tutor / Rebbi'), findsOneWidget);
    });

    testWidgets('displays self-learner mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Personal progress tracking, Siyum reminders, and daily goals.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays parent mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Reward management for children, progress reports, and family leaderboards.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('displays tutor mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.text(
          'Student management, class-wide assignments, and individual tracking.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Continue button disabled when no mode selected', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      // The continue button is an InkWell inside an AnimatedContainer.
      // When disabled, its onTap is null.
      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNull);
    });

    testWidgets('Continue button enabled after selecting a mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      // Tap Self-Learner mode
      await tester.tap(find.text('Self-Learner'));
      await tester.pump(const Duration(milliseconds: 500));

      final inkWell = tester.widget<InkWell>(find.byType(InkWell));
      expect(inkWell.onTap, isNotNull);
    });

    testWidgets('shows terms text', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(
        find.textContaining('By continuing, you agree to our terms'),
        findsOneWidget,
      );
    });

    testWidgets('shows question prompt', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pump(const Duration(milliseconds: 1500));

      expect(find.textContaining('Who are you'), findsOneWidget);
    });
  });
}
