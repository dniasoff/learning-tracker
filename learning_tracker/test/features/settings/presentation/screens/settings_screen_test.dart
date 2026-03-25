import 'package:drift/native.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/providers/firebase_providers.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';
import 'package:mocktail/mocktail.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

void main() {
  late AppDatabase database;
  late MockFirebaseAuth mockAuth;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    mockAuth = MockFirebaseAuth();
    when(() => mockAuth.currentUser).thenReturn(null);
  });

  tearDown(() async {
    await database.close();
  });

  Widget createTestWidget({List<CurriculumId> initialActive = const []}) {
    // Initialize database with active curricula
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
            firebaseAuthProvider.overrideWithValue(mockAuth),
            curriculumActivationServiceProvider.overrideWith((ref) {
              return CurriculumActivationService(
                database: database,
                pushActiveCurricula: (_) async {}, // Mock Firestore sync
                trackRepository: TrackRepositoryImpl(database: database),
              );
            }),
          ],
          child: const MaterialApp(home: SettingsScreen()),
        );
      },
    );
  }

  /// Pump the widget and wait for async providers to settle.
  Future<void> pumpUntilSettled(WidgetTester tester) async {
    // First pump resolves the FutureBuilder
    await tester.pump(const Duration(milliseconds: 100));
    // Second pump allows the StreamProvider to emit
    await tester.pump(const Duration(milliseconds: 100));
    // Third pump for any remaining microtasks
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders top section headers', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      expect(find.text('LEARNING'), findsOneWidget);
      expect(find.text('APPEARANCE'), findsOneWidget);
    });

    testWidgets('renders Curricula tile with active count', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActive: [CurriculumId.mishnayos, CurriculumId.bavli],
        ),
      );
      await pumpUntilSettled(tester);

      expect(find.text('Curricula'), findsOneWidget);
      expect(find.text('Manage your learning path'), findsOneWidget);
      expect(find.text('2 active'), findsOneWidget);
    });

    testWidgets('renders learning section tiles', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      expect(find.text('Curricula'), findsOneWidget);
      expect(find.text('Goals'), findsOneWidget);
      expect(find.text('Daily Reminder'), findsOneWidget);
    });

    testWidgets('shows active count of 1 for single curriculum',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      expect(find.text('1 active'), findsOneWidget);
    });

    testWidgets('renders Daily Reminder Switch', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      // Daily Reminder has a Switch in the LEARNING section
      expect(find.byType(Switch), findsAtLeastNWidgets(1));
    });

    testWidgets('renders lower sections when scrolled', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      // Scroll down to reveal more content
      await tester.drag(find.byType(ListView), const Offset(0, -800));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('ACCOUNT'), findsOneWidget);
      expect(find.text('Sign Out'), findsOneWidget);
      expect(find.text('Delete Account'), findsOneWidget);
    });

    testWidgets('displays app version when scrolled to bottom',
        (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await pumpUntilSettled(tester);

      // Scroll to the very bottom
      await tester.drag(find.byType(ListView), const Offset(0, -1000));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Torah Tracker v1.0.0'), findsOneWidget);
    });
  });
}
