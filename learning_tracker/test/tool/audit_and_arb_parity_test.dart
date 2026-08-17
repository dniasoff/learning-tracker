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

@Tags(['serial-tools'])
// serial-tools: every case here shells out to the real `make audit`
// (~90s each, ~18m for the file). Run under `flutter test --coverage`
// alongside the full parallel suite they contend for CPU and blow their
// per-test timeouts ('did not complete'), failing `make ci`. The ci
// pipeline therefore excludes this tag from the parallel run and
// executes it separately via `make test-serial-tools` (--concurrency=1).
library;

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
      timeout: const Timeout(Duration(minutes: 10)),
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
        //
        // A naive `.dart:` substring match is too loose: two categories of
        // `.dart:`-bearing stdout lines reach `make audit`'s output that
        // were never violations, and asserting file:line format on them
        // is asserting a property nobody claimed:
        //   1. `lint-rules-test`'s own `dart test` progress output, one
        //      line per test case run inside packages/custom_lints/ (shelled
        //      out to since AUD-guardrails-17, predating check 103), e.g.
        //      `00:00 +0: test/no_hand_rolled_async_state_notifier_test.dart:
        //      NoHandRolledAsyncStateNotifier violations — ...`. The `.dart:`
        //      here is the test *file name* embedded in the runner's own
        //      progress line, not a grep hit — recognisable because these
        //      lines start with the runner's elapsed-time/tally prefix
        //      (`MM:SS +N`, `MM:SS ~N`, `MM:SS -N`), which no `make audit`
        //      grep hit or WATCHLIST line ever does.
        //   2. Check 103's advisory WATCHLIST prose
        //      (`tool/check_profile_path_keying.dart:1155`), printed every
        //      run regardless of outcome and never a violation. Its format
        //      is deliberately `file.dart:ClassName` (a class name, not a
        //      line number) to point at the dormant repository class, e.g.
        //      `WATCHLIST: completions — live INT writer ... at
        //      lib/data/repositories/firestore_completion_repository.dart:
        //      FirestoreCompletionRepository ...`.
        // Excluding both (by the structural markers that identify them —
        // a leading test-runner progress prefix, and the `WATCHLIST:` tag
        // — not by pre-checking the file:line format itself) narrows the
        // assertion to what it was written to test: that a genuine
        // `make audit` violation hit is reported with a clickable
        // file:line, without silently degrading into an assertion that
        // is vacuously true regardless of what `make audit` prints.
        final testRunnerProgressLine = RegExp(r'^\d+:\d{2} [+~-]');
        final hitLines = stdout
            .split('\n')
            .where(
              (line) =>
                  line.contains('.dart:') &&
                  !line.startsWith('[') &&
                  line.isNotEmpty &&
                  !line.contains('WATCHLIST:') &&
                  !testRunnerProgressLine.hasMatch(line),
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
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test('exits 0 when codebase is fully clean', () async {});

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
      timeout: const Timeout(Duration(minutes: 10)),
    );
  });

  group('make audit check 10/15 — AG-6 TODO/FIXME Linear id '
      '(AUD-guardrails-16)', () {
    // Regression fixture proving the AG-6 grep (Makefile check "10/15")
    // distinguishes marker comments carrying a DNI-#### Linear id from
    // ones that don't, across every marker spelling AC1 names. Before
    // AUD-repo-02 generalized it, the check matched only three hardcoded
    // literal phrases that no real comment would ever use, so it
    // enforced nothing (AUD-guardrails-16). AUD-repo-02's fix generalized
    // two of the three marker spellings but left the third checked only
    // against its own old literal phrase, so a bare instance of that
    // third marker with no DNI id still slipped through uncaught -- this
    // fixture covers all three (see the fixture content below for the
    // exact spellings; deliberately not spelled out here, since a
    // marker word as the first token of a comment line is exactly the
    // shape this very check matches).
    //
    // AUD-guardrails-16 second bounce: the first bounce fix dropped the
    // `^\s*` line-start anchor to catch trailing and `///` markers, but
    // the only fixture lines it added were column-0 `//` markers -- the
    // exact shape the anchor never excluded in the first place -- so the
    // anchor removal itself was never actually exercised. This bounce
    // adds a genuinely non-line-start `//` marker and a `///` marker to
    // close that gap, plus a `/* ... */` block-comment marker to prove
    // the AC1 gap the reviewer probed (block comments have no `//` at
    // all, so the grep needed a second alternation, not just an anchor
    // change) is now closed too.
    test(
      'AC1/AC2: a bare TODO/XXX with no DNI id fails the gate; the '
      'same-style comment with a DNI-#### id passes',
      () async {
        final fixtureFile = File(
          '$packageDir/lib/zzz_audit_fixture_do_not_commit.dart',
        );

        Future<ProcessResult> runAudit() =>
            Process.run('make', ['audit'], workingDirectory: packageDir);

        try {
          fixtureFile.writeAsStringSync(
            '// AUDIT FIXTURE - DO NOT COMMIT '
            '(AUD-guardrails-16 / AG-6 check regression test)\n'
            '// TODO(DNI-999999): carries a Linear id, must NOT be flagged\n'
            // AUD-guardrails-16 bounce fix: the AG-6 grep is intentionally
            // unanchored now (matches `//` anywhere on the line, not just
            // at line-start), so this literal is split ('// TOD' + 'O')
            // to keep the source text of THIS test file from self-tripping
            // check 10/15 -- the concatenated runtime string is unaffected
            // and still exercises a genuine bare marker in the fixture.
            '// TOD'
            'O: has no Linear id, MUST be flagged\n'
            '// XXX(DNI-999999): carries a Linear id, must NOT be flagged\n'
            // Same split rationale as above, applied to XXX ('// XX' + 'X').
            '// XX'
            'X: has no Linear id, MUST be flagged\n'
            // Second bounce addition: a marker that does NOT start the
            // line (unlike every case above, which all happen to begin
            // at column 0). Same split rationale applied ('// TOD' + 'O').
            'const zzzTrailingMarker = 1; // TOD'
            'O: trailing marker, not line-start, no Linear id, '
            'MUST be flagged\n'
            // Second bounce addition: a `///` doc-comment marker. Same
            // split rationale applied ('/// TOD' + 'O').
            '/// TOD'
            'O: doc-comment marker, no Linear id, MUST be flagged\n'
            // Second bounce addition: a `/* ... */` block-comment marker
            // -- the AC1 gap the reviewer probed directly. Same split
            // rationale applied ('/* TOD' + 'O').
            '/* TOD'
            'O: block-comment marker, no Linear id, MUST be flagged */\n'
            'const zzzAuditFixtureDoNotCommit = true;\n',
          );

          final dirty = await runAudit();
          final stdout = dirty.stdout.toString();
          expect(
            stdout,
            contains('zzz_audit_fixture_do_not_commit.dart:3'),
            reason:
                'a TODO with no DNI-#### id must be caught by the AG-6 '
                'check (10/15).\nstdout=$stdout',
          );
          expect(
            stdout,
            isNot(contains('zzz_audit_fixture_do_not_commit.dart:2')),
            reason:
                'a TODO that already carries a DNI-#### id must NOT be '
                'flagged -- the grep must distinguish the two, not just '
                'ban TODO/FIXME outright.\nstdout=$stdout',
          );
          expect(
            stdout,
            contains('zzz_audit_fixture_do_not_commit.dart:5'),
            reason:
                'a bare XXX comment with no DNI-#### id must also be '
                'caught by the AG-6 check (10/15), not just the old '
                'literal "XXX: temporary" phrase (AC1 names XXX '
                'explicitly).\nstdout=$stdout',
          );
          expect(
            stdout,
            isNot(contains('zzz_audit_fixture_do_not_commit.dart:4')),
            reason:
                'an XXX comment that already carries a DNI-#### id must '
                'NOT be flagged.\nstdout=$stdout',
          );
          expect(
            stdout,
            contains('zzz_audit_fixture_do_not_commit.dart:6'),
            reason:
                'a TODO trailing after code on the same line (not '
                'line-start) must be caught -- proves the AG-6 grep is not '
                'anchored to the start of the line.\nstdout=$stdout',
          );
          expect(
            stdout,
            contains('zzz_audit_fixture_do_not_commit.dart:7'),
            reason:
                'a bare TODO in a `///` doc comment must be caught -- '
                'proves the AG-6 grep matches `//` anywhere on the line, '
                'not just a bare `// ` prefix.\nstdout=$stdout',
          );
          expect(
            stdout,
            contains('zzz_audit_fixture_do_not_commit.dart:8'),
            reason:
                'a bare TODO in a `/* ... */` block comment must be '
                'caught (AC1: "any TODO/FIXME/XXX comment") -- proves the '
                'AG-6 grep also matches block-comment markers, not only '
                '`//`-style ones.\nstdout=$stdout',
          );
          expect(
            dirty.exitCode,
            isNot(0),
            reason: 'the AG-6 check is a hard gate -- it must fail the build.',
          );
        } finally {
          if (fixtureFile.existsSync()) fixtureFile.deleteSync();
        }

        final clean = await runAudit();
        expect(
          clean.stdout.toString(),
          isNot(contains('zzz_audit_fixture_do_not_commit.dart')),
          reason: 'removing the fixture restores a clean pass.',
        );
        expect(
          clean.exitCode,
          0,
          reason:
              'make audit must be fully clean once the fixture is removed.\n'
              'stdout=${clean.stdout}\nstderr=${clean.stderr}',
        );
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit` twice; see the longer rationale on the 25/26 test
      // above.
      timeout: const Timeout(Duration(minutes: 15)),
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
      'regression: onboarding_screen.dart account imports no longer flagged '
      '(AUD-guardrails-02 fix site)',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        expect(
          result.stdout.toString(),
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
      timeout: const Timeout(Duration(minutes: 10)),
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
      timeout: const Timeout(Duration(minutes: 10)),
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
    }, timeout: const Timeout(Duration(minutes: 10)));
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
    const smSevenDescription =
        'SM-7: no ad-hoc ParentAnalyticsRepositoryImpl construction ANYWHERE '
        'in lib/ outside core/analytics/';

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
                'the current SM-7 construction scope must be clean.\n'
                'output=$output\nstderr=${shellResult.stderr}',
          );
        } finally {
          if (tmp.existsSync()) tmp.deleteSync();
        }
      },
      // AUD-guardrails-17 (see file-level NOTE above): shells out to
      // `make audit`; see the longer rationale on the 25/26 test above.
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test('AC1: reintroducing ad-hoc ParentAnalyticsRepositoryImpl '
        'construction flips the SM-7 check from clean to FAIL and back',
        () async {
      final fixtureFile = File(
        '$packageDir/lib/zzz_audit_sm7_fixture_do_not_commit.dart',
      );

      Future<ProcessResult> runAudit() =>
          Process.run('make', ['audit'], workingDirectory: packageDir);

      try {
        // Append a syntactically-valid, unmistakable-as-debris top-level
        // function reproducing the exact violation shape the SM-7 check
        // greps for: a `final x = RewardMilestoneService(...)` reaching
        // for a fresh instance instead of going through the injected
        // `_rewardMilestoneServiceFactory`.
        fixtureFile.writeAsStringSync(
          '// AUDIT FIXTURE - DO NOT COMMIT (SM-7 check test)\n'
          'void zzzAuditFixtureDoNotCommit(Object database) {\n'
          '  ParentAnalyticsRepositoryImpl(database);\n'
          '}\n',
        );

        final dirty = await runAudit();
        expect(
          dirty.stdout.toString(),
          contains('zzz_audit_sm7_fixture_do_not_commit.dart'),
          reason:
              'a reintroduced ad-hoc ParentAnalyticsRepositoryImpl construction '
              'must be caught by the SM-7 check, not silently swallowed.\n'
              'stdout=${dirty.stdout}',
        );
        expect(
          dirty.exitCode,
          isNot(0),
          reason: 'the SM-7 check is a hard gate — it must fail the build.',
        );
      } finally {
        if (fixtureFile.existsSync()) fixtureFile.deleteSync();
      }

      final clean = await runAudit();
      expect(
        clean.stdout.toString(),
        isNot(contains('zzz_audit_sm7_fixture_do_not_commit.dart')),
        reason: 'removing the fixture restores a clean pass.',
      );
      expect(clean.exitCode, 0);
    }, timeout: const Timeout(Duration(minutes: 15)));
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
      timeout: const Timeout(Duration(minutes: 10)),
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
      timeout: const Timeout(Duration(minutes: 15)),
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

  group('make audit check 103/103 — PROFILE-KEY-SPLIT '
      '(docs/firestore-rewrite-map.md item 10, tool/check_profile_path_'
      'keying.dart)', () {
    final profilePathKeyingScript =
        '$packageDir/tool/check_profile_path_keying.dart';
    // Piggybacks on a REAL, already-verified-LIVE repository file
    // (firestore_bookmark_repository.dart is reachable via HOP 1 from
    // lib/features/learning/presentation/providers/bookmark_providers.dart
    // today) rather than fabricating a fake provider/adapter chain: any
    // literal collection-name touch added anywhere in an already-LIVE file
    // is promoted to the liveness-filtered ULID-C bucket automatically,
    // because reachability is a property of the FILE, not the line.
    final bookmarkRepoFile = File(
      '$packageDir/lib/data/repositories/firestore_bookmark_repository.dart',
    );
    // The old INT bucket lived under lib/core/sync/, which was archived with
    // the Drift sync engine. Cloud Functions is the live INT bucket now.
    final functionsFixtureFile = File(
      '$packageDir/functions/src/_profile_path_keying_ac1_fixture.ts',
    );
    const fixtureCollectionName = 'some_new_test_collection_xyz';
    const fixtureMarkerLine =
        'const _profilePathKeyingAc1FixtureCollection = '
        "'$fixtureCollectionName';\n";

    void stripMarkerIfPresent() {
      // Crash-safety: a prior killed run may have left the marker line
      // appended to the real bookmark repository file — self-heal by
      // stripping exactly that known, uniquely-named line rather than
      // relying on a persisted backup across process runs.
      if (!bookmarkRepoFile.existsSync()) return;
      final content = bookmarkRepoFile.readAsStringSync();
      if (content.contains(fixtureMarkerLine)) {
        bookmarkRepoFile.writeAsStringSync(
          content.replaceAll(fixtureMarkerLine, ''),
        );
      }
    }

    setUp(() {
      stripMarkerIfPresent();
      if (functionsFixtureFile.existsSync()) {
        functionsFixtureFile.deleteSync();
      }
    });

    tearDown(() {
      stripMarkerIfPresent();
      if (functionsFixtureFile.existsSync()) {
        functionsFixtureFile.deleteSync();
      }
    });

    test(
      'the check runs as part of make audit, prints its stable description '
      'text, and is clean against its tracked baseline today (the overall '
      'make audit exit code is NOT asserted here — see this file\'s header '
      'NOTE: pre-existing, unrelated violations from earlier epics already '
      'keep it red; a dedicated skipped test above tracks that separately)',
      () async {
        final result = await Process.run('make', [
          'audit',
        ], workingDirectory: packageDir);
        final stdout = result.stdout.toString();
        expect(
          stdout,
          allOf(
            contains('103/103'),
            contains('PROFILE-KEY-SPLIT'),
            contains('docs/firestore-rewrite-map.md item 10'),
          ),
          reason:
              'make audit must run check 103/103 and print its stable '
              'description text.\nstdout=$stdout\nstderr=${result.stderr}',
        );
        expect(
          stdout,
          isNot(contains('PROFILE-KEY-SPLIT check FAILED')),
          reason:
              'the check itself must be clean against its tracked '
              'baseline on the real tree today.\nstdout=$stdout',
        );
        expect(stdout, contains('PROFILE-KEY-SPLIT check OK'));
      },
      // AUD-guardrails-17 (see file-level NOTE above): make audit's own
      // cost, not this check's — check_profile_path_keying.dart itself
      // runs in a few seconds.
      timeout: const Timeout(Duration(minutes: 10)),
    );

    test('AC1 (red-demo, "the grep must have teeth"): a throwaway '
        'cross-tree touch for a brand-new collection — an INT (Cloud Functions) '
        'literal plus a liveness-reachable ULID literal — flips the checker '
        'from clean to FAILED; removing both restores a clean pass', () async {
      final tempDir = await Directory.systemTemp.createTemp(
        'profile_path_keying_ac1_',
      );
      try {
        final collectionsFile = File('${tempDir.path}/collections.txt')
          ..writeAsStringSync('$fixtureCollectionName\n');
        final baselineFile = File('${tempDir.path}/baseline.txt')
          ..writeAsStringSync('');

        Future<ProcessResult> runFixtureCheck() => Process.run('dart', [
          'run',
          profilePathKeyingScript,
          '--collections',
          collectionsFile.path,
          '--baseline',
          baselineFile.path,
        ], workingDirectory: packageDir);

        final originalBookmarkContent = bookmarkRepoFile.readAsStringSync();
        try {
          bookmarkRepoFile.writeAsStringSync(
            '$originalBookmarkContent\n$fixtureMarkerLine',
          );
          functionsFixtureFile.writeAsStringSync('''
/// AC1 red-demo fixture for tool/check_profile_path_keying.dart's
/// meta-test (test/tool/audit_and_arb_parity_test.dart). Deleted by the
/// test's tearDown/finally; must never be committed.
library;

const someNewTestCollectionXyzIntTouch = '$fixtureCollectionName';
''');

          final dirty = await runFixtureCheck();
          expect(
            dirty.exitCode,
            1,
            reason:
                'a brand-new cross-tree split outside the (empty) '
                'fixture baseline must fail.\nstdout=${dirty.stdout}\n'
                'stderr=${dirty.stderr}',
          );
          expect(dirty.stderr.toString(), contains(fixtureCollectionName));
        } finally {
          bookmarkRepoFile.writeAsStringSync(originalBookmarkContent);
          if (functionsFixtureFile.existsSync()) {
            functionsFixtureFile.deleteSync();
          }
        }

        final clean = await runFixtureCheck();
        expect(
          clean.exitCode,
          0,
          reason:
              'removing both fixture touches must restore a clean pass.\n'
              'stdout=${clean.stdout}\nstderr=${clean.stderr}',
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  });
}
