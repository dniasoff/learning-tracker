import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/track_repository_impl.dart';
import 'package:learning_tracker/features/settings/domain/services/curriculum_activation_service.dart';
import 'package:learning_tracker/features/settings/presentation/providers/curriculum_activation_providers.dart';
import 'package:learning_tracker/features/settings/presentation/screens/settings_screen.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
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
          return const CircularProgressIndicator();
        }

        return ProviderScope(
          overrides: [
            appDatabaseProvider.overrideWithValue(database),
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

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all curricula with toggle switches', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await tester.pumpAndSettle();

      // Verify all curricula are displayed
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Talmud Bavli'), findsOneWidget);
      expect(find.text('Talmud Yerushalmi'), findsOneWidget);
      expect(find.text('Mishna Berurah'), findsOneWidget);
      expect(find.text('Chumash'), findsOneWidget);

      // Verify all have switches
      expect(
        find.byType(SwitchListTile),
        findsNWidgets(CurriculumId.values.length),
      );
    });

    testWidgets('shows active curricula with green status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActive: [CurriculumId.mishnayos, CurriculumId.bavli],
        ),
      );
      await tester.pumpAndSettle();

      // Find active status texts
      final activeTexts = find.text('Active');
      expect(activeTexts, findsNWidgets(2)); // Mishnayos and Bavli
    });

    testWidgets('shows inactive curricula with grey status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await tester.pumpAndSettle();

      // Find inactive status texts
      final inactiveTexts = find.text('Inactive');
      expect(
        inactiveTexts,
        findsNWidgets(CurriculumId.values.length - 1),
      ); // All but Mishnayos are inactive
    });

    testWidgets('toggles on an inactive curriculum', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await tester.pumpAndSettle();

      // Find and tap Bavli switch
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(bavliSwitch);
      await tester.pumpAndSettle();

      // Verify Bavli is now active in database
      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isTrue);
    });

    testWidgets('toggles off an active curriculum (when not last)', (
      tester,
    ) async {
      await tester.pumpWidget(
        createTestWidget(
          initialActive: [CurriculumId.mishnayos, CurriculumId.bavli],
        ),
      );
      await tester.pumpAndSettle();

      // Find and tap Bavli switch to deactivate
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );
      await tester.tap(bavliSwitch);
      await tester.pumpAndSettle();

      // Verify Bavli is now inactive in database
      final isActive = await database.activeCurriculumDao.isActive(
        CurriculumId.bavli,
      );
      expect(isActive, isFalse);
    });

    testWidgets('disables toggle for last active curriculum', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await tester.pumpAndSettle();

      // Find Mishnayos switch
      final mishnayosSwitch = find.ancestor(
        of: find.text('Mishnayos'),
        matching: find.byType(SwitchListTile),
      );

      final switchWidget = tester.widget<SwitchListTile>(mishnayosSwitch);
      expect(switchWidget.value, isTrue); // It's active
      expect(switchWidget.onChanged, isNull); // But disabled
    });

    testWidgets('section header displays correctly', (tester) async {
      await tester.pumpWidget(
        createTestWidget(initialActive: [CurriculumId.mishnayos]),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Curricula'), findsOneWidget);
      expect(
        find.text('Choose which curricula to display in the app'),
        findsOneWidget,
      );
    });
  });
}
