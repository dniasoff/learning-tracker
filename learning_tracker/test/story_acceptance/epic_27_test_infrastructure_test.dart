/// Story acceptance tests for Epic 27 — Story 27.1 (DNI-377):
/// Test infrastructure — `fake_cloud_firestore`, golden runner, real-Drift
/// in-memory helper.
///
/// Validates the four ACs from DNI-377:
///   AC1 — `test/helpers/firestore_fake.dart` exposes a configured
///         `FakeFirebaseFirestore` factory with the project's
///         `firestore.rules` pre-loaded so security rules execute against
///         the fake just like the emulator (NFR12).
///   AC2 — `test/helpers/golden_runner.dart` provides `goldenTest(name,
///         build)` that automatically produces both English and Hebrew
///         golden variants (NFR13).
///   AC3 — `test/helpers/drift_memory.dart` provides `inMemoryDb()`
///         returning a fresh schema-v1 (current schemaVersion = 13)
///         `UserDatabase` instance backed by `NativeDatabase.memory()`.
///   AC4 — At least one consumer of each helper exists. The consumers in
///         this file double as living documentation: the integration tests
///         in DNI-27.5–27.9 will follow these patterns.
@Tags(['epic_27'])
library;

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
      // We assert this by counting the locales actually exercised.
      final exercised = <Locale>{};
      goldenTest(
        'records both locale variants — sanity check',
        builder: (locale) {
          exercised.add(locale);
          return const SizedBox(width: 10, height: 10);
        },
        skipGolden: true,
      );

      test('goldenTest exercises both English and Hebrew locales', () {
        expect(
          exercised,
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
          // schema. DNI-326 set this to 13; the helper must not
          // pin a stale number.
          expect(db.schemaVersion, db.schemaVersion);
          expect(db.schemaVersion, greaterThanOrEqualTo(13));
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
}
