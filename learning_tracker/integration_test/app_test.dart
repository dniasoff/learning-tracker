import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:learning_tracker/app/learning_tracker_app.dart';
import 'package:learning_tracker/main.dart' as app;

/// Integration test suite for Torah Learning Tracker app
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

      // The local-first boot sequence resolves through async I/O (Drift DB
      // open, SharedPreferences, Firebase App Check) that doesn't keep the
      // frame scheduler "dirty" the way an animation would, so
      // pumpAndSettle can return before the boot splash is replaced by the
      // real tree. Poll until it settles, or time out.
      final deadline = DateTime.now().add(const Duration(seconds: 30));
      while (find.byType(LearningTrackerApp).evaluate().isEmpty &&
          DateTime.now().isBefore(deadline)) {
        await tester.pump(const Duration(milliseconds: 500));
      }

      // Verify app loaded successfully
      // Note: This will evolve as we implement the actual UI
      expect(find.byType(LearningTrackerApp), findsOneWidget);
    });
  });

  // TODO(DNI-393): Add more integration tests as features are implemented:
  // - Authentication flow (sign in, sign out)
  // - Content browsing (navigate curriculum hierarchy)
  // - Mark completion flow
  // - Sync verification
}
