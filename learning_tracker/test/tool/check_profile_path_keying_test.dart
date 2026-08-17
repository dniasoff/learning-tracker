// Tests for `tool/check_profile_path_keying.dart` (docs/firestore-rewrite-map.md
// item 10 — the writer/reader path-disagreement defect class that produced
// the bookmarks/learning-order regression).
//
// Each fixture test builds a disposable directory tree under the system
// temp dir and drives the checker at it via `--root`/`--baseline`/
// `--collections` — fully isolated from this repo's real lib/,
// functions/src/, and firestore.rules, mirroring the pattern used by
// test/tool/check_lcov_denominator_test.dart.
//
// This file unit-tests three things in isolation:
//   1. Step 0 — the collection-registry self-check against a fixture
//      firestore.rules snippet, both matching and deliberately-drifted.
//   2. The comment-stripping literal-token matcher (positive/negative
//      cases, including a `// mentions bookmarks in prose` line).
//   3. The reachability algorithm against small synthetic fixture
//      directories: a LIVE 1-hop case, a LIVE 2-hop case, a DEAD case
//      exhausting every hop, plus (below) the four blind-spot fixes:
//        F1 — the ULID-C bucket also scans lib/features/**/data/
//             repositories/**, not just lib/data/repositories/, and does
//             NOT require a `firestore_`-prefixed filename there.
//        F2 — HOP 1B: a class constructed directly, with no provider
//             indirection at all, is LIVE.
//        F3 — the `class Firestore*` regex accepts every Dart 3 class
//             modifier (`final class`, `abstract class`, etc.).
//        F4 — a torn/truncated file read aborts the whole run loudly
//             (a distinct exit path, never a silent misclassification).
//        F5 — every reachability matcher (HOP 1/1B/2, and the provider
//             `return`-statement search) runs against a comment- and
//             string-literal-stripped copy of each file, so a mention
//             inside a `///` doc comment, a string literal, or a `/* */`
//             block comment no longer counts as a live reference.
//
// It deliberately does NOT run the checker against the real lib/ tree
// (too slow/brittle for the main suite) — those real-tree assertions
// belong to the serial-tools meta-test in test/tool/audit_and_arb_parity_
// test.dart.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final packageDir = Directory.current.path;
  final scriptPath = '$packageDir/tool/check_profile_path_keying.dart';

  Future<ProcessResult> run(List<String> args) => Process.run('dart', [
    'run',
    scriptPath,
    ...args,
  ], workingDirectory: packageDir);

  group(
    'tool/check_profile_path_keying.dart — step 0 (registry self-check)',
    () {
      // The real 18-name registry, mirrored here ONLY to build fixture
      // firestore.rules snippets — never asserted as a magic count, always
      // spelled out so a reviewer can see exactly what's being checked.
      const realCollections = [
        'completions',
        'streak_events',
        'learning_ledger',
        'points_ledger',
        'reward_redemptions',
        'settings',
        'stage_definitions',
        'point_configs',
        'curriculum_tracks',
        'bookmarks',
        'learning_order',
        'track_learning_order',
        'preferences',
        'goals',
        'import_metadata',
        'profile_programs',
        'curriculum_scopes',
        'study_day_configs',
      ];

      String rulesSnippet(List<String> collectionNames) {
        final buffer = StringBuffer()
          ..writeln("rules_version = '2';")
          ..writeln('service cloud.firestore {')
          ..writeln('  match /databases/{database}/documents {')
          ..writeln('    match /users/{uid} {')
          ..writeln('      match /learner_profiles/{profileId} {');
        for (final name in collectionNames) {
          buffer.writeln(
            '        match /$name/{docId} { allow read: if true; }',
          );
        }
        buffer
          ..writeln('      }')
          ..writeln('    }')
          ..writeln('  }')
          ..writeln('}');
        return buffer.toString();
      }

      test(
        'a firestore.rules snippet whose direct children match _kCollections '
        'exactly passes step 0 (normal mode exits 0 with nothing to scan)',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'profile_path_keying_step0_match_',
          );
          try {
            File(
              '${tempDir.path}/firestore.rules',
            ).writeAsStringSync(rulesSnippet(realCollections));

            final result = await run([
              '--root',
              tempDir.path,
              '--baseline',
              '${tempDir.path}/baseline.txt',
            ]);
            expect(
              result.exitCode,
              0,
              reason:
                  'a matching registry with no lib/functions trees to scan '
                  'must pass cleanly.\nstdout=${result.stdout}\n'
                  'stderr=${result.stderr}',
            );
            expect(result.stderr.toString(), isNot(contains('DRIFTED APART')));
          } finally {
            await tempDir.delete(recursive: true);
          }
        },
      );

      test('a firestore.rules snippet missing collections that _kCollections '
          'has FAILS step 0 with exit 1 in normal mode, naming the symmetric '
          'difference', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'profile_path_keying_step0_drift_',
        );
        try {
          // Deliberately drifted: only 2 of the 17 real collections.
          File('${tempDir.path}/firestore.rules').writeAsStringSync(
            rulesSnippet(const ['completions', 'streak_events']),
          );

          final result = await run([
            '--root',
            tempDir.path,
            '--baseline',
            '${tempDir.path}/baseline.txt',
          ]);
          expect(
            result.exitCode,
            1,
            reason:
                'a drifted registry must hard-fail step 0 before any '
                'bucket-scanning runs.\nstdout=${result.stdout}\n'
                'stderr=${result.stderr}',
          );
          expect(
            result.stderr.toString(),
            allOf(
              contains('DRIFTED APART'),
              contains('bookmarks'),
              contains('learning_order'),
            ),
            reason:
                'the failure must name the collections missing from '
                '_kCollections (or extra in it).\nstderr=${result.stderr}',
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      });

      test(
        'the SAME drifted firestore.rules still exits 0 under --report, but '
        'surfaces the drift in stdout instead of silently continuing',
        () async {
          final tempDir = await Directory.systemTemp.createTemp(
            'profile_path_keying_step0_drift_report_',
          );
          try {
            File('${tempDir.path}/firestore.rules').writeAsStringSync(
              rulesSnippet(const ['completions', 'streak_events']),
            );

            final result = await run([
              '--root',
              tempDir.path,
              '--baseline',
              '${tempDir.path}/baseline.txt',
              '--report',
            ]);
            expect(
              result.exitCode,
              0,
              reason:
                  '--report always exits 0, even on a step-0 drift.\n'
                  'stdout=${result.stdout}\nstderr=${result.stderr}',
            );
            expect(
              result.stdout.toString(),
              contains('FAILED (drift detected'),
              reason:
                  '--report must still surface the drift, not silently '
                  'continue as if step 0 passed.\nstdout=${result.stdout}',
            );
          } finally {
            await tempDir.delete(recursive: true);
          }
        },
      );

      test('a missing firestore.rules file hard-fails step 0 (normal mode) '
          'rather than silently skipping the registry check', () async {
        final tempDir = await Directory.systemTemp.createTemp(
          'profile_path_keying_step0_missing_',
        );
        try {
          final result = await run([
            '--root',
            tempDir.path,
            '--baseline',
            '${tempDir.path}/baseline.txt',
          ]);
          expect(result.exitCode, 1);
          expect(result.stderr.toString(), contains('could not read/parse'));
        } finally {
          await tempDir.delete(recursive: true);
        }
      });
    },
  );

  group('tool/check_profile_path_keying.dart — comment-stripping literal '
      'matcher', () {
    test('a real code touch is counted; a comment-only mention is not; a '
        'longer-token near-miss is not (word-bounded by the surrounding '
        'quotes)', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_matcher_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        File(
          '${tempDir.path}/collections.txt',
        ).writeAsStringSync('bookmarks\n');
        File('${tempDir.path}/lib/core/sync/fixture.dart').writeAsStringSync(
          "const bookmarkTouch = 'bookmarks';\n" // line 1: code touch
          '// mentions bookmarks in prose\n' // line 2: comment-only, no touch
          "const another = 'bookmarks'; // also mentions bookmarks here\n" // line 3: code touch (before //)
          "const notMatched = 'bookmarks2';\n", // line 4: no touch (word-bounded)
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(
          result.exitCode,
          0,
          reason: 'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        final stdout = result.stdout.toString();
        expect(
          stdout,
          contains('INT-A (lib/core/sync/**): 2 touch(es)'),
          reason:
              'exactly 2 code touches expected (lines 1 and 3).\n'
              'stdout=$stdout',
        );
        expect(stdout, contains('fixture.dart:1'));
        expect(stdout, contains('fixture.dart:3'));
        expect(
          stdout,
          isNot(contains('fixture.dart:2')),
          reason:
              'a mention that exists ONLY inside a `//` comment must not '
              'count as a touch.\nstdout=$stdout',
        );
        expect(
          stdout,
          isNot(contains('fixture.dart:4')),
          reason:
              "'bookmarks2' must not match the 'bookmarks' quoted-token "
              'pattern.\nstdout=$stdout',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('tool/check_profile_path_keying.dart — 2-hop reachability', () {
    /// Builds a minimal synthetic tree at `$root` with:
    ///  - `lib/core/sync/fixture_sync.dart` touching every name in
    ///    [collectionNames] (so intTouch is always true — the reachability
    ///    algorithm itself is what's under test, not the INT buckets).
    ///  - `lib/data/firestore/repository_providers.dart` wiring one
    ///    `final firestore<Name>RepositoryProvider = FutureProvider(...
    ///    return Firestore<Name>Repository(...))` per collection.
    ///  - `lib/data/repositories/firestore_<name>_repository.dart` per
    ///    collection, each touching its own collection name literal.
    Future<Directory> buildBaseFixture(
      String tempPrefix,
      List<String> collectionNames,
    ) async {
      final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
      Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
      Directory(
        '${tempDir.path}/lib/data/repositories',
      ).createSync(recursive: true);
      Directory(
        '${tempDir.path}/lib/data/firestore',
      ).createSync(recursive: true);

      final syncBuffer = StringBuffer();
      final providersBuffer = StringBuffer();
      for (final name in collectionNames) {
        final pascal = name
            .split('_')
            .map((w) => w[0].toUpperCase() + w.substring(1))
            .join();
        syncBuffer.writeln("const _touch$pascal = '$name';");
        providersBuffer
          ..writeln('final firestore${pascal}RepositoryProvider =')
          ..writeln(
            '    FutureProvider<Firestore${pascal}Repository?>((ref) async {',
          )
          ..writeln('      return Firestore${pascal}Repository();')
          ..writeln('    });')
          ..writeln();

        File(
          '${tempDir.path}/lib/data/repositories/firestore_${name}_repository.dart',
        ).writeAsStringSync(
          'class Firestore${pascal}Repository {\n'
          "  void touch() { const c = '$name'; }\n"
          '}\n',
        );
      }
      File(
        '${tempDir.path}/lib/core/sync/fixture_sync.dart',
      ).writeAsStringSync(syncBuffer.toString());
      File(
        '${tempDir.path}/lib/data/firestore/repository_providers.dart',
      ).writeAsStringSync(providersBuffer.toString());
      File(
        '${tempDir.path}/collections.txt',
      ).writeAsStringSync(collectionNames.join('\n'));
      return tempDir;
    }

    test('LIVE 1-hop: a repository referenced directly by a presentation '
        'provider (outside data/repositories/) is LIVE', () async {
      final tempDir = await buildBaseFixture(
        'profile_path_keying_hop1_live_',
        const ['live_one_hop_coll'],
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          'void useIt() {\n'
          '  firestoreLiveOneHopCollRepositoryProvider;\n'
          '}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
        ]);
        expect(
          result.exitCode,
          1,
          reason:
              'a fresh LIVE split outside the (empty) baseline must fail.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stderr.toString(), contains('live_one_hop_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('LIVE 2-hop: a repository whose Adapter class (declared inside '
        'data/repositories/) is constructed from a presentation provider '
        'is LIVE', () async {
      final tempDir = await buildBaseFixture(
        'profile_path_keying_hop2_live_',
        const ['live_two_hop_coll'],
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/data/repositories',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/data/repositories/impl.dart',
        ).writeAsStringSync(
          'class FirestoreLiveTwoHopCollRepositoryAdapter {\n'
          '  FirestoreLiveTwoHopCollRepositoryAdapter({required this.ref});\n'
          '  final Object ref;\n'
          '  void useProvider() {\n'
          '    firestoreLiveTwoHopCollRepositoryProvider;\n'
          '  }\n'
          '}\n',
        );
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          'void wireIt() {\n'
          '  FirestoreLiveTwoHopCollRepositoryAdapter(ref: null);\n'
          '}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        expect(
          result.stdout.toString(),
          contains('currentSplits: live_two_hop_coll'),
          reason:
              'HOP1 alone must not find it (adapter is inside '
              'data/repositories/); HOP2 must, via the Adapter class '
              'construction.\nstdout=${result.stdout}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'DEAD: an Adapter class that exists but is constructed nowhere '
      'outside data/repositories/ exhausts both hops and does not enter '
      'the liveness-filtered ULID-C bucket (though it IS watchlisted)',
      () async {
        final tempDir = await buildBaseFixture(
          'profile_path_keying_hop_dead_',
          const ['dead_coll'],
        );
        try {
          Directory(
            '${tempDir.path}/lib/features/foo/data/repositories',
          ).createSync(recursive: true);
          // The adapter exists and references the provider, but nothing
          // outside data/repositories/ ever constructs the adapter itself.
          File(
            '${tempDir.path}/lib/features/foo/data/repositories/impl.dart',
          ).writeAsStringSync(
            'class FirestoreDeadCollRepositoryAdapter {\n'
            '  FirestoreDeadCollRepositoryAdapter({required this.ref});\n'
            '  final Object ref;\n'
            '  void useProvider() {\n'
            '    firestoreDeadCollRepositoryProvider;\n'
            '  }\n'
            '}\n',
          );

          final result = await run([
            '--root',
            tempDir.path,
            '--collections',
            '${tempDir.path}/collections.txt',
            '--baseline',
            '${tempDir.path}/baseline.txt',
          ]);
          expect(
            result.exitCode,
            0,
            reason:
                'a DEAD repository must never enter currentSplits, so the '
                'empty baseline still passes.\nstdout=${result.stdout}\n'
                'stderr=${result.stderr}',
          );
          expect(
            result.stdout.toString(),
            contains('WATCHLIST: dead_coll'),
            reason:
                'a DEAD repo opposite a live INT writer must still be '
                'watchlisted (never a silent blind spot).\n'
                'stdout=${result.stdout}',
          );
        } finally {
          await tempDir.delete(recursive: true);
        }
      },
    );
  });

  group('tool/check_profile_path_keying.dart — F1 (ULID-C also scans '
      'lib/features/**/data/repositories/**)', () {
    test('a raw touch inside lib/features/foo/data/repositories/ — a '
        'NON-`firestore_`-prefixed filename, the sanctioned migration seam '
        '(audit check 102) — is scanned and, once reachable via classic '
        'HOP 1 (provider-identifier reference), enters currentSplits; the '
        'pre-fix checker only ever scanned lib/data/repositories/firestore_'
        '*.dart and would have missed this file entirely', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f1_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/features/foo/data/repositories',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/data/firestore',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/lib/core/sync/fixture_sync.dart',
        ).writeAsStringSync("const _touch = 'f1_coll';\n");
        // Deliberately NOT named `firestore_*.dart` — the old filename
        // heuristic could never have matched this.
        File(
          '${tempDir.path}/lib/features/foo/data/repositories/some_impl.dart',
        ).writeAsStringSync(
          'class FirestoreF1CollRepository {\n'
          "  void touch() { const c = 'f1_coll'; }\n"
          '}\n',
        );
        File(
          '${tempDir.path}/lib/data/firestore/repository_providers.dart',
        ).writeAsStringSync(
          'final firestoreF1CollRepositoryProvider =\n'
          '    FutureProvider<FirestoreF1CollRepository?>((ref) async {\n'
          '      return FirestoreF1CollRepository();\n'
          '    });\n',
        );
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          'void useIt() {\n'
          '  firestoreF1CollRepositoryProvider;\n'
          '}\n',
        );
        File('${tempDir.path}/collections.txt').writeAsStringSync('f1_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
        ]);
        expect(
          result.exitCode,
          1,
          reason:
              'a fresh LIVE split found only via the widened '
              'lib/features/**/data/repositories/ scan must fail against '
              'an empty baseline.\nstdout=${result.stdout}\n'
              'stderr=${result.stderr}',
        );
        expect(result.stderr.toString(), contains('f1_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('tool/check_profile_path_keying.dart — F2 (HOP 1B: direct '
      'construction, independent of provider wiring)', () {
    test('a class constructed directly outside data/repositories/, with NO '
        'provider entry for it anywhere, is still detected LIVE — the '
        r'pre-fix checker only ever grepped for the `$xRepositoryProvider` '
        'identifier and would have reported this DEAD forever', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f2_live_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/data/repositories',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/widgets',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/lib/core/sync/fixture_sync.dart',
        ).writeAsStringSync("const _touch = 'f2_coll';\n");
        File(
          '${tempDir.path}/lib/data/repositories/firestore_f2_coll_repository.dart',
        ).writeAsStringSync(
          'class FirestoreF2CollRepository {\n'
          "  void touch() { const c = 'f2_coll'; }\n"
          '}\n',
        );
        // No lib/data/firestore/repository_providers.dart at all — there is
        // NO provider indirection to find. Only a direct construction.
        File(
          '${tempDir.path}/lib/features/foo/presentation/widgets/direct_build.dart',
        ).writeAsStringSync(
          'void build() {\n'
          '  FirestoreF2CollRepository();\n'
          '}\n',
        );
        File('${tempDir.path}/collections.txt').writeAsStringSync('f2_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        expect(
          result.stdout.toString(),
          allOf(contains('HOP1B LIVE'), contains('currentSplits: f2_coll')),
          reason:
              'direct construction with zero provider wiring must resolve '
              'LIVE via HOP 1B.\nstdout=${result.stdout}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('the SAME class, declared but constructed NOWHERE (not even '
        'directly), stays DEAD — HOP 1B does not manufacture false '
        'positives for a genuinely dormant class', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f2_dead_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/data/repositories',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/lib/core/sync/fixture_sync.dart',
        ).writeAsStringSync("const _touch = 'f2_dead_coll';\n");
        File(
          '${tempDir.path}/lib/data/repositories/firestore_f2_dead_coll_repository.dart',
        ).writeAsStringSync(
          'class FirestoreF2DeadCollRepository {\n'
          "  void touch() { const c = 'f2_dead_coll'; }\n"
          '}\n',
        );
        File(
          '${tempDir.path}/collections.txt',
        ).writeAsStringSync('f2_dead_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
        ]);
        expect(
          result.exitCode,
          0,
          reason:
              'a class constructed nowhere at all must stay DEAD.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stdout.toString(), contains('WATCHLIST: f2_dead_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('tool/check_profile_path_keying.dart — F3 (Dart 3 class modifiers)', () {
    test('a `final class Firestore*Repository` declaration is recognized '
        'as the primary class (not "(unknown)") and resolves LIVE via '
        'classic HOP 1 exactly like a bare `class` would — the pre-fix '
        r'regex (`^class\s+...`) never matched a modifier prefix and would '
        'have silently treated this file as having no Firestore class at '
        'all', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f3_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/data/repositories',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/data/firestore',
        ).createSync(recursive: true);
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);

        File(
          '${tempDir.path}/lib/core/sync/fixture_sync.dart',
        ).writeAsStringSync("const _touch = 'f3_coll';\n");
        File(
          '${tempDir.path}/lib/data/repositories/firestore_f3_coll_repository.dart',
        ).writeAsStringSync(
          'final class FirestoreF3CollRepository {\n'
          "  void touch() { const c = 'f3_coll'; }\n"
          '}\n',
        );
        File(
          '${tempDir.path}/lib/data/firestore/repository_providers.dart',
        ).writeAsStringSync(
          'final firestoreF3CollRepositoryProvider =\n'
          '    FutureProvider<FirestoreF3CollRepository?>((ref) async {\n'
          '      return FirestoreF3CollRepository();\n'
          '    });\n',
        );
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          'void useIt() {\n'
          '  firestoreF3CollRepositoryProvider;\n'
          '}\n',
        );
        File('${tempDir.path}/collections.txt').writeAsStringSync('f3_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        final stdout = result.stdout.toString();
        expect(
          stdout,
          isNot(contains('(unknown)')),
          reason:
              'the modifier-prefixed class must be resolved by name, not '
              'fall back to the "no class Firestore... declaration found" '
              'path.\nstdout=$stdout',
        );
        expect(stdout, contains('currentSplits: f3_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('tool/check_profile_path_keying.dart — F4 (torn-read hardening)', () {
    test('a file that is non-empty on disk but decodes to ZERO lines (a '
        'UTF-8-BOM-only file is a real, reproducible instance of this) '
        'aborts the ENTIRE run with a distinct "SUSPECT READ"/"ABORTED" '
        'diagnostic and exit 1 — never silently treated as "this file has '
        'no touches"', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f4_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        File(
          '${tempDir.path}/lib/core/sync/_torn.dart',
        ).writeAsBytesSync(const [0xEF, 0xBB, 0xBF]);
        File(
          '${tempDir.path}/collections.txt',
        ).writeAsStringSync('some_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
        ]);
        expect(result.exitCode, 1);
        expect(
          result.stderr.toString(),
          allOf(contains('SUSPECT READ'), contains('ABORTED')),
          reason: 'stderr=${result.stderr}',
        );
        expect(
          result.stderr.toString(),
          isNot(contains('PROFILE-KEY-SPLIT check FAILED')),
          reason:
              'a torn read must never be presented as a real production '
              'violation.\nstderr=${result.stderr}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('the SAME torn file also aborts under --report — a torn read is '
        'not "safe" just because --report normally always exits 0', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_f4_report_',
      );
      try {
        Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
        File(
          '${tempDir.path}/lib/core/sync/_torn.dart',
        ).writeAsBytesSync(const [0xEF, 0xBB, 0xBF]);
        File(
          '${tempDir.path}/collections.txt',
        ).writeAsStringSync('some_coll\n');

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(
          result.exitCode,
          1,
          reason:
              'unlike every other --report case, a torn read must still '
              'abort with a nonzero exit — a diagnostic dump built on '
              'corrupted content is not safe to print as if it were '
              'real.\nstdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(result.stderr.toString(), contains('SUSPECT READ'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });

  group('tool/check_profile_path_keying.dart — F5 (comment/string-literal '
      'stripping for reachability matching)', () {
    /// Builds the same shape of minimal fixture as the "2-hop reachability"
    /// group above (INT-A touch + provider wiring + a raw ULID-C file with
    /// its own literal touch), but WITHOUT any real reference to the
    /// provider identifier anywhere outside data/repositories/ — callers
    /// add exactly one decoy line (a comment or string literal mentioning
    /// the provider id) to prove it does NOT count.
    Future<Directory> buildDormantFixture(
      String tempPrefix,
      String collectionName,
      String pascalName,
    ) async {
      final tempDir = await Directory.systemTemp.createTemp(tempPrefix);
      Directory('${tempDir.path}/lib/core/sync').createSync(recursive: true);
      Directory(
        '${tempDir.path}/lib/data/repositories',
      ).createSync(recursive: true);
      Directory(
        '${tempDir.path}/lib/data/firestore',
      ).createSync(recursive: true);
      File(
        '${tempDir.path}/lib/core/sync/fixture_sync.dart',
      ).writeAsStringSync("const _touch = '$collectionName';\n");
      File(
        '${tempDir.path}/lib/data/firestore/repository_providers.dart',
      ).writeAsStringSync(
        'final firestore${pascalName}RepositoryProvider =\n'
        '    FutureProvider<Firestore${pascalName}Repository?>((ref) async {\n'
        '      return Firestore${pascalName}Repository();\n'
        '    });\n',
      );
      File(
        '${tempDir.path}/lib/data/repositories/firestore_${collectionName}_repository.dart',
      ).writeAsStringSync(
        'class Firestore${pascalName}Repository {\n'
        "  void touch() { const c = '$collectionName'; }\n"
        '}\n',
      );
      File(
        '${tempDir.path}/collections.txt',
      ).writeAsStringSync('$collectionName\n');
      return tempDir;
    }

    test('a provider identifier mentioned ONLY in a `///` doc comment '
        'outside data/repositories/ stays DEAD — reproduced against the '
        'real tree pre-fix: 8 of the 10 non-declaration occurrences of '
        'firestoreBookmarkRepositoryProvider in lib/** are exactly this '
        'shape (see the library doc comment\'s F5 section)', () async {
      final tempDir = await buildDormantFixture(
        'profile_path_keying_f5_doccomment_',
        'f5_doc_coll',
        'F5DocColl',
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          '/// Mentions `firestoreF5DocCollRepositoryProvider` in prose only —\n'
          '/// not a real reference.\n'
          'void noop() {}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        final stdout = result.stdout.toString();
        expect(
          stdout,
          contains('currentSplits: '),
          reason:
              'currentSplits must be empty (no collection name after '
              'the colon).\nstdout=$stdout',
        );
        expect(
          stdout,
          isNot(contains('currentSplits: f5_doc_coll')),
          reason:
              'a doc-comment-only mention must NOT be treated as a live '
              'reference — pre-fix this alone made HOP1 report LIVE.\n'
              'stdout=$stdout',
        );
        expect(stdout, contains('DEAD ULID-C candidate'));
        expect(stdout, contains('WATCHLIST: f5_doc_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('a provider identifier mentioned ONLY inside a string literal '
        '(e.g. an exception message) outside data/repositories/ also stays '
        'DEAD — modeled on the real '
        'BookmarkRepositoryNotReadyException.toString() in '
        'bookmark_repository_impl.dart, which embeds '
        'firestoreBookmarkRepositoryProvider inside a plain string message '
        '(P2-10: no longer citing a specific line number here — the exact '
        'line drifts every time that file is edited; the shape being '
        'tested, a provider name inside an exception toString(), is the '
        'durable fact)', () async {
      final tempDir = await buildDormantFixture(
        'profile_path_keying_f5_string_',
        'f5_string_coll',
        'F5StringColl',
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          'void noop() {\n'
          "  throw Exception('firestoreF5StringCollRepositoryProvider "
          "resolved to null');\n"
          '}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        final stdout = result.stdout.toString();
        expect(
          stdout,
          isNot(contains('currentSplits: f5_string_coll')),
          reason:
              'a string-literal-only mention must NOT be treated as a live '
              'reference.\nstdout=$stdout',
        );
        expect(stdout, contains('WATCHLIST: f5_string_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('a provider identifier mentioned ONLY inside a `/* ... */` block '
        'comment spanning multiple lines also stays DEAD', () async {
      final tempDir = await buildDormantFixture(
        'profile_path_keying_f5_blockcomment_',
        'f5_block_coll',
        'F5BlockColl',
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          '/* mentions firestoreF5BlockCollRepositoryProvider spanning\n'
          '   multiple lines of a block comment */\n'
          'void noop() {}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        final stdout = result.stdout.toString();
        expect(
          stdout,
          isNot(contains('currentSplits: f5_block_coll')),
          reason:
              'a mention inside a multi-line block comment must NOT be '
              'treated as a live reference.\nstdout=$stdout',
        );
        expect(stdout, contains('WATCHLIST: f5_block_coll'));
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('a genuine reference is still detected LIVE even with a decoy '
        'comment mentioning the SAME provider id elsewhere — the stripper '
        'must not over-strip real code', () async {
      final tempDir = await buildDormantFixture(
        'profile_path_keying_f5_live_guard_',
        'f5_live_coll',
        'F5LiveColl',
      );
      try {
        Directory(
          '${tempDir.path}/lib/features/foo/presentation/providers',
        ).createSync(recursive: true);
        File(
          '${tempDir.path}/lib/features/foo/presentation/providers/wiring.dart',
        ).writeAsStringSync(
          '/// Also mentions `firestoreF5LiveCollRepositoryProvider` here, in '
          'prose.\n'
          'void useIt() {\n'
          '  firestoreF5LiveCollRepositoryProvider; // and here, trailing\n'
          '}\n',
        );

        final result = await run([
          '--root',
          tempDir.path,
          '--collections',
          '${tempDir.path}/collections.txt',
          '--baseline',
          '${tempDir.path}/baseline.txt',
          '--report',
        ]);
        expect(result.exitCode, 0, reason: '--report always exits 0');
        final stdout = result.stdout.toString();
        expect(
          stdout,
          allOf(contains('HOP1 LIVE'), contains('currentSplits: f5_live_coll')),
          reason:
              'the real reference on the code line must still be found '
              'even though a doc comment above it and a trailing comment '
              'after it mention the same identifier.\nstdout=$stdout',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
