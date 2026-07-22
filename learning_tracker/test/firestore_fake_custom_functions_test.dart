/// R4 (Firestore security rules) investigation — why this repo does NOT
/// have a `createFakeFirestore(strictRules: true)`-based owner/non-owner
/// MATRIX test, and where the real one lives instead.
///
/// `firestore_fake.dart`'s own header says the companion
/// `fake_firebase_security_rules` package "does NOT support
/// `request.resource`, `resource`, or `functions`; clauses using those
/// construct evaluate to deny in the fake." Read quickly, that sounds like
/// a narrow limitation — rules that inspect the incoming/existing document
/// body can't be positively verified, but plain ownership checks should
/// still work. They do NOT.
///
/// Every non-trivial `allow` clause in `firestore.rules` is gated by a
/// user-defined `function` — `isOwner(uid)`, `isSignedIn()`, or
/// `hasActiveTutorAccess(uid, profileId)`. `fake_firebase_security_rules`
/// 0.5.4's "functions" limitation is not about `get()`/`exists()` (Firestore's
/// built-in cross-document lookups) — it is about the `function` keyword
/// itself: `unsupportedFeatures['functions']` in its `parser.dart` matches
/// the literal declaration syntax `function \w+(`, and nothing in the
/// package ever registers a declared function with the CEL environment
/// before compiling an `allow` clause's condition. A call to an undeclared
/// function fails at evaluation time; `path_match.dart` catches that failure
/// and treats the clause as `false` — i.e. denied, for EVERYONE, including
/// the legitimate owner. This is confirmed empirically below with an
/// isolated minimal ruleset (not the project's real rules), then grounded
/// against the project's actual simplest rule.
///
/// Practically: because virtually every rule in `firestore.rules` calls at
/// least one custom function, `createFakeFirestore(strictRules: true)`
/// cannot positively verify ANY of them ("owner CAN write" would always
/// throw), and a "negative" assertion ("non-owner CANNOT write") against
/// the same path is tautological — it would deny a non-owner even if the
/// ownership check were deleted entirely, because the function call itself
/// never evaluates. Building a matrix test on this foundation would produce
/// tests that are always green regardless of whether the rules are correct
/// — exactly the false-assurance failure mode this campaign exists to catch
/// (see run-10's `content_index.dart` investigation and this campaign's R7
/// tautology findings for the same class of bug in a different guise).
///
/// The real, comprehensive, DYNAMICALLY-verified owner/tutor/stranger/anon
/// matrix already exists and already covers every one of this file's
/// concerns, against a real Firestore emulator (which has no such
/// limitation):
///
///   functions/test/firestore_rules.test.mjs
///     — 104 tests, 24/24 match paths, owner-write + tutor-read +
///       stranger/anon-deny matrix per collection, SR-1..SR-5 boundary
///       tests, a Phase D zero-denial oracle (every legitimate owner write
///       succeeds, with a canary proving the oracle isn't trivially green),
///       and a Phase E cross-device replication round-trip.
///     — Gated by `functions/tool/check_rule_coverage.mjs` (TQ-9): every
///       conditional `allow` line in `firestore.rules` must be evaluated by
///       at least one test, checked against the emulator's own rule-
///       coverage report.
///     — Run via `make test-rules`; wired into `make ci`.
///     — Verified during this investigation: 104/104 pass, TQ-9 coverage
///       clean, AND red-demoed — temporarily widening the completions
///       TUTOR WRITE BLOCK (`firestore.rules:244`) to also allow
///       `hasActiveTutorAccess(uid, profileId)` immediately failed
///       exactly one test ("tutor with active grant CANNOT create or
///       update a completion (write block)") with
///       "Expected request to fail, but it succeeded."; reverting restored
///       104/104 green.
///
/// A second, weaker layer already exists on the Dart side too — STATIC
/// text-matching against the rules file source (not dynamic evaluation),
/// added because a previous author independently hit this same limitation:
///   test/story_acceptance/epic_27_story_27_8_rules_and_offline_flush_test.dart
///   test/features/tutoring/w3_41_tutor_security_rules_test.dart
///
/// So R4's rules-matrix coverage is NOT missing — it is comprehensive,
/// current (functions/test/firestore_rules.test.mjs was last touched
/// 2026-07-13), and red-demo-verified. What was missing was a Dart-fake
/// path, and that turns out to be structurally impossible for this rules
/// file with the currently-pinned `fake_firebase_security_rules` version,
/// not merely unbuilt.
@Tags(['epic_27', 'security'])
library;

import 'dart:io';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(
    'fake_firebase_security_rules cannot evaluate custom `function` '
    'declarations (root-caused, isolated from the project\'s real rules)',
    () {
      test(
        'baseline: an INLINED auth check (no custom function) DOES work — '
        'the fake is not broken categorically, only for function calls',
        () async {
          const inlineRules = '''
service cloud.firestore {
  match /databases/{database}/documents {
    match /inline_test/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }
}
''';
          final auth = Stream<Map<String, dynamic>?>.value({'uid': 'owner_1'});
          final fake = FakeFirebaseFirestore(
            securityRules: inlineRules,
            authObject: auth,
          );

          // The owner writes successfully — no throw.
          await fake.collection('inline_test').doc('owner_1').set({'x': 1});
          final snap = await fake
              .collection('inline_test')
              .doc('owner_1')
              .get();
          expect(snap.data()?['x'], 1);
        },
      );

      test('the IDENTICAL check, wrapped in a custom function() and called by '
          'name, is denied even for the legitimate owner', () async {
        // Semantically identical to the inline case above — only the
        // `function isOwner(uid) { ... }` wrapper differs.
        const funcRules = '''
service cloud.firestore {
  match /databases/{database}/documents {
    function isOwner(uid) {
      return request.auth != null && request.auth.uid == uid;
    }
    match /func_test/{uid} {
      allow read, write: if isOwner(uid);
    }
  }
}
''';
        final auth = Stream<Map<String, dynamic>?>.value({'uid': 'owner_1'});
        final fake = FakeFirebaseFirestore(
          securityRules: funcRules,
          authObject: auth,
        );

        // If a future fake_firebase_security_rules upgrade adds custom-
        // function support, this assertion will start failing (the write
        // will stop throwing) — that failure is the intended signal to
        // revisit whether a Dart-fake matrix has become viable, not a
        // regression to silence.
        await expectLater(
          () => fake.collection('func_test').doc('owner_1').set({'x': 1}),
          throwsA(anything),
          reason:
              'fake_firebase_security_rules 0.5.4 does not register '
              'user-defined `function` declarations with its CEL '
              'environment, so any call to one fails evaluation and the '
              'enclosing allow clause is treated as denied — for every '
              'caller, including the true owner.',
        );
      });

      test('grounded in the real project rules: users/{uid} (the simplest '
          'rule in firestore.rules — a single isOwner(uid) call, no '
          'request.resource.data at all) still denies the true owner under '
          'strictRules', () async {
        final rules = _loadProjectRules();
        final auth = Stream<Map<String, dynamic>?>.value({'uid': 'owner_1'});
        final fake = FakeFirebaseFirestore(
          securityRules: rules,
          authObject: auth,
        );

        // `users/{uid}` is gated by `allow create, update: if isOwner(uid);`
        // ONLY — no request.resource.data reference anywhere in that rule.
        // If the "functions" limitation only covered request.resource /
        // resource (as a narrow reading of firestore_fake.dart's header
        // might suggest), the true owner would succeed here. They do not —
        // confirming the limitation is total for this rules file, not
        // partial.
        await expectLater(
          () => fake.collection('users').doc('owner_1').set({
            'displayName': 'Alice',
          }),
          throwsA(anything),
          reason:
              'users/{uid} is gated ONLY by isOwner(uid) — no '
              'request.resource.data reference — yet the fake still denies '
              'the true owner, because isOwner() is a custom function. '
              'This is why no positive ("owner CAN") assertion appears '
              'anywhere in this repo built on createFakeFirestore('
              'strictRules: true) against a real matched collection: it is '
              'not possible with the currently-pinned dependency version. '
              'See functions/test/firestore_rules.test.mjs for the real, '
              'dynamically-verified matrix (24/24 paths, run via '
              '`make test-rules`, wired into `make ci`).',
        );
      });
    },
  );
}

/// Reads the project's real `firestore.rules`, mirroring
/// `test/helpers/firestore_fake.dart`'s own loader (tests may run from the
/// repo root or from `learning_tracker/`).
String _loadProjectRules() {
  for (final path in const ['../firestore.rules', 'firestore.rules']) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found. Run tests from learning_tracker/ or the '
    'repo root.',
  );
}
