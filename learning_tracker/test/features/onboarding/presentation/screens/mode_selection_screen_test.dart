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
    testWidgets('displays two mode options', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('Child'), findsOneWidget);
      expect(find.text('Adult'), findsOneWidget);
    });

    testWidgets('displays child mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.text('Full gamification, mystery rewards, parent oversight'),
        findsOneWidget,
      );
    });

    testWidgets('displays adult mode description', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.text(
          'Streamlined tracking, self-directed, optional engagement features',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Continue button disabled when no mode selected', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNull);
    });

    testWidgets('Continue button enabled after selecting a mode', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());

      // Tap child mode
      await tester.tap(find.text('Child'));
      await tester.pumpAndSettle();

      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button.onPressed, isNotNull);
    });

    testWidgets('shows change later message', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(
        find.text('You can change this later in Settings.'),
        findsOneWidget,
      );
    });

    testWidgets('shows question prompt', (tester) async {
      await tester.pumpWidget(createTestWidget());

      expect(find.text('How would you like to use the app?'), findsOneWidget);
    });
  });
}
