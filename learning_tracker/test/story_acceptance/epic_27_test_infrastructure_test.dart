/// Story acceptance tests for Epic 27 — Story 27.1 (DNI-377).
///
/// Story 27.1 (DNI-377):
///   AC1 — `test/helpers/firestore_fake.dart` exposes a configured
///         `FakeFirebaseFirestore` factory with the project's
///         `firestore.rules` pre-loaded so security rules execute against
///         the fake just like the emulator (NFR12).
///   AC2 — `test/helpers/golden_runner.dart` provides `goldenTest(name,
///         build)` that automatically produces both English and Hebrew
///         golden variants (NFR13).
///   AC3 — At least one consumer of each helper exists. The consumers in
///         this file double as living documentation: the integration tests
///         in DNI-27.5–27.9 will follow these patterns.
@Tags(['epic_27'])
library;

import 'package:flutter/widgets.dart';
import 'package:test/test.dart';

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
        // reject any write. `unmatched_collection` is deliberately not a
        // real path in firestore.rules: this test is exercising the
        // blanket default-deny (`match /{document=**} { allow read, write:
        // if false; }`), not any specific per-collection rule, so the
        // collection name is named to make that explicit rather than
        // inviting a reader to think it corresponds to a real rule.
        final fake = createFakeFirestore(strictRules: true);

        await expectLater(
          () => fake.collection('unmatched_collection').doc('uid_1').set({
            'uid': 'x',
          }),
          throwsA(isA<Exception>()),
          reason:
              'firestore_fake helper must mount the real firestore.rules '
              'in strict mode so security-rule violations fail closed',
        );
      });

      // AUD-t-cross (R4 follow-up, run-10): this test previously targeted a
      // fictional `accounts/{docId}` collection and its comment claimed the
      // throw came from an unsupported `request.resource.data.hasOnly()`
      // clause on that rule. Neither was true — `accounts` was never a real
      // path in firestore.rules, so the throw was actually the blanket
      // default-deny (the SAME mechanism as the test above), not evidence
      // that request.auth.uid was "honoured" or that hasOnly() was
      // exercised. That is exactly the tautology class this campaign exists
      // to catch: the assertion passed, but not for the reason its name and
      // comment claimed. Rewritten to target a REAL rule and state the true
      // (more interesting) finding instead.
      test('createFakeFirestore(strictRules: true) still denies the '
          'authenticated OWNER on the simplest real owner-only rule '
          '(users/{uid}) — a Dart-fake ceiling, not a rules bug', () async {
        // users/{uid} in the real firestore.rules is gated ONLY by
        // `isOwner(uid)` — no request.resource.data, no hasOnly()
        // whitelist, nothing else. In production the authenticated
        // owner's write succeeds. Here it still throws:
        // fake_firebase_security_rules does not register user-defined
        // `function` declarations (isOwner/isSignedIn/
        // hasActiveTutorAccess) with its CEL environment at all, so the
        // call fails evaluation and the enclosing allow clause is denied
        // for EVERY caller, including the true owner. See
        // test/firestore_fake_custom_functions_test.dart for the full,
        // isolated root-cause investigation (R4, run-10) — this test
        // only pins the corrected, real-rule version of what this file
        // used to (incorrectly) claim.
        final fake = createFakeFirestore(
          authenticatedUid: 'uid_1',
          strictRules: true,
        );

        await expectLater(
          () => fake.collection('users').doc('uid_1').set({
            'displayName': 'Alice',
          }),
          throwsA(isA<Exception>()),
          reason:
              'users/{uid} is gated ONLY by isOwner(uid) in the real '
              'firestore.rules — no request.resource.data reference at '
              'all — yet the fake still denies the true owner, because '
              'isOwner() is a custom function and this dependency '
              'version does not support custom function declarations. '
              'If this assertion ever starts failing (the write '
              'succeeds), a future fake_firebase_security_rules upgrade '
              'has added function support — revisit whether a dynamic '
              'Dart-side rules matrix has become viable.',
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
        // R2 widened the builder to (locale, brightness). The body stays a
        // bare SizedBox: this call site's job is to prove the RUNNER
        // registers every variant, so it must not depend on either axis.
        builder: (locale, brightness) => const SizedBox(width: 10, height: 10),
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

      // R2 (golden matrix) added a light/dark axis alongside the locale
      // axis. Without a structural guard the brightness axis could silently
      // stop being registered — every golden would still pass, just with
      // half the coverage, which is exactly the inert-golden failure mode
      // this campaign exists to catch. Asserted at registration time for
      // the same order-independence reason as the locale guard above.
      test('goldenTest exercises both light and dark brightness', () {
        final brightnesses = registeredGoldenTests
            .where((registration) => registration.name == goldenName)
            .map((registration) => registration.brightness)
            .toSet();
        expect(
          brightnesses,
          {Brightness.light, Brightness.dark},
          reason:
              'goldenTest(name, builder) must register one sub-test per '
              'brightness so dark-mode regressions are caught — the run-9 '
              'dark-mode legibility cluster shipped because nothing '
              'asserted on dark renderings',
        );
      });
    });
  });
}
