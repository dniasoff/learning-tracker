// firebase_bootstrap_test.dart — AUD-app-06 regression coverage.
//
// bootstrapFirebase() has two nested `catch` blocks that must never swallow
// an exception silently (EH-3): the inner App Check `activate()` catch
// (comment-only before the fix) and the outer Firebase-init catch
// (comment-only before the fix). Both must log through AppLogger with a
// distinct event name so a real-world failure leaves a diagnostic trace.
//
// Test 1 forces FirebaseAppCheck.instance.activate() to throw via a fake
// FirebaseAppCheckPlatform. Firebase.initializeApp itself must succeed for
// this test to even reach the App Check try — the stock
// `setupFirebaseCoreMocks()` helper's canned `CoreInitializeResponse`
// (apiKey '123') does NOT match this app's real
// `DefaultFirebaseOptions.android` apiKey, so `Firebase.initializeApp` would
// throw a `duplicate-app` FirebaseException and land in the *separate*
// `on FirebaseException catch (_)` branch (line ~47, not part of this
// finding) before ever reaching App Check. `_MatchingCoreHostApi` below
// avoids that by echoing back whatever options it's asked to initialize
// with, so the init genuinely succeeds.
//
// Test 2 forces Firebase.initializeApp's own argument evaluation
// (DefaultFirebaseOptions.currentPlatform) to throw by overriding
// debugDefaultTargetPlatformOverride to an unsupported platform
// (TargetPlatform.fuchsia) — a deterministic, host-OS-independent way to
// reach the outer, non-FirebaseException catch without any Firebase mocking.

@Tags(['bootstrap', 'unit'])
library;

// ignore_for_file: depend_on_referenced_packages
// firebase_app_check_platform_interface and firebase_core_platform_interface
// are transitive deps of firebase_app_check / firebase_core, not declared
// directly in pubspec.yaml — the standard platform-interface test-seam
// pattern already used in
// test/features/tutoring/data/repositories/firestore_tutor_grant_repository_test.dart.

import 'package:firebase_app_check_platform_interface/firebase_app_check_platform_interface.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/app/bootstrap/firebase_bootstrap.dart';
import 'package:learning_tracker/core/logging/logger.dart';

/// [TestFirebaseCoreHostApi] that reports no pre-existing native app (an
/// empty [initializeCore] response) and echoes back whatever options
/// [initializeApp] is called with, so a real `Firebase.initializeApp(options:
/// DefaultFirebaseOptions.android)` call succeeds cleanly instead of hitting
/// the stock mock's hardcoded-apiKey `duplicate-app` mismatch.
class _MatchingCoreHostApi implements TestFirebaseCoreHostApi {
  @override
  Future<List<CoreInitializeResponse>> initializeCore() async => [];

  @override
  Future<CoreInitializeResponse> initializeApp(
    String appName,
    CoreFirebaseOptions initializeAppRequest,
  ) async => CoreInitializeResponse(
    name: appName,
    options: initializeAppRequest,
    pluginConstants: {},
  );

  @override
  Future<CoreFirebaseOptions> optionsFromResource() =>
      throw UnimplementedError('not exercised — options are always explicit');
}

/// Fake [FirebaseAppCheckPlatform] whose [activate] always throws, letting
/// tests force bootstrapFirebase()'s App Check catch block without touching
/// real attestation providers or the network.
class _ThrowingAppCheckPlatform extends FirebaseAppCheckPlatform {
  _ThrowingAppCheckPlatform() : super();

  @override
  FirebaseAppCheckPlatform delegateFor({required FirebaseApp app}) => this;

  @override
  FirebaseAppCheckPlatform setInitialValues() => this;

  @override
  Future<void> activate({
    WebProvider? webProvider,
    AndroidProvider? androidProvider,
    AppleProvider? appleProvider,
    AndroidAppCheckProvider? providerAndroid,
    AppleAppCheckProvider? providerApple,
    WindowsAppCheckProvider? providerWindows,
  }) {
    throw Exception('fake App Check activation failure');
  }
}

void main() {
  setUp(() {
    // Fresh Talker/AppLogger per test so history assertions only see this
    // test's own entries.
    AppLogger.init();
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  group('bootstrapFirebase — App Check activation failure', () {
    setUpAll(() {
      TestWidgetsFlutterBinding.ensureInitialized();
      TestFirebaseCoreHostApi.setUp(_MatchingCoreHostApi());
    });

    test('is logged through AppLogger, not silently swallowed', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      FirebaseAppCheckPlatform.instance = _ThrowingAppCheckPlatform();

      // Must not throw — bootstrapFirebase() is documented non-fatal.
      await bootstrapFirebase();

      final history = AppLogger.instance.talker.history;
      final matches = history.where(
        (entry) =>
            entry.generateTextMessage().contains('app_check_activation_failed'),
      );

      expect(
        matches,
        isNotEmpty,
        reason:
            'App Check activation failure must leave an AppLogger/Talker '
            'history entry (EH-3) — found: '
            '${history.map((e) => e.generateTextMessage()).toList()}',
      );
      expect(
        matches.first.exception,
        isNotNull,
        reason: 'the logged entry must carry the original exception',
      );
    });
  });

  group('bootstrapFirebase — Firebase.initializeApp failure', () {
    test('is logged through AppLogger, not silently swallowed', () async {
      // TargetPlatform.fuchsia has no configured FirebaseOptions, so
      // DefaultFirebaseOptions.currentPlatform throws UnsupportedError before
      // Firebase.initializeApp is ever reached — deterministically driving
      // bootstrapFirebase() into its outer, non-FirebaseException catch
      // (lines 50-52) on any host OS.
      debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;

      // Must not throw — bootstrapFirebase() is documented non-fatal.
      await bootstrapFirebase();

      final history = AppLogger.instance.talker.history;
      final matches = history.where(
        (entry) => entry.generateTextMessage().contains('firebase_init_failed'),
      );

      expect(
        matches,
        isNotEmpty,
        reason:
            'Firebase.initializeApp failure must leave an AppLogger/Talker '
            'history entry (EH-3) — found: '
            '${history.map((e) => e.generateTextMessage()).toList()}',
      );
      expect(
        matches.first.exception,
        isNotNull,
        reason: 'the logged entry must carry the original exception',
      );
    });
  });
}
