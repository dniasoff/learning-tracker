// Regression guard for AUD-guardrails-04's fix-bounce: `tool/seed/lib/
// sefaria_mongo.dart` and its entrypoints (`build_text_cache.dart`,
// `build_daily_content.dart`, `sample_validate.dart`) are plain-Dart CLI
// scripts, invoked via `dart run tool/seed/...` (Makefile "make seed"
// targets 1/4 + 2/4) with NO Flutter engine/`dart:ui` embedder available.
//
// A reviewer bounce caught `sefaria_mongo.dart` importing
// `package:flutter/foundation.dart show visibleForTesting` — a pure-Dart
// symbol re-exported from a Flutter-only library. `flutter analyze` and
// `flutter test` both stayed green because `flutter_test` itself provides
// `dart:ui`, so a `flutter_test`-driven unit test of this file (see
// `sefaria_mongo_test.dart` in this directory) compiles fine even with the
// broken import. Only the standalone `dart` VM used by the real seed
// pipeline fails, with a `dart:ui`-shaped compile error (undefined
// `ui.Image`/`ui.Picture` etc. from `flutter/foundation.dart`'s
// `memory_allocations.dart`) — BEFORE `main()` ever runs, so no amount of
// mocking Mongo would surface it.
//
// This test shells out to `dart run tool/seed/build_text_cache.dart`
// exactly as `make seed` does (precedent:
// test/tool/build_cities_db_admin1_test.dart), proving the entrypoint
// compiles and starts executing under the plain Dart VM. It points `--mongo`
// at an unbound loopback port so it fails FAST on a real (non-`dart:ui`)
// runtime error without requiring the Dockerized Sefaria Mongo — the failure
// signature itself (a MongoDB connection exception, not a compile error) is
// asserted, so a regressed `dart:ui`-requiring import turns this test RED.

@Tags(['tool', 'seed'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory tmpDir;
  late String repoRoot;

  setUp(() {
    tmpDir = Directory.systemTemp.createTempSync('seed_entrypoint_smoke_');
    // The test runs with CWD == the `learning_tracker` package root.
    repoRoot = Directory.current.path;
  });

  tearDown(() {
    if (tmpDir.existsSync()) tmpDir.deleteSync(recursive: true);
  });

  test('build_text_cache.dart compiles + runs under the standalone Dart VM '
      '(no dart:ui-requiring import) — AUD-guardrails-04', () async {
    // Minimal synthetic manifest: {program: {book: [ref, ...]}}, matching
    // `_loadManifestRefs`'s expected shape.
    final manifestPath = '${tmpDir.path}/manifest.json';
    File(manifestPath).writeAsStringSync(
      jsonEncode({
        'program': {
          'book': ['Genesis 1:1'],
        },
      }),
    );

    final scriptPath = '$repoRoot/tool/seed/build_text_cache.dart';

    // Port 1 on loopback: nothing listens there, so the connection is
    // refused immediately (no Docker/Mongo needed, no hang).
    final result = await Process.run('timeout', [
      '30',
      'dart',
      'run',
      scriptPath,
      '--manifest',
      manifestPath,
      '--mongo',
      'mongodb://127.0.0.1:1/no_such_db',
    ], workingDirectory: repoRoot);

    final stdout = result.stdout.toString();
    final stderr = result.stderr.toString();
    final combined = '$stdout\n$stderr';

    // A dart:ui-requiring import fails to COMPILE, so nothing in main()
    // ever runs and this line never prints — this is the load-bearing
    // assertion the reviewer bounce would have caught.
    expect(
      stdout,
      contains('Manifest refs: 1'),
      reason:
          'script must compile and start executing under the plain Dart '
          'VM; if this fails, an import in sefaria_mongo.dart (or an '
          'entrypoint) requires dart:ui — check for '
          'package:flutter/... imports outside a Flutter target.\n'
          'stdout: $stdout\nstderr: $stderr',
    );
    expect(
      combined,
      isNot(
        anyOf(
          contains('dart:ui'),
          contains("Undefined name 'Image'"),
          contains("Undefined name 'Picture'"),
          contains('package:flutter/'),
        ),
      ),
      reason:
          'output must not contain any dart:ui-unavailable compile-error '
          'signature\ncombined output: $combined',
    );
    // The real failure mode here (no live Mongo) must be a runtime
    // connection error, not a compile error — proves we got past imports
    // and into main().
    expect(
      combined,
      anyOf(contains('MongoDB'), contains('SocketException')),
      reason:
          'expected a MongoDB connection failure (proves the script '
          'compiled and ran), got:\ncombined output: $combined',
    );
    expect(
      result.exitCode,
      isNot(0),
      reason:
          'no live Mongo is available in this test, so the script must '
          'fail — but via a runtime connection error, not a compile '
          'error (asserted above)',
    );
  }, timeout: const Timeout(Duration(seconds: 45)));
}
