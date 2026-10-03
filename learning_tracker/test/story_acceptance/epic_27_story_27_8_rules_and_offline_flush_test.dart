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
///     1. The five collections retired at the AD-49 cutover have no match
///        block since the release after (DNI-491); the global default-deny
///        covers them.
///     2. The snapshot field whitelists and delete guards are present in
///        the rules file.
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

        // W3.35-W3.37 — the old per-event collections. The AD-49 cutover
        // (DNI-490) denied every client write to them; the release after
        // (DNI-491) removed their matches, so the global default-deny now
        // denies every client read and write.
        test('retired collections have no match block (AD-49, DNI-491)', () {
          for (final c in [
            'completions',
            'streak_events',
            'learning_ledger',
            'bookmarks',
            'learning_order',
          ]) {
            expect(rules, isNot(contains('match /$c/')), reason: c);
          }
          // The governed per-track ordering is a different collection and
          // keeps its match.
          expect(rules, contains('match /track_learning_order/{orderId}'));
        });

        // Snapshot collections in the nested layout gate writes through
        // a .hasOnly() whitelist.
        test(
          'snapshot collections gate writes through hasOnly() field whitelist',
          () {
            // Collections with write field whitelist + delete-denied.
            for (final c in [
              'stage_definitions/{stageId}',
              'import_metadata/{docId}', // W3.34: renamed
            ]) {
              final block = _extractRuleBlock(rules, c);
              expect(
                block,
                c.startsWith('stage_definitions/')
                    ? contains('writesOnlyLiveKeys([')
                    : contains('.hasOnly('),
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
              contains('writesOnlyLiveKeys(['),
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
  //   • The `learning_events` create gate is `isOwner(uid)` — which
  //     evaluates to `request.auth.uid == uid` where `uid` is the Firestore
  //     path segment for the profile owner. A tutor has a different uid and
  //     cannot satisfy this condition, making the create rule always false
  //     for non-owners.
  //   • The `tutor_grants` collection rules deny all client writes (create /
  //     update / delete: if false), preventing a malicious client from forging
  //     an active-state grant.
  //   • Audit log entries inside `tutor_grants/{grantId}/audit_log/{entryId}`
  //     also deny all client writes.

  group(
    'W3.41 — Tutor security boundary: learning write-block and grant rules',
    tags: ['story_w3_41_tutor_security'],
    () {
      late String rules;
      setUpAll(() {
        rules = _readProjectRules();
      });

      // ── 1. Learning write-block — non-owner cannot write ────────────────
      //
      // learning_events is the one learning write target (AD-49). Its create
      // rule is `isOwner(uid)`, which expands to `request.auth.uid == uid`.
      // A tutor (different uid) can never satisfy it. We assert:
      //   (a) No tutor-bypass path exists in the learning_events block.
      //   (b) The block denies client deletes.
      //   (c) The load-bearing comment keyword is present to aid future audit.
      //   (d) The retired completions collection has no match at all.

      test('learning_events block contains no tutor-bypass write clause', () {
        final block = _extractRuleBlock(rules, 'learning_events/{eventId}');
        expect(
          block,
          isNot(contains('isTutorOf')),
          reason:
              'isTutorOf MUST NOT appear in the learning_events block — '
              'tutors may never write learning directly',
        );
        expect(
          block,
          isNot(contains('isActiveTutorGrant')),
          reason:
              'isActiveTutorGrant MUST NOT appear in the learning_events '
              'block — tutor learning writes go through Cloud Functions only',
        );
        expect(
          RegExp(
            r'allow\s+(create|update|write)[^;]*hasActiveTutorAccess',
          ).hasMatch(block),
          isFalse,
          reason: 'tutor read access must not open a write path',
        );
        expect(block, contains('allow delete: if false;'));
      });

      test('the retired completions collection has no match block', () {
        expect(rules, isNot(contains('match /completions/')));
      });

      test(
        'learning_events block documents the load-bearing security boundary',
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
        'learning_events allow create rule has an isOwner path (owner can write)',
        () {
          // AD-49: learning_events is the one learning write target.
          final block = _extractRuleBlock(rules, 'learning_events/{eventId}');
          expect(
            block,
            contains('allow create: if isOwner(uid)'),
            reason:
                'The owner MUST be able to record learning events; '
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
