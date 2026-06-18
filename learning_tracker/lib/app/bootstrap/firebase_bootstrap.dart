import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
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
    ).timeout(const Duration(seconds: 15));
    // Activate App Check before any Firestore/Functions/Storage use so the
    // SDK attaches attestation tokens to every request. Debug builds (incl.
    // sideloaded `flutter run`) use the debug provider, whose token must be
    // registered in the console; release builds attest via Play Integrity /
    // App Attest. Non-fatal: a failure must not block local-first startup.
    //
    // Timeout guards against FirebearStorageCryptoHelper decryption failures
    // (corrupted Firebase Installation ID from a previous install) which cause
    // activate() to hang indefinitely rather than throw.
    try {
      await FirebaseAppCheck.instance
          .activate(
            providerAndroid: kDebugMode
                ? const AndroidDebugProvider()
                : const AndroidPlayIntegrityProvider(),
            providerApple: kDebugMode
                ? const AppleDebugProvider()
                : const AppleAppAttestProvider(),
          )
          .timeout(const Duration(seconds: 10));
    } catch (_) {
      // App Check unavailable — continue; sync may be rejected if enforced.
    }
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
