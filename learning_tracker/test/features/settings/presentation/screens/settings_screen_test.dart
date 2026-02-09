import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/app_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
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

  Future<Widget> createTestWidget(WidgetTester tester) async {
    final service = CurriculumActivationService(
      database: database,
      firestoreDataSource: null, // No Firestore in tests
    );

    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
        curriculumActivationServiceProvider.overrideWithValue(service),
      ],
    );
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('shows all 5 curricula with toggle switches', (tester) async {
      // Activate one curriculum to avoid empty state
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      await tester.pumpWidget(await createTestWidget(tester));
      await tester.pumpAndSettle();

      // Check that all 5 curricula are shown
      expect(find.text('Mishnayos'), findsOneWidget);
      expect(find.text('Talmud Bavli'), findsOneWidget);
      expect(find.text('Talmud Yerushalmi'), findsOneWidget);
      expect(find.text('Mishna Berurah'), findsOneWidget);
      expect(find.text('Chumash'), findsOneWidget);

      // Check that there are 5 switches
      expect(find.byType(SwitchListTile), findsNWidgets(5));
    });

    testWidgets('active curricula have switches toggled on', (tester) async {
      // Activate Bavli and Mishnayos
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      await tester.pumpWidget(await createTestWidget(tester));
      await tester.pumpAndSettle();

      // Find the switches for Bavli and Mishnayos
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );
      final mishnayosSwitch = find.ancestor(
        of: find.text('Mishnayos'),
        matching: find.byType(SwitchListTile),
      );

      expect(tester.widget<SwitchListTile>(bavliSwitch).value, isTrue);
      expect(tester.widget<SwitchListTile>(mishnayosSwitch).value, isTrue);
    });

    testWidgets('toggling off last curriculum shows error snackbar', (
      tester,
    ) async {
      // Activate only Bavli
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );

      await tester.pumpWidget(await createTestWidget(tester));
      await tester.pumpAndSettle();

      // Find and tap the Bavli switch to turn it off
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );

      await tester.tap(bavliSwitch);
      await tester.pumpAndSettle();

      // Verify error snackbar is shown
      expect(find.byType(SnackBar), findsOneWidget);
      expect(
        find.text('Exception: Cannot deactivate the last active curriculum'),
        findsOneWidget,
      );
    });

    testWidgets('toggling on a curriculum activates it', (tester) async {
      // Activate Mishnayos
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      await tester.pumpWidget(await createTestWidget(tester));
      await tester.pumpAndSettle();

      // Find and tap the Bavli switch to turn it on
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );

      // Verify it's initially off
      expect(tester.widget<SwitchListTile>(bavliSwitch).value, isFalse);

      await tester.tap(bavliSwitch);
      await tester.pumpAndSettle();

      // Verify it's now on
      expect(tester.widget<SwitchListTile>(bavliSwitch).value, isTrue);

      // Verify it's in the database
      final isActive = await database.activeCurriculumDao.isActive('bavli');
      expect(isActive, isTrue);
    });

    testWidgets('toggling off a curriculum deactivates it', (tester) async {
      // Activate both Bavli and Mishnayos
      await database.activeCurriculumDao.activate(
        CurriculumId.bavli.storageKey,
      );
      await database.activeCurriculumDao.activate(
        CurriculumId.mishnayos.storageKey,
      );

      await tester.pumpWidget(await createTestWidget(tester));
      await tester.pumpAndSettle();

      // Find and tap the Bavli switch to turn it off
      final bavliSwitch = find.ancestor(
        of: find.text('Talmud Bavli'),
        matching: find.byType(SwitchListTile),
      );

      // Verify it's initially on
      expect(tester.widget<SwitchListTile>(bavliSwitch).value, isTrue);

      await tester.tap(bavliSwitch);
      await tester.pumpAndSettle();

      // Verify it's now off
      expect(tester.widget<SwitchListTile>(bavliSwitch).value, isFalse);

      // Verify it's removed from the database
      final isActive = await database.activeCurriculumDao.isActive('bavli');
      expect(isActive, isFalse);
    });
  });
}
