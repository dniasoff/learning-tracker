/// Story acceptance tests for Story 27.8 (DNI-384) — integration coverage
/// of Firestore security rules and the live nested-layout boundary.
///
/// The surviving groups pin the live nested Firestore layout and the
/// structural security boundary in `firestore.rules`:
///
///   Group A — Firestore rules (W3.30-W3.37 new layout):
///     The old top-level compat blocks (accounts, learner_profiles,
///     completion_events, etc.) were removed in W3.30. Tests now assert
///     the live nested layout under users/{uid}/learner_profiles/{profileId}.
///
///     1. `delete()` is rejected by the key nested-layout collections:
///        completions, streak_events, learning_ledger, import_metadata.
///     2. Field-validator clauses for completions (points range,
///        future `completed_at`) and the snapshot field whitelists are
///        present in the rules file.
///
/// The retired offline-completion flush group has been removed.
@Tags(['epic_27'])
library;

import 'dart:io';

import 'package:test/test.dart';

void main() {
  // ── Group A — Firestore rules ───────────────────────────────────────────

  group(
    'Story 27.8 — Firestore rules enforce per-collection semantics (new layout W3.30-W3.37)',
    tags: ['story_27_8_rules'],
    () {
      // Static rule-file assertions — these pin the field validators that
      // the dynamic fake cannot evaluate. After W3.30, the old top-level
      // compat blocks are gone; assertions now target the live nested layout.
      group('rules file pins per-AC field validators', () {
        late String rules;
        setUpAll(() {
          rules = _readProjectRules();
        });

        // W3.35 — completions in the nested layout enforce points + timestamp.
        test('completions/{completionId} enforces 0 <= points <= 100', () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          expect(block, contains('points >= 0'));
          expect(block, contains('points <= 100'));
        });

        test(
          'completions/{completionId} enforces completed_at <= request.time',
          () {
            final block = _extractRuleBlock(
              rules,
              'completions/{completionId}',
            );
            expect(block, contains('completed_at <= request.time'));
          },
        );

        test(
          'completions/{completionId} denies non-owner update and delete',
          () {
            final block = _extractRuleBlock(
              rules,
              'completions/{completionId}',
            );
            // The current SR-1/D-L rule permits only owner-authenticated,
            // allowlisted status updates. That still denies every non-owner
            // update while allowing idempotent retries and tombstones.
            expect(
              block,
              contains('allow update: if isOwner(uid)'),
              reason:
                  'completions update must be owner-authenticated so non-owners '
                  'cannot mutate a completion',
            );
            expect(
              block,
              contains("hasOnly(['purged_at', 'source', 'completed_at'])"),
              reason:
                  'completion updates must stay within the status allowlist',
            );
            expect(block, contains('allow delete: if false'));
          },
        );

        // W3.37 — streak_events is now a per-event collection.
        // W3.36 — learning_ledger uses ULID doc-ids; still append-only.
        test(
          'streak_events and learning_ledger deny non-owner update and delete',
          () {
            for (final c in [
              'streak_events/{streakEventId}',
              'learning_ledger/{entryId}',
            ]) {
              final block = _extractRuleBlock(rules, c);
              expect(
                block,
                contains('allow update: if isOwner(uid)'),
                reason: '$c update must be owner-only or explicitly denied',
              );
              expect(
                block,
                c.startsWith('streak_events')
                    ? contains('request.resource.data == resource.data')
                    : contains("hasOnly(['purged_at'])"),
                reason: '$c update must remain narrowly allowlisted',
              );
              expect(block, contains('allow delete: if false'), reason: c);
            }
          },
        );

        // Snapshot collections in the nested layout gate writes through
        // a .hasOnly() whitelist.
        test(
          'snapshot collections gate writes through hasOnly() field whitelist',
          () {
            // Collections with write field whitelist + delete-denied.
            for (final c in [
              'bookmarks/{bookmarkId}',
              'stage_definitions/{stageId}',
              'import_metadata/{docId}', // W3.34: renamed
            ]) {
              final block = _extractRuleBlock(rules, c);
              expect(
                block,
                contains('.hasOnly('),
                reason: '$c must restrict writes to a fixed field list',
              );
              expect(
                block,
                contains('allow delete: if false'),
                reason: '$c must deny deletes',
              );
            }
            // profile_programs: has hasOnly() whitelist, but allows owner-delete
            // (C4 fix — V3-W1: removeProfileProgramAssignment must hard-delete).
            final ppBlock = _extractRuleBlock(
              rules,
              'profile_programs/{curriculumId}',
            );
            expect(
              ppBlock,
              contains('.hasOnly('),
              reason:
                  'profile_programs must restrict writes to a fixed field list',
            );
          },
        );

        test(
          'global deny-all wildcard precedes per-collection allow rules',
          () {
            final denyIdx = rules.indexOf('match /{document=**}');
            // After W3.30 top-level compat blocks removed; first allow is
            // the tutor_grants block or the users/ block.
            final firstAllowIdx = rules.indexOf('match /tutor_grants');
            expect(denyIdx, greaterThan(-1));
            expect(firstAllowIdx, greaterThan(-1));
            expect(
              denyIdx,
              lessThan(firstAllowIdx),
              reason:
                  'Default deny rule must appear before any allow rule so '
                  'an undeclared collection inherits the deny default.',
            );
          },
        );

        // W3.33 — preferences/{scope} replaces three separate collections.
        test('preferences/{scope} block allows owner reads/writes (W3.33)', () {
          final block = _extractRuleBlock(rules, 'preferences/{scope}');
          expect(
            block,
            contains('isOwner(uid)'),
            reason: 'preferences must be owner-gated',
          );
          expect(
            block,
            contains('allow delete: if false'),
            reason: 'preferences docs must not be deletable by clients',
          );
        });
      });
    },
  );

  // ── Group C — Tutor security boundary (W3.41) ──────────────────────────
  //
  // These are static structural assertions on the rules file (same approach
  // as Group A — the `fake_firebase_security_rules` package cannot evaluate
  // `request.auth.uid` comparisons dynamically, but string-scanning the rules
  // proves that the correct guards are present).
  //
  // The LOAD-BEARING security invariant tested here:
  //   • The `completions` rule gate is `isOwner(uid)` — which evaluates to
  //     `request.auth.uid == uid` where `uid` is the Firestore path segment
  //     for the profile owner. A tutor has a different uid and cannot satisfy
  //     this condition, making the create rule always false for non-owners.
  //   • The `tutor_grants` collection rules deny all client writes (create /
  //     update / delete: if false), preventing a malicious client from forging
  //     an active-state grant.
  //   • Audit log entries inside `tutor_grants/{grantId}/audit_log/{entryId}`
  //     also deny all client writes.

  group(
    'W3.41 — Tutor security boundary: completions write-block and grant rules',
    tags: ['story_w3_41_tutor_security'],
    () {
      late String rules;
      setUpAll(() {
        rules = _readProjectRules();
      });

      // ── 1. Completions write-block — non-owner cannot write ─────────────
      //
      // The completion create rule is `isOwner(uid)` which expands to
      // `request.auth.uid == uid`. A tutor (different uid) can never satisfy
      // this condition. We assert:
      //   (a) The completions block uses isOwner() — NOT a tutor helper.
      //   (b) No tutor-bypass path exists in the completions block.
      //   (c) The block still carries the mandatory `allow update: if false`
      //       and `allow delete: if false` guards.
      //   (d) The load-bearing comment keyword is present to aid future audit.

      test(
        'completions create is gated by isOwner(uid) — non-owner (tutor) is denied',
        () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          expect(
            block,
            contains('isOwner(uid)'),
            reason:
                'completions create MUST use isOwner(uid); a tutor whose '
                'request.auth.uid != uid always fails this check',
          );
        },
      );

      test('completions block contains no tutor-bypass allow clause', () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(
          block,
          isNot(contains('isTutorOf')),
          reason:
              'isTutorOf MUST NOT appear in the completions block — '
              'tutors may never write live completions directly',
        );
        expect(
          block,
          isNot(contains('isActiveTutorGrant')),
          reason:
              'isActiveTutorGrant MUST NOT appear in the completions block '
              '— tutor completion writes go through Cloud Functions only',
        );
      });

      test('completions block denies non-owner update and delete', () {
        final block = _extractRuleBlock(rules, 'completions/{completionId}');
        expect(
          block,
          contains('allow update: if isOwner(uid)'),
          reason:
              'completions update must be owner-authenticated so tutors '
              'cannot mutate a completion',
        );
        expect(
          block,
          contains("hasOnly(['purged_at', 'source', 'completed_at'])"),
          reason: 'completion updates must stay within the status allowlist',
        );
        expect(block, contains('allow delete: if false'));
      });

      test(
        'completions block documents the load-bearing security boundary',
        () {
          // The keyword comment is a searchable audit trail.
          expect(
            rules,
            contains('TUTOR WRITE BLOCK'),
            reason:
                'The rules file must contain the TUTOR WRITE BLOCK comment '
                'as a searchable security-boundary marker for auditors',
          );
        },
      );

      // ── 2. tutor_grants — client writes forbidden ────────────────────────
      //
      // If a client could write a grant doc with state='active', it could
      // bypass the entire permission model. All three write operations must
      // be denied.

      test(
        'tutor_grants denies all client writes (create, update, delete)',
        () {
          final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
          expect(
            block,
            contains('allow create: if false'),
            reason: 'tutor_grants create must always be denied for clients',
          );
          expect(
            block,
            contains('allow update: if false'),
            reason: 'tutor_grants update must always be denied for clients',
          );
          expect(
            block,
            contains('allow delete: if false'),
            reason: 'tutor_grants delete must always be denied for clients',
          );
        },
      );

      test('tutor_grants audit_log denies all client writes', () {
        final block = _extractRuleBlock(rules, 'audit_log/{entryId}');
        expect(block, contains('allow create: if false'));
        expect(block, contains('allow update: if false'));
        expect(block, contains('allow delete: if false'));
      });

      // ── 3. Rule correctness — owner can create a completion ──────────────
      //
      // The positive direction: the owner's path through the rules must
      // succeed. We verify the rule allows the isOwner() path (structural).

      test(
        'completions allow create rule has an isOwner path (owner can write)',
        () {
          final block = _extractRuleBlock(rules, 'completions/{completionId}');
          // The rule body must contain an isOwner(uid) create path — accepts
          // both "allow create:" and "allow create, update:" forms.
          expect(
            block,
            anyOf(
              contains('allow create: if isOwner(uid)'),
              contains('allow create, update: if isOwner(uid)'),
            ),
            reason:
                'The owner MUST be able to create completions; '
                'isOwner(uid) is the positive branch',
          );
        },
      );

      // ── 4. tutor_grants read — only tutor or parent can read ────────────

      test('tutor_grants allows reads to tutor_uid or parent_uid', () {
        final block = _extractRuleBlock(rules, 'tutor_grants/{grantId}');
        expect(
          block,
          contains('tutor_uid'),
          reason:
              'tutor_grants read rule must reference tutor_uid for tutor self-read',
        );
        expect(
          block,
          contains('parent_uid'),
          reason:
              'tutor_grants read rule must reference parent_uid for parent read',
        );
        expect(
          block,
          contains('allow read: if isSignedIn()'),
          reason: 'tutor_grants must require authentication for all reads',
        );
      });
    },
  );
}

/// Reads the project's `firestore.rules` file from the repo root, hopping
/// up one directory when the test launcher set cwd to `learning_tracker/`.
String _readProjectRules() {
  for (final path in const ['../firestore.rules', 'firestore.rules']) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found from cwd; run tests from learning_tracker/.',
  );
}

/// Extract the body (between `{` and matching `}`) of a `match /<pattern>`
/// rule. Brace counting starts at the first `{` AFTER the match
/// declaration, so path-parameter braces like `{docId}` do not skew it.
String _extractRuleBlock(String rules, String matchPattern) {
  final start = rules.indexOf('match /$matchPattern');
  if (start == -1) {
    throw StateError('rule block not found: $matchPattern');
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
