// Story 2.1 — AD-1 topology go/no-go smoke test.
//
// Question this file answers, and nothing more: do N named `FirebaseApp`
// instances (same Firestore project, distinct Auth identities, persistence
// enabled) keep fully isolated on-disk caches on Android?
//
// Traceability: FR1 (docs/planning/epics-firestore-migration-phase0.md),
// CAP-1 gate semantics, AD-1 topology `[ASSUMPTION]` and its "What could
// kill this" #1, AD-29 tier-3 on-device verification
// (docs/planning/architecture/architecture-learning-tracker-2026-07-30/ARCHITECTURE-SPINE.md).
//
// Backend: the Firestore + Auth EMULATORS (learning_tracker/firebase.json),
// reached from an Android emulator/device at 10.0.2.2. This deliberately
// skips App Check and production — client-side persistence-cache behavior
// (the thing AD-1's `[ASSUMPTION]` is unsure about) is backend-independent,
// so the emulator is a faithful test of the topology question. Uses minimal
// placeholder `FirebaseOptions` (real projectId `torah-study-tracker`,
// dummy apiKey/appId/messagingSenderId) so this file does not depend on the
// CI-injected `lib/firebase_options.dart` secret — the emulator never
// validates those fields.
//
// Deviation from steer: none. Two secondary named apps are created; the
// default app is left untouched.
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

/// Android emulator's alias for the host loopback interface. Matches
/// `firebase.json`'s configured emulator ports (firestore 8080, auth 9099).
const _emulatorHost = '10.0.2.2';
const _firestorePort = 8080;
const _authPort = 9099;

/// A bounded (non-unlimited) persistence cache size, per the steer's
/// resource-risk framing (api29-learn-oom thread) — this is not the
/// resource pass bar itself (that's binary: no OOM/fd-exhaustion/crash),
/// just a deliberately-finite cache so the test doesn't rely on the SDK
/// default of unlimited.
const _cacheSizeBytes = 5 * 1024 * 1024; // 5 MiB

/// Placeholder `FirebaseOptions` good enough for the emulator, which does
/// not validate apiKey/appId/messagingSenderId. Only `projectId` must be
/// real (it must match the emulator's `--project torah-study-tracker`).
FirebaseOptions _emulatorOptions() => const FirebaseOptions(
  apiKey: 'placeholder-api-key',
  appId: '1:000000000000:android:0000000000000000000000',
  messagingSenderId: '000000000000',
  projectId: 'torah-study-tracker',
);

/// Initializes a secondary named [FirebaseApp] and points its Firestore
/// instance at the emulator with persistence enabled, BEFORE first use
/// (required by the SDK — `.settings` must be set before any Firestore
/// call on that instance).
Future<(FirebaseApp, FirebaseFirestore, FirebaseAuth)> _initNamedContext(
  String name,
) async {
  final firebaseApp = await Firebase.initializeApp(
    name: name,
    options: _emulatorOptions(),
  );

  final firestore = FirebaseFirestore.instanceFor(app: firebaseApp);
  // One settings assignment carrying host+ssl+persistence together: setting
  // `.settings` a second time (e.g. after a separate `useFirestoreEmulator`
  // call) would silently reset any fields omitted from the second call.
  firestore.settings = const Settings(
    host: '$_emulatorHost:$_firestorePort',
    sslEnabled: false,
    persistenceEnabled: true,
    cacheSizeBytes: _cacheSizeBytes,
  );

  final auth = FirebaseAuth.instanceFor(app: firebaseApp);
  await auth.useAuthEmulator(_emulatorHost, _authPort);

  return (firebaseApp, firestore, auth);
}

/// Best-effort, in-process inspection of this app's own private storage for
/// per-`FirebaseApp` Firestore persistence artifacts. Runs as the app's own
/// Android process (self-instrumented `integration_test`), so no `adb
/// run-as` / root is needed to read its own sandboxed files.
///
/// Observed on-device (this run, `cloud_firestore` 6.4.1 / API 34): the
/// Android SDK's SQLite persistence backend materializes ONE FILE per named
/// app directly under `<filesDir's sibling>/databases/`, named
/// `firestore.<persistenceKey>.<projectId>.%28default%29` where
/// `persistenceKey` is `FirebaseApp.getPersistenceKey()` — which equals the
/// app's `name` for a non-default app (e.g.
/// `databases/firestore.account_A.torah-study-tracker.%28default%29`).
/// That is a documented Android SDK gotcha's inverse used as a feature
/// here: naming embeds the app identity, so a filename literally containing
/// `account_A` (or `account_B`) is direct on-disk evidence of a per-app
/// cache artifact, not an inference. (An older/legacy LevelDB-based build
/// would instead show this as a `firestore/<project>.<db>/<persistenceKey>/`
/// *directory* — both shapes are searched for, since which one a given SDK
/// version uses is an implementation detail this test does not pin.)
///
/// Returns the discovered artifact paths keyed by app name. Never throws —
/// permission or path-shape surprises are swallowed and reported as an
/// empty map, in which case the caller must fall back to the behavioral
/// isolation proof (steps above) and say so explicitly, per the steer.
Future<Map<String, String>> _findFirestorePersistenceArtifacts(
  List<String> appNames,
) async {
  final found = <String, String>{};
  try {
    final supportDir = await getApplicationSupportDirectory();
    // On Android, getApplicationSupportDirectory() is
    // `<filesDir>/app_flutter`; its parent is the app's private root
    // (`/data/user/0/<package>` or `/data/data/<package>`), which also
    // contains the `databases/` (and, on older SDKs, `files/firestore/`)
    // siblings Firestore persists into.
    final appPrivateRoot = supportDir.parent;
    final allDirsSeen = <String>[];
    final allFilesSeen = <String>[];
    void recordIfMatch(String path) {
      final base = path.split(Platform.pathSeparator).last;
      for (final name in appNames) {
        if (base.contains(name) && !found.containsKey(name)) {
          found[name] = path;
        }
      }
    }

    void walk(Directory dir, int depth) {
      if (depth > 8) return;
      List<FileSystemEntity> entries;
      try {
        entries = dir.listSync();
      } catch (_) {
        return; // permission-denied / transient — skip, do not crash the run
      }
      for (final entry in entries) {
        if (entry is File) {
          allFilesSeen.add(entry.path);
          recordIfMatch(entry.path);
          continue;
        }
        if (entry is! Directory) continue;
        allDirsSeen.add(entry.path);
        recordIfMatch(entry.path);
        walk(entry, depth + 1);
      }
    }

    walk(appPrivateRoot, 0);
    // Logged unconditionally so the verdict below is independently
    // auditable from the test output, not just asserted.
    // ignore: avoid_print
    print(
      '[dir-inspection] root=${appPrivateRoot.path} '
      'dirsSeen=${allDirsSeen.length} filesSeen=${allFilesSeen.length} '
      'matched=$found',
    );
  } catch (e) {
    // Inconclusive — behavioral proof (below) remains the load-bearing
    // isolation assertion; the caller documents this explicitly.
    // ignore: avoid_print
    print('[dir-inspection] inconclusive: $e');
  }
  return found;
}

/// Prints (does not gate on) process memory + open-fd counts as
/// observational evidence for the resource pass bar. Per the steer, the
/// binary pass bar is simply "the run completes with no OOM kill, no fd
/// exhaustion, no cache-init crash" — reaching this line at all is that
/// bar; these numbers are attached evidence only.
void _logResourceSnapshot(String label) {
  try {
    final status = File('/proc/self/status').readAsStringSync();
    final vmRss = RegExp(r'VmRSS:\s*(\d+ kB)').firstMatch(status)?.group(1);
    final fdCount = Directory('/proc/self/fd').listSync().length;
    // ignore: avoid_print
    print('[resource-snapshot:$label] VmRSS=$vmRss openFds=$fdCount');
  } catch (e) {
    // ignore: avoid_print
    print('[resource-snapshot:$label] unavailable: $e');
  }
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Story 2.1 — AD-1 two-named-app cache isolation smoke test', () {
    // All three named-app contexts (account_A, account_B for the isolation
    // proof; shared_leaky_app for the red-demo) are created together, once,
    // before either test body runs, and torn down together at the very end.
    //
    // This is a deliberate structural choice, not just tidiness: creating
    // them interleaved with per-test deletion (create A+B → run test →
    // delete A+B → create a 3rd app → run red-demo) reproducibly trips a
    // firebase_auth Android-plugin bug — the 3rd `useAuthEmulator()` call
    // made after a prior app in the same process was deleted throws
    // `_TypeError: type 'String' is not a subtype of type 'Map<dynamic,
    // dynamic>?'` inside the plugin's own PlatformException conversion
    // (firebase_auth_platform_interface's `platformExceptionToFirebaseAuthException`).
    // Verified: each test passes cleanly in isolation
    // (`--plain-name "distinct named apps"` and `--plain-name "RED-DEMO"`
    // each pass 100% on their own); only the combined in-process ordering
    // trips the plugin bug. Front-loading all `useAuthEmulator()` calls
    // before any deletion happens avoids the trigger and is unrelated to
    // the AD-1 topology question this file exists to answer.
    late FirebaseApp appA;
    late FirebaseFirestore firestoreA;
    late FirebaseAuth authA;
    late FirebaseApp appB;
    late FirebaseFirestore firestoreB;
    late FirebaseAuth authB;
    late FirebaseApp sharedApp;
    late FirebaseFirestore sharedFirestore;
    late FirebaseAuth sharedAuth;

    setUpAll(() async {
      (appA, firestoreA, authA) = await _initNamedContext('account_A');
      (appB, firestoreB, authB) = await _initNamedContext('account_B');
      (sharedApp, sharedFirestore, sharedAuth) = await _initNamedContext(
        'shared_leaky_app',
      );
    });

    tearDownAll(() async {
      await appA.delete();
      await appB.delete();
      await sharedApp.delete();
    });

    testWidgets('distinct named apps keep fully isolated on-disk caches', (
      tester,
    ) async {
      _logResourceSnapshot('start');

      // --- Assertion 1: distinct anonymous uid per app (FR1).
      final credA = await authA.signInAnonymously();
      final credB = await authB.signInAnonymously();
      final uidA = credA.user!.uid;
      final uidB = credB.user!.uid;
      expect(
        uidA,
        isNot(equals(uidB)),
        reason: 'each named app must sign in as a distinct identity',
      );

      // --- Assertion 2: app A's write round-trips into app A's own cache.
      // Path uses the real `diagnostic_logs` collection (firestore.rules
      // `users/{uid}/diagnostic_logs/{logId}`, owner-only create/read, no
      // field whitelist) rather than an invented collection, so the write
      // is exercised against the actual security rules the emulator loads
      // — not a rules-bypassing shortcut.
      final markerPath = 'users/$uidA/diagnostic_logs/isolation_marker';
      await firestoreA.doc(markerPath).set({
        'writtenBy': 'account_A',
        'uid': uidA,
      });
      final selfRead = await firestoreA
          .doc(markerPath)
          .get(const GetOptions(source: Source.cache));
      expect(
        selfRead.exists,
        isTrue,
        reason: "app A must see its own write in app A's own cache",
      );
      expect(selfRead.data()!['writtenBy'], 'account_A');

      // --- Assertion 3 (the isolation proof): the SAME logical path is
      // invisible in app B's cache — app B never wrote or fetched it, and a
      // leaking shared cache would show it anyway (see the red-demo test).
      DocumentSnapshot<Map<String, dynamic>>? crossRead;
      Object? crossReadError;
      try {
        crossRead = await firestoreB
            .doc(markerPath)
            .get(const GetOptions(source: Source.cache));
      } catch (e) {
        crossReadError = e;
      }
      // The Android SDK throws "Failed to get document from cache" for a
      // cache-only get() on an unknown path; treat either "threw" or
      // "returned exists:false" as isolation-confirmed, since both mean
      // app B's cache has no knowledge of app A's document.
      final isolated =
          crossReadError != null || (crossRead != null && !crossRead.exists);
      expect(
        isolated,
        isTrue,
        reason:
            "app B's cache must NOT contain app A's write "
            '(got error=$crossReadError, snapshot=$crossRead)',
      );

      // --- Assertion 4: cache-directory/artifact isolation. Best-effort
      // direct on-disk inspection; falls back to "behavioral-only"
      // documentation if the SDK's on-disk layout can't be located from
      // Dart, per the steer. A short settle delay first: the SDK's on-disk
      // SQLite persistence flush runs on a background thread and may not
      // have materialized the artifact the instant `.set()`/`.get()`
      // return.
      await Future<void>.delayed(const Duration(seconds: 2));
      final artifacts = await _findFirestorePersistenceArtifacts([
        'account_A',
        'account_B',
      ]);
      if (artifacts.containsKey('account_A') &&
          artifacts.containsKey('account_B')) {
        expect(
          artifacts['account_A'],
          isNot(equals(artifacts['account_B'])),
          reason: 'account_A and account_B must use distinct cache storage',
        );
        // ignore: avoid_print
        print(
          '[cache-dir] DIRECTLY OBSERVED distinct on-disk cache artifacts: '
          'account_A=${artifacts['account_A']} '
          'account_B=${artifacts['account_B']}',
        );
      } else {
        // ignore: avoid_print
        print(
          '[cache-dir] INCONCLUSIVE from Dart-side inspection '
          '(found: ${artifacts.keys}). Cache-directory isolation is NOT '
          'directly observed here; it is INFERRED from the behavioral '
          'isolation proof in Assertion 3 above (a shared/colliding cache '
          "would make app B's cache-read see app A's document, which it "
          'did not). This inference gap is disclosed, not papered over.',
        );
      }

      _logResourceSnapshot('end');
    });

    testWidgets(
      'RED-DEMO: sharing one app/cache is caught as a leak (proves the '
      'isolation assertion has teeth)',
      (tester) async {
        // Deliberately mis-configured: ONE named app (`sharedApp`, created
        // in `setUpAll` above) stands in for BOTH logical contexts, so
        // there is exactly one cache directory shared between "context 1"
        // and "context 2". If Assertion 3 above were vacuous (always passes
        // regardless of real isolation), this test would also pass. It
        // must NOT — it must show the leak.

        // Context 1: sign in, write a marker.
        final cred1 = await sharedAuth.signInAnonymously();
        final uid1 = cred1.user!.uid;
        final markerPath = 'users/$uid1/diagnostic_logs/isolation_marker';
        await sharedFirestore.doc(markerPath).set({
          'writtenBy': 'context_1',
          'uid': uid1,
        });

        // Context 2: a DIFFERENT logical identity, same app/cache (the
        // mis-configuration under test).
        await sharedAuth.signOut();
        final cred2 = await sharedAuth.signInAnonymously();
        final uid2 = cred2.user!.uid;
        expect(
          uid2,
          isNot(equals(uid1)),
          reason: 'sanity check: context 2 must be a genuinely new identity',
        );

        // The leak: context 2, using the SAME Firestore instance/cache as
        // context 1, can read context 1's write straight from cache — the
        // exact failure mode Assertion 3 exists to catch.
        final leaked = await sharedFirestore
            .doc(markerPath)
            .get(const GetOptions(source: Source.cache));
        expect(
          leaked.exists,
          isTrue,
          reason:
              'RED-DEMO: with one shared app/cache, context 2 CAN see '
              "context 1's write — this is the leak the real isolation "
              'assertion (Assertion 3, above) is designed to catch. Seeing '
              'it here confirms that assertion is not vacuous.',
        );
        expect(leaked.data()!['writtenBy'], 'context_1');

        // Cache-directory collision is trivial here by construction (one
        // app instance played both roles) — logged for completeness, not
        // re-derived from disk.
        // ignore: avoid_print
        print(
          '[red-demo] cache-directory collision is trivial by construction: '
          'both contexts used the single "shared_leaky_app" named app.',
        );
      },
    );
  });
}
