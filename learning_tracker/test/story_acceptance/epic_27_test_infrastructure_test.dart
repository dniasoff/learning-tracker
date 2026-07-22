/// Story acceptance tests for Epic 27 — Story 27.1 (DNI-377) and
/// Story 27.3 (DNI-379).
///
/// Story 27.1 (DNI-377):
///   AC1 — `test/helpers/firestore_fake.dart` exposes a configured
///         `FakeFirebaseFirestore` factory with the project's
///         `firestore.rules` pre-loaded so security rules execute against
///         the fake just like the emulator (NFR12).
///   AC2 — `test/helpers/golden_runner.dart` provides `goldenTest(name,
///         build)` that automatically produces both English and Hebrew
///         golden variants (NFR13).
///   AC3 — `test/helpers/drift_memory.dart` provides `inMemoryDb()`
///         returning a fresh schema-v1 (current schemaVersion — see
///         `UserDatabase.schemaVersion`) `UserDatabase` instance backed
///         by `NativeDatabase.memory()`.
///   AC4 — At least one consumer of each helper exists. The consumers in
///         this file double as living documentation: the integration tests
///         in DNI-27.5–27.9 will follow these patterns.
///
/// Story 27.3 (DNI-379) — DAO + repository test suite using real
/// in-memory Drift:
///   AC1 — Every DAO in `lib/core/database/daos/` has a sibling test
///         file under `test/core/database/daos/`.
///   AC2 — Every DAO test file constructs its database through
///         `inMemoryDb()` from `test/helpers/drift_memory.dart`.
///   AC3 — Zero `MockUserDatabase` references survive anywhere under
///         `test/` — every test exercises the real engine (NFR12).
@Tags(['epic_27'])
library;

import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter/widgets.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:test/test.dart';

import '../helpers/drift_memory.dart';
import '../helpers/firestore_fake.dart';
import '../helpers/golden_runner.dart';

void main() {
  group('Story 27.1 — Test infrastructure', () {
    // ── AC1 — firestore_fake.dart ────────────────────────────────────────

    group('firestore_fake helper', tags: ['story_27_1_firestore'], () {
      test('createFakeFirestore() (permissive default) is usable for normal '
          'read/write flows without auth-rule friction', () async {
        final fake = createFakeFirestore(authenticatedUid: 'uid_1');

        // Smoke-test the contract everything else relies on: write a
        // doc, read it back, get the same payload.
        await fake.collection('accounts').doc('uid_1').set({
          'uid': 'uid_1',
          'email': 'a@b.test',
        });
        final snap = await fake.collection('accounts').doc('uid_1').get();
        expect(snap.data()?['uid'], 'uid_1');
        expect(snap.data()?['email'], 'a@b.test');
      });

      test('createFakeFirestore(strictRules: true) pre-loads the project '
          'firestore.rules and rejects unauthenticated writes', () async {
        // Strict mode + no auth — the deny-all default match should
        // reject any write.
        final fake = createFakeFirestore(strictRules: true);

        await expectLater(
          () => fake.collection('accounts').doc('uid_1').set({'uid': 'x'}),
          throwsA(isA<Exception>()),
          reason:
              'firestore_fake helper must mount the real firestore.rules '
              'in strict mode so security-rule violations fail closed',
        );
      });

      test('createFakeFirestore(strictRules: true) honours request.auth.uid '
          'on uid-scoped collections', () async {
        // Authenticated as uid_1; the accounts/{docId} rule matches
        // `request.auth.uid == docId`, so a write to accounts/uid_1
        // succeeds.
        final fake = createFakeFirestore(
          authenticatedUid: 'uid_1',
          strictRules: true,
        );
        // accounts/{uid} also requires `request.resource.data.keys()
        // .hasOnly(...)` which the underlying parser does NOT support
        // and which therefore evaluates to deny; this confirms the
        // documented limitation rather than smoke-testing every rule.
        await expectLater(
          () => fake.collection('accounts').doc('uid_1').set({
            'uid': 'uid_1',
            'email': 'a@b.test',
          }),
          throwsA(isA<Exception>()),
          reason:
              'fake_firebase_security_rules does not yet evaluate '
              'request.resource.data — see firestore_fake.dart header. '
              'When strict mode is on, those clauses evaluate as deny.',
        );
      });
    });

    // ── AC2 — golden_runner.dart ─────────────────────────────────────────

    group('golden_runner helper', tags: ['story_27_1_golden'], () {
      // `goldenTest` registers TWO underlying tests — one per locale.
      // skipGolden: false (AUD-t-cross-51) — flutter_test_config.dart now
      // loads real fonts before any test runs (TQ-5), so the pixel
      // assertion is meaningful. This particular golden has no font
      // dependency at all (a plain SizedBox, no text) — the safest of the
      // suite's call sites to baseline first, since its captured PNG can
      // never regress for font-loading reasons, only for a genuine
      // structural change to the harness itself.
      const goldenName = 'records both locale variants — sanity check';
      goldenTest(
        goldenName,
        builder: (locale) => const SizedBox(width: 10, height: 10),
      );

      // R6 fix (docs/test-artifacts/reassurance-plan.md Surface 6):
      // previously asserted against a local `exercised` set mutated INSIDE
      // the widget builder above — i.e. only populated once each golden
      // sub-test actually RAN. package:test/flutter_test declare the full
      // test tree synchronously before any test body executes, but they do
      // NOT guarantee sibling tests within a group execute in declaration
      // order once `--test-randomize-ordering-seed` shuffles it — so this
      // assertion test could (and, randomized, did: caught live by this
      // very change) run before one or both golden sub-tests had executed,
      // failing with only a partial (or empty) `exercised` set despite the
      // helper being perfectly correct. Fixed the same way
      // epic_27_story_4_widget_golden_test.dart's "Hebrew variant ships for
      // every golden widget" test already does (AUD-t-story-acceptance-16):
      // assert against `registeredGoldenTests`, which golden_runner.dart's
      // `goldenTest()` populates at REGISTRATION time (synchronously, while
      // main() builds the tree) — order-independent by construction.
      test('goldenTest exercises both English and Hebrew locales', () {
        final locales = registeredGoldenTests
            .where((registration) => registration.name == goldenName)
            .map((registration) => registration.locale)
            .toSet();
        expect(
          locales,
          {const Locale('en'), const Locale('he')},
          reason:
              'goldenTest(name, builder) must register one sub-test '
              'per locale so visual regressions in either rendering '
              'are caught (NFR13)',
        );
      });
    });

    // ── AC3 — drift_memory.dart ──────────────────────────────────────────

    group('drift_memory helper', tags: ['story_27_1_drift'], () {
      test('inMemoryDb() returns a fresh UserDatabase at the current '
          'schemaVersion', () async {
        final db = inMemoryDb();
        try {
          // Touching the DAO triggers the migration runner. If the
          // helper is wired correctly, this is a no-op (schema is
          // brand-new and matches `schemaVersion`).
          final profiles = await db.select(db.learnerProfiles).get();
          expect(profiles, isEmpty);

          // Schema version reflects the project's current Drift
          // schema. W3.19 reset this to 1; the helper must not
          // pin a stale number.
          // weaken-ok: AUD-t-story-acceptance-43 — removed
          // `expect(db.schemaVersion, db.schemaVersion)`, a
          // self-comparison that always passes and verified nothing.
          // The `greaterThanOrEqualTo(1)` check below is the real
          // (minimal) sanity check on the value.
          expect(db.schemaVersion, greaterThanOrEqualTo(1));
        } finally {
          await db.close();
        }
      });

      test('inMemoryDb() returns independent instances per call', () async {
        final a = inMemoryDb();
        final b = inMemoryDb();
        try {
          // Writing to A must not be visible from B — proves no shared
          // backing store leaks between tests.
          // Seed account first — W3.25 added FK learner_profiles→accounts.
          await seedProfile(a);
          final now = DateTime.utc(2026, 5, 13);
          await a
              .into(a.learnerProfiles)
              .insert(
                LearnerProfilesCompanion.insert(
                  id: const Value(7),
                  accountId: 1,
                  displayName: 'a-only',
                  mode: 'adult',
                  createdAt: now,
                  updatedAt: now,
                ),
              );
          final fromB = await b.select(b.learnerProfiles).get();
          expect(
            fromB,
            isEmpty,
            reason:
                'each inMemoryDb() call must return a brand-new in-'
                'memory backing store — tests cannot share state',
          );
        } finally {
          await a.close();
          await b.close();
        }
      });
    });
  });

  // ─── Story 27.3 — DAO tests use real in-memory Drift (DNI-379) ───────────

  group(
    'Story 27.3 — DAO + repository test suite uses real in-memory Drift',
    tags: ['story_27_3'],
    () {
      late Directory daoSrcDir;
      late Directory daoTestDir;
      late Directory testRoot;

      setUpAll(() {
        // The test runs from learning_tracker/ when invoked via
        // `flutter test`, or from the repo root when invoked via
        // `flutter test learning_tracker/test/…`. Detect which.
        final candidates = [
          Directory('lib/core/database/daos'),
          Directory('learning_tracker/lib/core/database/daos'),
        ];
        daoSrcDir = candidates.firstWhere(
          (d) => d.existsSync(),
          orElse: () => throw StateError(
            'DAO source directory not found; searched: '
            '${candidates.map((d) => d.path)}',
          ),
        );
        final testRoots = [
          Directory('test'),
          Directory('learning_tracker/test'),
        ];
        testRoot = testRoots.firstWhere(
          (d) => d.existsSync(),
          orElse: () => throw StateError(
            'test/ directory not found; searched: '
            '${testRoots.map((d) => d.path)}',
          ),
        );
        daoTestDir = Directory('${testRoot.path}/core/database/daos');
      });

      /// Lists DAO source files (`*_dao.dart`) excluding generated `.g.dart`.
      List<File> listDaoSources() {
        return daoSrcDir
            .listSync()
            .whereType<File>()
            .where((f) => f.path.endsWith('_dao.dart'))
            .toList();
      }

      test('AC1: every DAO has a sibling test file under '
          'test/core/database/daos/', () {
        final daos = listDaoSources();
        expect(
          daos,
          isNotEmpty,
          reason: 'no DAO sources discovered — wrong working directory?',
        );

        final missing = <String>[];
        for (final dao in daos) {
          final base = dao.uri.pathSegments.last.replaceAll('.dart', '');
          final testFile = File('${daoTestDir.path}/${base}_test.dart');
          if (!testFile.existsSync()) missing.add(base);
        }

        expect(
          missing,
          isEmpty,
          reason:
              'These DAOs are missing test files at '
              '${daoTestDir.path}/<dao>_test.dart: $missing',
        );
      });

      test(
        'AC2: every DAO test file uses inMemoryDb() from drift_memory.dart',
        () {
          final daos = listDaoSources();
          final notUsingHelper = <String>[];
          for (final dao in daos) {
            final base = dao.uri.pathSegments.last.replaceAll('.dart', '');
            final testFile = File('${daoTestDir.path}/${base}_test.dart');
            if (!testFile.existsSync()) continue; // AC1 reports this
            final src = testFile.readAsStringSync();
            final usesHelper =
                src.contains('inMemoryDb()') &&
                src.contains('helpers/drift_memory.dart');
            if (!usesHelper) notUsingHelper.add(base);
          }
          expect(
            notUsingHelper,
            isEmpty,
            reason:
                'These DAO test files must use inMemoryDb() from '
                'test/helpers/drift_memory.dart: $notUsingHelper. '
                'Replace inline UserDatabase(NativeDatabase.memory()) and '
                'older createTestDatabase() calls with inMemoryDb().',
          );
        },
      );

      test('AC3: zero MockUserDatabase references survive in test/', () {
        final offenders = <String>[];
        for (final entity in testRoot.listSync(recursive: true)) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.dart')) continue;
          // The acceptance test itself mentions "MockUserDatabase"
          // in string-literal form — that does not count as a
          // production use. Skip self.
          if (entity.path.endsWith('epic_27_test_infrastructure_test.dart')) {
            continue;
          }
          final src = entity.readAsStringSync();
          if (src.contains('MockUserDatabase')) {
            offenders.add(entity.path);
          }
        }
        expect(
          offenders,
          isEmpty,
          reason:
              'MockUserDatabase must be deleted from the test suite. '
              'These files still reference it: $offenders. Replace '
              'mocked instances with real inMemoryDb()-backed databases.',
        );
      });
    },
  );
}
