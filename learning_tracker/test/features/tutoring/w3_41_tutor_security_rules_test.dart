/// W3.41 — Tutor Security Boundary: Firestore Rules Tests
///
/// Static structural assertions on `firestore.rules` that prove the load-
/// bearing security invariants are correctly authored.
///
/// WHY STATIC ASSERTIONS:
///   The `fake_firebase_security_rules` package (used in epic_27 tests) cannot
///   evaluate `request.auth.uid` comparisons dynamically — it does not mock
///   the auth context. The emulator-based tests in `test/firestore-rules/`
///   provide dynamic coverage. These tests serve as a structural guard that
///   survives refactors and CI runs without requiring the emulator.
///
/// INVARIANTS ASSERTED:
///   1. TUTOR WRITE BLOCK — completions create is gated by `isOwner(uid)`.
///      A tutor (uid ≠ profile owner uid) always fails this check. No
///      tutor-bypass clause (`isTutorOf`, `isActiveTutorGrant`) appears in
///      the completions block.
///
///   2. CLIENT WRITE LOCK — `tutor_grants` collection denies all client
///      writes (create/update/delete: if false). This prevents a malicious
///      client from forging an active-state grant document.
///
///   3. AUDIT LOG CLIENT LOCK — `audit_log` sub-collection also denies all
///      client writes. All audit entries are written exclusively by Cloud
///      Functions (Admin SDK) — W3.42.
///
///   4. OWNER POSITIVE PATH — The completions block must retain the
///      `allow create: if isOwner(uid)` path so legitimate owners can still
///      write completions.
///
///   5. GRANT READ SCOPE — `tutor_grants` allows reads only to tutor_uid or
///      parent_uid, requiring authentication.
///
/// COMPLEMENT TEST (emulator):
///   The full dynamic complement is in `test/firestore-rules/` (Mocha + Node
///   Firebase emulator). It tests:
///     - owner write → allowed
///     - tutor write (different uid) → denied (403)
///     - unauthenticated write → denied (403)
///     - tutor forging a grant doc → denied (403)

@Tags(['tutoring', 'w3_41', 'security'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  late String rules;

  setUpAll(() {
    rules = _readProjectRules();
  });

  // ── 1. Completions write-block ──────────────────────────────────────────

  group('W3.41 completions — tutor write-block', () {
    test(
      'completions create is gated by isOwner(uid) — non-owner (tutor) is denied',
      () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(
          block,
          contains('isOwner(uid)'),
          reason:
              'The completions create rule MUST use isOwner(uid). '
              'A tutor whose request.auth.uid differs from uid always fails '
              'this check, making the create always false for non-owners.',
        );
      },
    );

    test('completions block contains no isTutorOf bypass', () {
      final block = _extractRuleBlock(rules, 'completions/{completionId}');
      expect(
        block,
        isNot(contains('isTutorOf')),
        reason:
            'isTutorOf MUST NOT appear in the completions block. '
            'Tutors may never write live completions via the client. '
            'All tutor completion writes go through the Cloud Function proxy (W3.43).',
      );
    });

    test('completions block contains no isActiveTutorGrant bypass', () {
      final block = _extractRuleBlock(rules, 'completions/{completionId}');
      expect(
        block,
        isNot(contains('isActiveTutorGrant')),
        reason:
            'isActiveTutorGrant MUST NOT appear in the completions block. '
            'Grant status is irrelevant — no tutor may write live completions.',
      );
    });

    test('completions block documents the load-bearing security boundary', () {
      expect(
        rules,
        contains('TUTOR WRITE BLOCK'),
        reason:
            'The rules file MUST contain the TUTOR WRITE BLOCK comment as '
            'a searchable security-boundary marker for auditors and reviewers.',
      );
    });

    test('completions block denies update from non-owners and denies delete', () {
      final block = _extractRuleBlock(rules, 'completions/{completionId}');
      // Update must be gated by isOwner(uid) — either as a combined
      // "create, update" or a separate rule (including the SR-1
      // idempotent-replay guard — AUD-docs-01 — which is owner-only PLUS
      // value-unchanged, strictly stronger than plain owner-only). A tutor
      // (uid ≠ profileId owner) always fails isOwner(uid), so no tutor can
      // update a completion.
      expect(
        block,
        anyOf(
          contains('allow update: if false'),
          contains('allow create, update: if isOwner'),
          contains(
            'allow update: if isOwner(uid) && request.resource.data == resource.data',
          ),
          matches(RegExp(r'allow update:\s+if isOwner\(uid\)')),
        ),
        reason: 'completions update MUST be owner-only or explicitly denied.',
      );
      expect(block, contains('allow delete: if false'));
    });
  });

  // ── 2. Owner positive path (regression guard) ───────────────────────────

  group('W3.41 completions — owner positive path', () {
    test(
      'completions block allows owner create (isOwner(uid) positive path)',
      () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(
          block,
          // Accepts both "allow create: if isOwner" and "allow create, update: if isOwner"
          anyOf(
            contains('allow create: if isOwner(uid)'),
            contains('allow create, update: if isOwner(uid)'),
          ),
          reason:
              'The owner MUST be able to create completions. '
              'isOwner(uid) is the ONLY allow path. Removing it would silently '
              'break all completion recording.',
        );
      },
    );
  });

  // ── 3. tutor_grants — client write lock ────────────────────────────────

  group('W3.41 tutor_grants — client writes forbidden', () {
    test('tutor_grants denies client create (forged grant attack vector)', () {
      final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
      expect(
        block,
        contains('allow create: if false'),
        reason:
            'A client MUST NOT be able to create a grant document. '
            'A malicious client could forge state=active and bypass the '
            'entire permission model.',
      );
    });

    test('tutor_grants denies client update', () {
      final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
      expect(
        block,
        contains('allow update: if false'),
        reason:
            'A client MUST NOT be able to update a grant document. '
            'State transitions (pending→active, active→revoked) must only '
            'happen via Cloud Functions (Admin SDK).',
      );
    });

    test('tutor_grants denies client delete', () {
      final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
      expect(
        block,
        contains('allow delete: if false'),
        reason:
            'A client MUST NOT be able to delete a grant document. '
            'Grant lifecycle is server-side only.',
      );
    });

    test('tutor_grants allows reads for authenticated tutor or parent', () {
      final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
      expect(
        block,
        contains('allow read: if isSignedIn()'),
        reason:
            'Grant docs must be readable by authenticated parties '
            '(tutor reads their own grants; parent reads grants they issued).',
      );
      expect(
        block,
        contains('tutor_uid'),
        reason:
            'The read rule must reference tutor_uid to allow the tutor '
            'to read their own grant.',
      );
      expect(
        block,
        contains('parent_uid'),
        reason:
            'The read rule must reference parent_uid to allow the parent '
            'to read grants they issued.',
      );
    });
  });

  // ── 4. audit_log — client write lock ───────────────────────────────────

  group('W3.41 audit_log — client writes forbidden', () {
    test('audit_log sub-collection denies all client writes', () {
      final block = _extractRuleBlock(rules, 'audit_log/{entryId}');
      expect(
        block,
        contains('allow create: if false'),
        reason:
            'Audit log entries MUST only be created by Cloud Functions '
            '(Admin SDK) to prevent log tampering.',
      );
      expect(
        block,
        contains('allow update: if false'),
        reason: 'Audit log entries are immutable — must deny update.',
      );
      expect(
        block,
        contains('allow delete: if false'),
        reason:
            'Audit log entries must only be purged by the scheduled Cloud '
            'Function (W3.42) — not by the client.',
      );
    });
  });

  // ── 5. V2-R3 C2 — tutor subcollection read access ──────────────────────

  group('V2-R3 C2 — tutor active access for subcollection reads', () {
    test('hasActiveTutorAccess helper is defined in rules', () {
      expect(
        rules,
        contains('function hasActiveTutorAccess(ownerUid, profileId)'),
        reason:
            'hasActiveTutorAccess() MUST be defined for subcollection '
            'read rules to use (V2-R3 C2 fix).',
      );
    });

    test('tutor_active_access collection is defined in rules', () {
      expect(
        rules,
        contains('tutor_active_access/{accessId}'),
        reason:
            'tutor_active_access collection MUST be declared so Cloud '
            'Functions can write the lookup docs and rules can check them.',
      );
    });

    test('tutor_active_access denies all client writes', () {
      final block = _extractRuleBlock(rules, 'tutor_active_access/{accessId}');
      expect(
        block,
        contains('allow create: if false'),
        reason:
            'Clients MUST NOT create tutor_active_access docs — only Cloud '
            'Functions (Admin SDK) may write these.',
      );
      expect(
        block,
        contains('allow update: if false'),
        reason: 'tutor_active_access docs are immutable from client.',
      );
      expect(
        block,
        contains('allow delete: if false'),
        reason:
            'Only Cloud Functions may delete tutor_active_access docs '
            '(on revoke/resign/expiry).',
      );
    });

    test('completions read includes tutor access path', () {
      final block = _extractRuleBlock(rules, 'completions/{completionId}');
      expect(
        block,
        contains('hasActiveTutorAccess(uid, profileId)'),
        reason:
            'Tutors MUST be able to read completions to view learner progress. '
            'V2-R3 C2: hasActiveTutorAccess gate allows active tutors to read.',
      );
    });

    test('goals read includes tutor access path', () {
      final block = _extractRuleBlock(rules, 'goals/{goalId}');
      expect(
        block,
        contains('hasActiveTutorAccess(uid, profileId)'),
        reason:
            'Tutors MUST be able to read goals per FR-3 (tutors can '
            'set/modify/remove goals).',
      );
    });

    test('bookmarks read includes tutor access path', () {
      final block = _extractRuleBlock(rules, 'bookmarks/{bookmarkId}');
      expect(
        block,
        contains('hasActiveTutorAccess(uid, profileId)'),
        reason:
            'Tutors MUST be able to read bookmarks per FR-3 (tutors can '
            'advance bookmarks).',
      );
    });

    test('settings read includes tutor access path', () {
      final block = _extractRuleBlock(rules, 'settings/{settingId}');
      expect(
        block,
        contains('hasActiveTutorAccess(uid, profileId)'),
        reason:
            'Tutors MUST be able to read settings per FR-3 '
            '(tutors can configure curricula and stages).',
      );
    });

    test(
      'completions write block isOwner(uid) guard is not weakened by C2 change',
      () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        // The create rule must be isOwner-only — accepts combined create,update.
        expect(
          block,
          anyOf(
            contains('allow create: if isOwner(uid)'),
            contains('allow create, update: if isOwner(uid)'),
          ),
          reason:
              'Adding tutor read access MUST NOT have weakened the write '
              'block. allow create must still be isOwner(uid) only.',
        );
      },
    );
  });

  // ── 6. V2-R3 C4 — expirePendingInvites exists in Cloud Functions ────────

  group('V2-R3 C4 — expirePendingInvites structured guard', () {
    // NOTE (AUD-firebase-15): the Cloud Functions god-file was split into
    // focused modules; functions/src/index.ts is now a re-export barrel
    // only (see its own header comment). expirePendingInvites is actually
    // implemented in functions/src/tutor_invites.ts, so the structural
    // assertions below read that module — the barrel is checked separately
    // for the re-export itself.
    test('expirePendingInvites function is defined in tutor_invites.ts', () {
      final tutorInvitesTs = _readFunctionsTutorInvites();
      expect(
        tutorInvitesTs,
        contains('expirePendingInvites'),
        reason:
            'expirePendingInvites scheduled function MUST be defined '
            '(V2-R3 C4 — 7-day TTL enforcement).',
      );
    });

    test('expirePendingInvites is re-exported from the index.ts barrel', () {
      final indexTs = _readFunctionsIndex();
      expect(
        indexTs,
        contains('expirePendingInvites'),
        reason:
            'expirePendingInvites MUST be re-exported from index.ts so the '
            'deployed Cloud Function name is unaffected by the '
            'AUD-firebase-15 module split.',
      );
    });

    test('expirePendingInvites queries on expires_at field', () {
      final tutorInvitesTs = _readFunctionsTutorInvites();
      expect(
        tutorInvitesTs,
        contains('expires_at'),
        reason:
            'expirePendingInvites MUST query the expires_at field to find '
            'expired pending grants.',
      );
    });

    test('expirePendingInvites transitions state to expired', () {
      final tutorInvitesTs = _readFunctionsTutorInvites();
      expect(
        tutorInvitesTs,
        contains('state: "expired"'),
        reason:
            'expirePendingInvites MUST set state to expired on matching grants.',
      );
    });
  });
}

// ── Helpers ────────────────────────────────────────────────────────────────

/// Reads the project's `firestore.rules` file from the repo root.
/// Looks two levels up because dart test sets cwd to `learning_tracker/`.
String _readProjectRules() {
  for (final path in const ['firestore.rules', '../firestore.rules']) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found; run tests from learning_tracker/ '
    'or the repo root.',
  );
}

/// Reads the Cloud Functions `index.ts` barrel source.
String _readFunctionsIndex() {
  for (final path in const [
    'functions/src/index.ts',
    '../functions/src/index.ts',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'functions/src/index.ts not found; run tests from learning_tracker/ '
    'or the repo root.',
  );
}

/// Reads the Cloud Functions `tutor_invites.ts` source — the module that
/// implements `expirePendingInvites` post AUD-firebase-15 (index.ts is now
/// only a re-export barrel; see its header comment).
String _readFunctionsTutorInvites() {
  for (final path in const [
    'functions/src/tutor_invites.ts',
    '../functions/src/tutor_invites.ts',
  ]) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'functions/src/tutor_invites.ts not found; run tests from '
    'learning_tracker/ or the repo root.',
  );
}

/// Extract the body (between `{` and matching `}`) of a `match /<pattern>`
/// block. Brace counting starts at the first `{` AFTER the match
/// declaration to skip path-parameter braces like `{docId}`.
String _extractRuleBlock(String rules, String matchPattern) {
  final start = rules.indexOf('match /$matchPattern');
  if (start == -1) {
    throw StateError('rule block not found: match /$matchPattern');
  }
  var i = start + 'match /$matchPattern'.length;
  while (i < rules.length && rules[i] != '{') {
    i++;
  }
  if (i >= rules.length) return rules.substring(start);
  var depth = 0;
  while (i < rules.length) {
    final ch = rules[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) return rules.substring(start, i + 1);
    }
    i++;
  }
  return rules.substring(start);
}
