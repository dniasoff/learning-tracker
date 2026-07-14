/// Story acceptance tests for Epic 24 -- Stop-the-Bleeding (Phase 0).
///
/// Story 24.1: Per-collection Firestore rules with field validators.
@Tags(['epic_24'])
library;

import 'dart:io';

import 'package:test/test.dart';

/// Reads the canonical `firestore.rules` file from the repository root.
///
/// The test runs from the `learning_tracker/` sub-directory, so we need to
/// go up one level.
String _readRules() {
  // When running via `flutter test` the cwd is learning_tracker/.
  // When running from repo root it is the repo root itself.
  final candidates = [File('../firestore.rules'), File('firestore.rules')];
  for (final f in candidates) {
    if (f.existsSync()) return f.readAsStringSync();
  }
  throw StateError(
    'firestore.rules not found. Searched: ${candidates.map((f) => f.path)}',
  );
}

void main() {
  group(
    'Story 24.1 -- Per-collection Firestore rules with field validators',
    tags: ['story_24_1'],
    () {
      late String rules;

      setUpAll(() {
        rules = _readRules();
      });

      // ── completions ──────────────────────────────────────────────────
      //
      // The Firestore collection is still named `completions` (nested under
      // users/{uid}/learner_profiles/{profileId}/completions/{completionId}).
      group('completions collection', () {
        test('has per-collection match for completions/{completionId}', () {
          expect(rules, contains('match /completions/{completionId}'));
        });

        test('allows create (not wildcard read/write)', () {
          expect(rules, contains('points >= 0'));
          expect(rules, contains('points <= 100'));
        });

        test('enforces completed_at <= request.time', () {
          expect(rules, contains('completed_at <= request.time'));
        });

        test('denies update on completions', () {
          final block = _extractBlock(rules, 'completions/{completionId}');
          expect(
            block,
            anyOf(
              contains('allow update, delete: if false'),
              contains('allow update: if false'),
              contains('allow delete: if false'),
            ),
          );
        });
      });

      // ── streak_events ────────────────────────────────────────────────

      group('streak_events collection', () {
        test('has per-collection match for streak_events/{streakEventId}', () {
          expect(rules, contains('match /streak_events/{streakEventId}'));
        });

        test('create-only with timestamp clamp', () {
          final streakBlock = _extractBlock(
            rules,
            'streak_events/{streakEventId}',
          );
          expect(streakBlock, contains('created_at <= request.time'));
        });

        test('denies delete on streak_events', () {
          final streakBlock = _extractBlock(
            rules,
            'streak_events/{streakEventId}',
          );
          expect(
            streakBlock,
            anyOf(
              contains('allow update, delete: if false'),
              contains('allow update: if false'),
              contains('allow delete: if false'),
            ),
          );
        });
      });

      // ── learning_ledger ──────────────────────────────────────────────

      group('learning_ledger collection', () {
        test('has per-collection match for learning_ledger/{entryId}', () {
          expect(rules, contains('match /learning_ledger/{entryId}'));
        });

        test('create-only (no timestamp clamp on learning_ledger)', () {
          // learning_ledger create is owner-gated without a timestamp clamp;
          // the ULID doc-id provides idempotency. Accepts combined create,update.
          final ledgerBlock = _extractBlock(rules, 'learning_ledger/{entryId}');
          expect(
            ledgerBlock,
            anyOf(
              contains('allow create: if isOwner(uid)'),
              contains('allow create, update: if isOwner(uid)'),
            ),
          );
        });

        test('denies delete on learning_ledger', () {
          final ledgerBlock = _extractBlock(rules, 'learning_ledger/{entryId}');
          expect(
            ledgerBlock,
            anyOf(
              contains('allow update, delete: if false'),
              contains('allow update: if false'),
              contains('allow delete: if false'),
            ),
          );
        });
      });

      // ── settings ─────────────────────────────────────────────────────
      //
      // settings is an open-ended curriculum preference bag (no hasOnly
      // whitelist). Reads and create/update are owner-gated; delete is denied.

      group('settings collection', () {
        test('has per-collection match for settings/{settingId}', () {
          expect(rules, contains('match /settings/{settingId}'));
        });

        test('owner can create and update settings', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(
            settingsBlock,
            contains('allow create, update: if isOwner(uid)'),
          );
        });

        test('denies delete on settings', () {
          final settingsBlock = _extractBlock(rules, 'settings/{settingId}');
          expect(
            settingsBlock,
            anyOf(
              contains('allow delete: if false'),
              contains('allow update, delete: if false'),
            ),
          );
        });
      });

      // ── Global deny-all default ───────────────────────────────────────

      group('global default deny rule', () {
        test('has wildcard deny-all rule', () {
          expect(rules, contains('match /{document=**}'));
          // The deny-all rule must come before any collection-specific rules.
          final denyPos = rules.indexOf('allow read, write: if false');
          expect(
            denyPos,
            greaterThan(-1),
            reason: 'Missing default deny-all rule',
          );
        });
      });

      // ── Emulator test suite exists ────────────────────────────────────
      //
      // The original test/firestore-rules/ Jest suite (accounts/{uid} model)
      // was deleted by AUD-t-cross-18 (18f9bd6b) as dead code: it targeted an
      // obsolete rules layout, was wired into no Makefile target, and read a
      // non-existent repo-root firestore.rules path. The canonical, CI-wired
      // suite — already required by the "CI workflow has firestore-rules
      // job" test below and run via `make test-rules` — has lived at
      // learning_tracker/functions/test/firestore_rules.test.mjs since
      // 76fb1d5f. These assertions were missed by 18f9bd6b and are updated
      // here to point at that canonical suite instead.

      group('emulator test suite', () {
        test('functions/test/firestore_rules.test.mjs exists', () {
          final candidates = [
            File('../functions/test/firestore_rules.test.mjs'),
            File('functions/test/firestore_rules.test.mjs'),
          ];
          final exists = candidates.any((f) => f.existsSync());
          expect(
            exists,
            isTrue,
            reason:
                'Emulator test suite not found at '
                'functions/test/firestore_rules.test.mjs',
          );
        });

        test('functions/package.json exists', () {
          final candidates = [
            File('../functions/package.json'),
            File('functions/package.json'),
          ];
          final exists = candidates.any((f) => f.existsSync());
          expect(
            exists,
            isTrue,
            reason: 'package.json not found at functions/package.json',
          );
        });

        test('CI workflow has firestore-rules job', () {
          final candidates = [
            File('../.github/workflows/ci.yml'),
            File('.github/workflows/ci.yml'),
          ];
          String? ciContent;
          for (final f in candidates) {
            if (f.existsSync()) {
              ciContent = f.readAsStringSync();
              break;
            }
          }
          expect(ciContent, isNotNull, reason: 'ci.yml not found');
          expect(
            ciContent,
            contains('firestore-rules:'),
            reason: 'CI does not have a firestore-rules job',
          );
        });
      });
    },
  );
}

/// Extracts the text of the `match /<collectionPattern>` block for
/// [collectionPattern] from [rules].
///
/// The match statement itself may contain `{` characters as part of the path
/// pattern (e.g. `{eventId}`), so we skip to the end of the match line
/// before starting brace-depth counting.
String _extractBlock(String rules, String collectionPattern) {
  final startPattern = 'match /$collectionPattern';
  final startIndex = rules.indexOf(startPattern);
  if (startIndex == -1) return '';

  // Find the end of the match declaration line (the opening `{` of the block).
  // Skip past the pattern itself to avoid counting `{` inside `{eventId}`.
  var i = startIndex + startPattern.length;

  // Advance to the first `{` that opens the rule block (not a path param).
  // The match declaration ends at `{` after the closing `)` or newline.
  // We look for a `{` that is preceded by a newline or space, not by `/`.
  while (i < rules.length && rules[i] != '{') {
    i++;
  }

  if (i >= rules.length) return rules.substring(startIndex);

  // Now do depth counting from the opening `{`.
  var depth = 0;

  while (i < rules.length) {
    final ch = rules[i];
    if (ch == '{') {
      depth++;
    } else if (ch == '}') {
      depth--;
      if (depth == 0) {
        return rules.substring(startIndex, i + 1);
      }
    }
    i++;
  }

  return rules.substring(startIndex);
}
