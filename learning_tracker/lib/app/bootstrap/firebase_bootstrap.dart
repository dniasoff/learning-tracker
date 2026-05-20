import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/firebase_options.dart';

/// Initialises Firebase and Crashlytics, returning a [CrashlyticsService].
///
/// Non-fatal if Firebase is unavailable (no network, no Play Services, etc.).
/// In that case the returned service is a [NullCrashlyticsService] and the app
/// continues in local-first mode.
Future<CrashlyticsService> bootstrapFirebase() async {
  CrashlyticsService crashlytics = const NullCrashlyticsService();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // Wire Crashlytics immediately after Firebase init, before any other
    // init that can throw (Story 24.4).
    final fbCrashlytics = FirebaseCrashlytics.instance;
    await fbCrashlytics.setCrashlyticsCollectionEnabled(true);
    crashlytics = FirebaseCrashlyticsService(fbCrashlytics);
  } on FirebaseException catch (_) {
    // Already initialized (e.g. hot restart) — use existing app.
    crashlytics = FirebaseCrashlyticsService(FirebaseCrashlytics.instance);
  } catch (_) {
    // Firebase init failed — app continues in local-first mode.
  }
  return crashlytics;
}
