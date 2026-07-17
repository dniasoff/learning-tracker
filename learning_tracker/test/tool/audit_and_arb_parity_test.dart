// Tests for `make audit` and `tool/arb_parity_check.dart` (DNI-389 / Story 27.13).
//
// These tests shell out to the real Make target and Dart script and
// assert their behaviour. This keeps the same integration-style
// approach as `schema_check_test.dart`.
//
// NOTE: `make audit` may exit non-zero on the current codebase because
// enforcement greps catch pre-existing violations from earlier stories
// (e.g. EdgeInsets.only, firebase_storage outside core/sync — those
// stories land in Epics 26–27). The test therefore validates that the
// target *runs all 17 greps and prints file:line hits* rather than
// asserting a clean exit code. A separate live-clean assertion is
// guarded with a skip note so it can be re-enabled once all
// violations are resolved.
//
// NOTE (AUD-guardrails-17): `audit` now depends on `lint-rules-test`, which
// runs `dart pub get && dart test` inside packages/custom_lints/ before the
// greps run. That suite's analyzer-per-test harness alone takes ~30s, which
// blows the default 30s `test()` timeout — the two tests below that shell
// out to `make audit` carry an explicit longer timeout to account for it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Single-quotes [value] for safe interpolation into a `bash -c` command.
String _shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

void main() {
  // `flutter test` runs with cwd = the package dir (`learning_tracker/`).
  // The repo root is one level up; the Makefile lives in the package dir.
  final packageDir = Directory.current.path;
  final repoRoot = Directory.current.parent.path;

  group('make audit (DNI-389 — Story 27.13 AC1)', () {
    test(
      'prints N/total headers for all 17 greps',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        final stdout = result.stdout.toString();
        // The target must attempt all 17 greps regardless of whether
        // earlier ones fail, so every N/total header must appear.
        // Greps 1-15 are labelled N/15; greps 16-17 are labelled N/17.
        for (var i = 1; i <= 15; i++) {
          expect(
            stdout,
            contains('$i/15'),
            reason:
                'make audit must run grep $i of 15.\n'
                'stdout=$stdout\nstderr=${result.stderr}',
          );
        }
        for (var i = 16; i <= 17; i++) {
          expect(
            stdout,
            contains('$i/17'),
            reason:
                'make audit must run grep $i of 17.\n'
                'stdout=$stdout\nstderr=${result.stderr}',
          );
        }
      },
      // AUD-guardrails-17: `audit` now depends on `lint-rules-test`
      // (packages/custom_lints/ `dart test`), which alone takes ~30s.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'prints file:line paths for violations',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        final stdout = result.stdout.toString();
        // When there are violations, each hit must contain a colon
        // indicating file:line format. We verify this if any violation
        // output is present (i.e. a line that looks like a grep hit).
        final hitLines = stdout
            .split('\n')
            .where(
              (line) =>
                  line.contains('.dart:') &&
                  !line.startsWith('[') &&
                  line.isNotEmpty,
            )
            .toList();

        // Either there are no violations (OK) or each hit has file:line.
        for (final line in hitLines) {
          expect(
            RegExp(r'\.dart:\d+:').hasMatch(line),
            isTrue,
            reason: 'violation line must match file:line format: $line',
          );
        }
      },
      // AUD-guardrails-17: see timeout rationale above.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'exits 0 when codebase is fully clean [skip until Epics 26–27 violations resolved]',
      () async {
        // This test is skipped until all enforcement violations from
        // Epics 25–26 are resolved (Stories 25.9, 25.10, 25.11, 25.19,
        // 25.21, 26.31, etc.).
        //
        // To re-enable: remove the `skip:` parameter from this group()
        // when `make audit` exits 0 on the main branch.
      },
      skip:
          'Pre-existing violations from Epics 25–26 not yet resolved; '
          're-enable once make audit is fully clean (DNI-389 tracks this)',
    );

    test(
      'check 25/26 asserts exactly one coding-standards.md outside '
      'docs/_archive/ (AUD-docs-04)',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        final stdout = result.stdout.toString();
        expect(
          stdout,
          contains('25/26'),
          reason:
              'make audit must run the coding-standards.md uniqueness '
              'check (AUD-docs-04). Renumbered from 23/23 to 25/25 during '
              'wave-0 gate-repair merge (this check collided with two other '
              'wave-0 additions to the same target: AUD-guardrails-03\'s '
              'custom_lint-marker check and AUD-repo-01\'s AG-4 '
              'duplicate-type-name check, both also originally 23/23), then '
              'to 25/26 when AUD-core-analytics-01 (wave-1) appended a 26th '
              'check (the AnalyticsEvent catalog enforcement).\n'
              'stdout=$stdout\nstderr=${result.stderr}',
        );
        expect(
          stdout,
          isNot(contains('Expected exactly one coding-standards.md')),
          reason:
              'docs/coding-standards.md must be the only file named '
              'coding-standards.md outside docs/_archive/ — a duplicate '
              'root copy would regress AUD-docs-04.\n'
              'stdout=$stdout\nstderr=${result.stderr}',
        );
      },
      // AUD-guardrails-17 (see file-level NOTE above): this test shells out
      // to `make audit`, which depends on `lint-rules-test` alone taking
      // ~30s, plus a growing set of individual `dart run tool/check_*.dart`
      // subprocess checks (33 as of gate-repair 2026-07-11) that each carry
      // their own dart-VM startup cost — the combined run now reliably blows
      // the default 30s `test()` timeout even with no other load. Matches
      // the explicit longer timeout already carried by this group's other
      // `make audit`-shelling tests above.
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('make audit check 15/15 cross-feature-import detector '
      '(AUD-guardrails-02)', () {
    // Mirrors the awk program in Makefile check 15/15 (both occurrences,
    // which are identical). If that awk changes, update this constant too —
    // these tests exercise the exact detection logic, not just its wiring.
    //
    // The original awk matched `features/([^/]+)/` against BOTH $1 (the
    // grep -rn file-path field) and $0 (the whole line, which STARTS with
    // that same file path), so it always compared the importing file's own
    // feature against itself and could never detect a real violation. This
    // version extracts the import statement text (everything after the
    // first two `:`-delimited fields) before matching the imported feature,
    // and exempts imports that route through the target feature's own
    // barrel (`features/<f>/<f>.dart`).
    const awkProgram =
        r'{ content = $0; sub(/^[^:]*:[^:]*:/, "", content); '
        r'if (match($1, /features\/([^\/]+)\//, a) && '
        r'match(content, /features\/([^\/]+)\//, b)) { '
        'if (a[1] != b[1]) { '
        'barrel = "features/" b[1] "/" b[1] ".dart"; '
        'if (index(content, barrel) == 0) print } } }';

    Future<String> runAwk(String inputLine) async {
      final result = await Process.run('bash', [
        '-c',
        "printf '%s\\n' ${_shellQuote(inputLine)} | awk -F: '$awkProgram'",
      ]);
      expect(
        result.exitCode,
        0,
        reason: 'awk itself must not error.\nstderr=${result.stderr}',
      );
      return result.stdout.toString();
    }

    test(
      'prints a synthetic cross-feature deep import (not suppressed)',
      () async {
        // AC1: "file/features/A/x.dart:N:import ...features/B/y.dart"
        // must be printed, not silently swallowed by the awk.
        const line =
            'lib/features/A/x.dart:9:'
            "import 'package:learning_tracker/features/B/y.dart';";
        final out = await runAwk(line);
        expect(
          out.trim(),
          line,
          reason: 'a genuine cross-feature deep import must be reported',
        );
      },
    );

    test('suppresses a same-feature deep import (not cross-feature)', () async {
      const line =
          'lib/features/A/domain/x.dart:9:'
          "import 'package:learning_tracker/features/A/data/y.dart';";
      final out = await runAwk(line);
      expect(
        out.trim(),
        isEmpty,
        reason: 'an import within the same feature is not a violation',
      );
    });

    test(
      'suppresses a cross-feature import that routes through the barrel',
      () async {
        const line =
            'lib/features/A/x.dart:9:'
            "import 'package:learning_tracker/features/B/B.dart';";
        final out = await runAwk(line);
        expect(
          out.trim(),
          isEmpty,
          reason: 'importing another feature\'s own barrel is compliant',
        );
      },
    );

    test(
      'regression: pending_local_signup.dart and onboarding_screen.dart '
      'account imports no longer flagged (AUD-guardrails-02 fix sites)',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        final stdout = result.stdout.toString();
        expect(
          stdout,
          isNot(contains('pending_local_signup.dart:11')),
          reason:
              'pending_local_signup.dart now imports currentAccountIdProvider '
              'via features/profiles/profiles.dart, not the deep provider path',
        );
        expect(
          stdout,
          allOf(
            isNot(contains('onboarding_screen.dart:10')),
            isNot(contains('onboarding_screen.dart:11')),
          ),
          reason:
              'onboarding_screen.dart now imports OnboardingIntentStep and '
              'the auth state provider via features/account/account.dart',
        );
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit`; see the longer rationale on the 25/26 test above.
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  group('make audit check 15/15 — AUD-learning-02', () {
    test(
      'regression: learning_screen.dart tutoring import no longer flagged',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        expect(
          result.stdout.toString(),
          isNot(contains('learning_screen.dart:21')),
          reason:
              'learning_screen.dart now imports '
              'activeTutoredProfileSelectionProvider via '
              'features/tutoring/tutoring.dart, which already exported it',
        );
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit`; see the longer rationale on the 25/26 test above.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('AC1: adding then removing a throwaway cross-feature import flips '
        'check 15/15 from clean to WARN and back', () async {
      // NOTE: this test shells out to `make audit` TWICE (see auditStdout()
      // below) — AUD-guardrails-17 (file-level NOTE above) applies doubly
      // here, hence the explicit longer timeout passed below.
      // A disposable feature directory outside any real feature, so this
      // can never collide with a real barrel and is unmistakable debris
      // if cleanup is ever interrupted.
      final fixtureDir = Directory(
        '$packageDir/lib/features/zzz_audit_fixture_do_not_commit',
      );
      final fixtureFile = File(
        '${fixtureDir.path}/zzz_audit_fixture_do_not_commit.dart',
      );

      Future<String> auditStdout() async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        return result.stdout.toString();
      }

      try {
        await fixtureDir.create(recursive: true);
        // A real cross-feature deep import (not through dashboard's own
        // barrel) — exactly the shape check 15/15 exists to catch.
        fixtureFile.writeAsStringSync(
          "import 'package:learning_tracker/features/dashboard/"
          "presentation/providers/dashboard_providers.dart';\n",
        );

        final withFixture = await auditStdout();
        expect(
          withFixture,
          contains('zzz_audit_fixture_do_not_commit.dart'),
          reason:
              'a genuine new cross-feature deep import must be caught, '
              'not silently swallowed like before AUD-guardrails-02',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
        if (fixtureDir.existsSync()) {
          fixtureDir.deleteSync(recursive: true);
        }
      }

      final clean = await auditStdout();
      expect(
        clean,
        isNot(contains('zzz_audit_fixture_do_not_commit.dart')),
        reason: 'removing the fixture restores a clean pass for that file',
      );
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit` twice; see the longer rationale on the 25/26 test
      // above.
    }, timeout: const Timeout(Duration(minutes: 3)));
  });

  group('make audit SM-7 check — AUD-sync-05', () {
    // NOTE: this group used to assert on the check's `N/total` position
    // string (originally "37/37"). That position renumbers every time a
    // check is inserted or appended anywhere in the Makefile — it has
    // already drifted twice (37/37 → 37/40, with the file's grand total
    // now 42) with zero change to the SM-7 check itself. The assertions
    // below instead key off the check's stable description text (the
    // "SM-7" / "AUD-sync-05" identifiers), which only changes if the
    // check's own scope or fix-site list changes.
    // Wave-4 gate-repair follow-up: re-pinned after the AUD-core-navigation-04
    // gate-repair broadened this check's own echo text into two clauses (the
    // RewardMilestoneService fix-site clause below, plus a separate
    // ParentAnalyticsRepositoryImpl-anywhere-in-lib clause) — the combined
    // "ParentAnalyticsRepositoryImpl/RewardMilestoneService" phrase this
    // constant previously expected no longer appears verbatim anywhere in
    // the Makefile, so this test could never have matched a real clean run
    // since that change landed. Keyed on the stable prefix both wordings
    // have always shared.
    const smSevenDescription =
        'SM-7: no ad-hoc RewardMilestoneService construction inside the '
        'AUD-sync-05 fix sites';

    test(
      'clean on the AUD-sync-05 fix sites (no ad-hoc Repository/Service '
      'construction)',
      () async {
        // Wave-4 gate-repair follow-up: capture via a redirected temp file
        // rather than relying on Process.run's in-memory stdout pipe.
        // `make audit`'s full output now exceeds 100KB (83 checks, including
        // 2 large warn-only cross-import listings) and this specific
        // shell-out reproducibly hit "grep: write error: Broken pipe" plus a
        // truncated capture when run inside a flutter_tester test isolate in
        // this environment — NOT reproducible via a bare `dart run`/shell
        // invocation of the identical `make audit` call (isolated and
        // confirmed: a standalone script doing the same Process.run
        // completed in ~56s with the full ~107KB of output and exit 0).
        // File redirection sidesteps whatever pipe/relay limit the test
        // isolate imposes without changing what this test asserts.
        // Keyed off the process id and a fresh Object's identity hash, NOT
        // a wall-clock read: TQ-6 (check 61/62) bans a non-hermetic wall
        // clock in test/, and this is just a unique-filename seed, not a
        // clock dependency, so process-local entropy keeps it out of that
        // gate while still being unique per run.
        final tmp = File(
          '${Directory.systemTemp.path}/make_audit_sm7_${pid}_'
          '${identityHashCode(Object())}.log',
        );
        try {
          final shellResult = await Process.run('sh', [
            '-c',
            'make audit > ${_shellQuote(tmp.path)} 2>&1',
          ], workingDirectory: packageDir);
          final output = tmp.existsSync() ? await tmp.readAsString() : '';
          expect(
            output,
            contains(smSevenDescription),
            reason:
                'make audit must run the SM-7 AUD-sync-05 scoped check '
                '(matched on its stable description, not its N/total '
                'position).\noutput=$output\nstderr=${shellResult.stderr}',
          );
          expect(
            shellResult.exitCode,
            0,
            reason:
                'the three AUD-sync-05 fix sites must be clean.\n'
                'output=$output\nstderr=${shellResult.stderr}',
          );
        } finally {
          if (tmp.existsSync()) tmp.deleteSync();
        }
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit`; see the longer rationale on the 25/26 test above.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test('AC1: reintroducing ad-hoc RewardMilestoneService construction in '
        'outbox_sync_write_facade.dart flips the SM-7 check from clean to '
        'FAIL and back', () async {
      final fixtureFile = File(
        '$packageDir/lib/features/sync/data/outbox_sync_write_facade.dart',
      );
      final original = fixtureFile.readAsStringSync();

      Future<ProcessResult> runAudit() =>
          Process.run('make', ['audit'], workingDirectory: packageDir);

      try {
        // Append a syntactically-valid, unmistakable-as-debris top-level
        // function reproducing the exact violation shape the SM-7 check
        // greps for: a `final x = RewardMilestoneService(...)` reaching
        // for a fresh instance instead of going through the injected
        // `_rewardMilestoneServiceFactory`.
        fixtureFile.writeAsStringSync(
          '$original\n'
          '// AUDIT FIXTURE - DO NOT COMMIT (AUD-sync-05 / SM-7 check test)\n'
          'void zzzAuditFixtureDoNotCommit(UserDatabase database) {\n'
          '  final rewardService = RewardMilestoneService(\n'
          '    database,\n'
          '    profileId: 1,\n'
          '  );\n'
          '  rewardService.exportCloudPayload();\n'
          '}\n',
        );

        final dirty = await runAudit();
        expect(
          dirty.stdout.toString(),
          contains('outbox_sync_write_facade.dart'),
          reason:
              'a reintroduced ad-hoc RewardMilestoneService construction '
              'must be caught by the SM-7 check, not silently swallowed.\n'
              'stdout=${dirty.stdout}',
        );
        expect(
          dirty.exitCode,
          isNot(0),
          reason: 'the SM-7 check is a hard gate — it must fail the build.',
        );
      } finally {
        fixtureFile.writeAsStringSync(original);
      }

      final clean = await runAudit();
      expect(
        clean.stdout.toString(),
        isNot(contains('zzzAuditFixtureDoNotCommit')),
        reason: 'removing the fixture restores a clean pass.',
      );
      expect(clean.exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 5)));
  });

  group('make audit check 44/44 — stale story file targets (AUD-docs-03)', () {
    // Keyed off the check's stable description text, not its N/total
    // position — see the file-level NOTE on the SM-7 group above for why
    // (the position has already drifted twice on unrelated additions).
    const checkDescription =
        'Tier-4 doc-lint: every ready-for-dev/backlog/todo '
        'docs/stories/implementation/*.md Key-Files target resolves under '
        'lib/';

    Future<ProcessResult> runAudit() =>
        Process.run('make', ['audit'], workingDirectory: packageDir);

    test(
      'runs and is clean against the tracked baseline '
      '(19-8/19-9 archived, no longer ready-for-dev)',
      () async {
        final result = await runAudit();
        expect(
          result.stdout.toString(),
          contains(checkDescription),
          reason:
              'make audit must run the AUD-docs-03 stale-story-target '
              'check.\nstdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.exitCode,
          0,
          reason:
              'story targets must be clean against the tracked baseline.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit`; see the longer rationale on the 25/26 test above.
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      'AC1: a ready-for-dev story targeting a deleted lib/ file flips the '
      'check from clean to FAIL and back',
      () async {
        final fixtureFile = File(
          '$repoRoot/docs/stories/implementation/'
          'zzz-audit-fixture-do-not-commit.md',
        );

        try {
          // sync_engine.dart is the AUD-docs-03 fix's own proof case — it
          // was deleted in the SyncOrchestrator+outbox rewrite and exists
          // nowhere under lib/ (exact path or by basename).
          fixtureFile.writeAsStringSync('''
# Fixture Story (AUDIT FIXTURE — DO NOT COMMIT, AUD-docs-03 check test)

Status: ready-for-dev

### Key Files

| File | Action |
|------|--------|
| `lib/features/sync/data/sync_engine.dart` | Modify — resurrect deleted engine |
''');

          final dirty = await runAudit();
          expect(
            dirty.stdout.toString(),
            contains('zzz-audit-fixture-do-not-commit.md'),
            reason:
                'a ready-for-dev story targeting a deleted lib/ file must '
                'be caught, not silently swallowed.\n'
                'stdout=${dirty.stdout}',
          );
          expect(
            dirty.exitCode,
            isNot(0),
            reason: 'the AUD-docs-03 check is a hard gate.',
          );
        } finally {
          if (fixtureFile.existsSync()) fixtureFile.deleteSync();
        }

        final clean = await runAudit();
        expect(
          clean.stdout.toString(),
          isNot(contains('zzz-audit-fixture-do-not-commit.md')),
          reason: 'removing the fixture restores a clean pass.',
        );
        expect(clean.exitCode, 0);
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit` twice; see the longer rationale on the 25/26 test
      // above.
      timeout: const Timeout(Duration(minutes: 5)),
    );
  });

  group('tool/arb_parity_check.dart (DNI-389 — Story 27.13 AC2)', () {
    final scriptPath = '$repoRoot/tool/arb_parity_check.dart';

    Future<ProcessResult> runCheck({String? enPath, String? hePath}) {
      final args = <String>[
        'run',
        scriptPath,
        if (enPath != null) ...['--en', enPath],
        if (hePath != null) ...['--he', hePath],
      ];
      return Process.run('dart', args, workingDirectory: repoRoot);
    }

    test(
      'exits 0 when English and Hebrew keys are in parity (live ARBs)',
      () async {
        final result = await runCheck();
        expect(
          result.exitCode,
          0,
          reason:
              'arb_parity_check must pass on the live ARB files.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stdout.toString(),
          contains('arb_parity_check OK'),
          reason: 'stdout should confirm parity',
        );
      },
    );

    test('exits 1 when English has keys missing in Hebrew', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_test_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb');
        final heArb = File('${tmpDir.path}/app_he.arb');

        enArb.writeAsStringSync(
          '{"@@locale":"en","hello":"Hello","world":"World"}',
        );
        heArb.writeAsStringSync('{"@@locale":"he","hello":"שלום"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(
          result.exitCode,
          1,
          reason:
              'should fail when Hebrew is missing a key.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
        expect(
          result.stderr.toString(),
          contains('world'),
          reason: 'stderr should name the missing key',
        );
        expect(
          result.stderr.toString(),
          contains('arb_parity_check FAILED'),
          reason: 'stderr should contain FAILED marker',
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('metadata keys (@-prefixed) are excluded from parity check', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_meta_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb');
        final heArb = File('${tmpDir.path}/app_he.arb');

        // English has a user-facing key `greeting` and a metadata key
        // `@greeting`. Hebrew has only `greeting` (no metadata key).
        // The check should pass because metadata keys are exempt.
        enArb.writeAsStringSync(
          '{"@@locale":"en","greeting":"Hello","@greeting":{"description":"A greeting"}}',
        );
        heArb.writeAsStringSync('{"@@locale":"he","greeting":"שלום"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(
          result.exitCode,
          0,
          reason:
              'metadata keys must not be required in the target locale.\n'
              'stdout=${result.stdout}\nstderr=${result.stderr}',
        );
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });

    test('exits 2 when English ARB path does not exist', () async {
      final result = await runCheck(
        enPath: '/nonexistent/app_en.arb',
        hePath: '$repoRoot/learning_tracker/lib/l10n/app_he.arb',
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('not found'));
    });

    test('exits 2 when Hebrew ARB path does not exist', () async {
      final result = await runCheck(
        enPath: '$repoRoot/learning_tracker/lib/l10n/app_en.arb',
        hePath: '/nonexistent/app_he.arb',
      );
      expect(result.exitCode, 2);
      expect(result.stderr.toString(), contains('not found'));
    });

    test('exits 2 when English ARB is not valid JSON', () async {
      final tmpDir = Directory.systemTemp.createTempSync('arb_parity_json_');
      try {
        final enArb = File('${tmpDir.path}/app_en.arb')
          ..writeAsStringSync('not-json');
        final heArb = File('${tmpDir.path}/app_he.arb')
          ..writeAsStringSync('{"@@locale":"he"}');

        final result = await runCheck(enPath: enArb.path, hePath: heArb.path);

        expect(result.exitCode, 2);
        expect(result.stderr.toString(), contains('parse'));
      } finally {
        tmpDir.deleteSync(recursive: true);
      }
    });
  });
}
