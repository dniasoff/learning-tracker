import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/main.dart' as app;

/// Integration test suite for Learning Tracker app
///
/// Runs on real devices/emulators to test end-to-end flows.
/// Uses Firebase emulators for auth/firestore in CI.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('App Launch', () {
    testWidgets('app launches without crashing', (tester) async {
      // Launch the app
      app.main();
      await tester.pumpAndSettle();

      // Verify app loaded successfully
      // Note: This will evolve as we implement the actual UI
      expect(find.byType(app.LearningTrackerApp), findsOneWidget);
    });
  });

  // TODO: Add more integration tests as features are implemented:
  // - Authentication flow (sign in, sign out)
  // - Content browsing (navigate curriculum hierarchy)
  // - Mark completion flow
  // - Sync verification
}
