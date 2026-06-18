@Tags(['contract'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// ── Oracle #1: the client↔server schema contract ────────────────────────────
///
/// THE BUG CLASS THIS KILLS
/// ------------------------
/// Firestore has TWO schemas that must agree but were never diffed:
///   * The CLIENT write shape — what a codec's `encode()` emits.
///   * The SERVER accept shape — the `hasOnly([...])` field allowlist in
///     `firestore.rules`.
/// When a codec emits a field the rule doesn't list, the *real* Firestore
/// rejects the entire write with PERMISSION_DENIED. The app swallows that error
/// ("local DB is source of truth"), so it is invisible to UI-level E2E and to
/// `make ci` (which uses `fake_cloud_firestore`, a fake that does NOT enforce
/// rules). This test makes the mismatch fail FAST and LOCALLY — milliseconds,
/// no emulator — instead of three weeks later on a real device.
///
/// HOW IT WORKS
/// ------------
/// Statically parses both schemas straight from source — single source of
/// truth, zero hand-maintained fixtures to drift:
///   * `firestore.rules`  → {collection: allowed keys}
///   * `lib/core/sync/codec/*_codec.dart` `encode()` → {collection: emitted keys}
/// then asserts emitted ⊆ allowed for every whitelisted collection.
///
/// KNOWN SCOPE (documented, not silent — see Oracle table in the test plan)
/// ------------------------------------------------------------------------
/// Covers the centralized codec write path. A few live writes bypass the codec
/// (e.g. repo-injected `id`/`profile_id`, gateway `synced_at`). Those extras are
/// either already in every rule allowlist (`synced_at`) or are tracked by
/// follow-up work to route all writes through the codecs. This test is the
/// floor, not the ceiling — Oracle #2 (emulator-enforced rules in CI) backstops
/// anything static analysis cannot model.

/// Collections whose rule uses a `hasOnly([...])` allowlist AND that have a
/// codec defining the client write shape. Open-ended bags (settings,
/// preferences), append-only event collections (completions, streak_events,
/// learning_ledger, points_ledger), and server-only collections (tutor_grants)
/// intentionally have no `hasOnly` and are excluded.
const _codecForCollection = <String, String>{
  'bookmarks': 'lib/core/sync/codec/bookmark_codec.dart',
  'goals': 'lib/core/sync/codec/goal_codec.dart',
  'learning_order': 'lib/core/sync/codec/learning_order_codec.dart',
  'profile_programs': 'lib/core/sync/codec/profile_program_codec.dart',
  'stage_definitions': 'lib/core/sync/codec/stage_definition_codec.dart',
  'study_day_configs': 'lib/core/sync/codec/study_day_config_codec.dart',
  'curriculum_tracks': 'lib/core/sync/codec/track_codec.dart',
};

/// LIVE write-path serializers: the `toFirestore()` method that actually builds
/// the push payload for a collection (distinct from the codec's `encode()`,
/// which is currently decode-companion for some entities). Repos layer a few
/// rule-legal keys on top (id/profile_id/sefaria_ref/stage_id) — those are in
/// `_serverInjectedKeys` so they don't read as drift. This is the half of the
/// contract that guards what the app *actually writes* today; Phase B will
/// collapse encode()/toFirestore() into one serializer so both maps converge.
const _toFirestoreForCollection = <String, String>{
  'goals': 'lib/features/scheduler/domain/models/goal_entity.dart',
  'bookmarks': 'lib/features/learning/domain/entities/bookmark.dart',
};

/// Keys injected outside the serializer (gateway `FieldValue.serverTimestamp()`,
/// or repo/facade layers that add the doc id and scope keys after
/// `toFirestore()`). All are themselves rule-legal; listing them here keeps the
/// ⊆-check from flagging them as drift just because they're added elsewhere.
const _serverInjectedKeys = <String>{
  'synced_at',
  'id',
  'goal_id',
  'profile_id',
  'sefaria_ref',
  'stage_id',
};

void main() {
  group('codec ↔ firestore.rules contract', () {
    final rulesFile = File('firestore.rules');

    test('firestore.rules is present at the package root', () {
      expect(
        rulesFile.existsSync(),
        isTrue,
        reason:
            'Expected firestore.rules at the flutter package root. Run this '
            'test from learning_tracker/ (working dir = package root).',
      );
    });

    final ruleWhitelists = _parseRuleWhitelists(rulesFile.readAsStringSync());

    test('rules parser found the expected hasOnly collections', () {
      // Guard against a silent parser regression: if the rules format changes
      // and we extract nothing, every ⊆ check would vacuously pass.
      for (final collection in _codecForCollection.keys) {
        expect(
          ruleWhitelists.containsKey(collection),
          isTrue,
          reason:
              'Could not extract a hasOnly() allowlist for "$collection" from '
              'firestore.rules. The rules format may have changed — update the '
              'parser in this test.',
        );
      }
    });

    for (final entry in _codecForCollection.entries) {
      final collection = entry.key;
      final codecPath = entry.value;

      test('$collection: codec emits only fields the rule accepts', () {
        final allowed = ruleWhitelists[collection] ?? const <String>{};
        final emitted = _parseMethodMapKeys(
          File(codecPath).readAsStringSync(),
          'encode',
        );

        expect(
          emitted,
          isNotEmpty,
          reason: 'Failed to parse any encoded keys from $codecPath',
        );

        final offending = emitted
            .difference(allowed)
            .difference(_serverInjectedKeys)
            .toList()
          ..sort();

        expect(
          offending,
          isEmpty,
          reason:
              '\n\nPERMISSION_DENIED RISK — $collection\n'
              '$codecPath emits field(s) NOT in the firestore.rules '
              'hasOnly() allowlist:\n'
              '    ${offending.join(', ')}\n\n'
              'Every write of one of these fields is rejected by the real '
              'Firestore (the fake used in `make ci` does not enforce rules, '
              'so this is otherwise invisible until a real device).\n'
              'FIX: either add the field(s) to the `$collection` hasOnly() list '
              'in firestore.rules AND `firebase deploy --only firestore:rules`, '
              'or stop emitting them from the codec.\n',
        );
      });
    }

    // ── Live write path — toFirestore() builders ────────────────────────────
    for (final entry in _toFirestoreForCollection.entries) {
      final collection = entry.key;
      final sourcePath = entry.value;

      test('$collection: live toFirestore() emits only fields the rule accepts', () {
        final allowed = ruleWhitelists[collection] ?? const <String>{};
        final emitted = _parseMethodMapKeys(
          File(sourcePath).readAsStringSync(),
          'toFirestore',
        );

        expect(
          emitted,
          isNotEmpty,
          reason: 'Failed to parse toFirestore() keys from $sourcePath',
        );

        final offending = emitted
            .difference(allowed)
            .difference(_serverInjectedKeys)
            .toList()
          ..sort();

        expect(
          offending,
          isEmpty,
          reason:
              '\n\nPERMISSION_DENIED RISK — $collection (LIVE write path)\n'
              '$sourcePath toFirestore() emits field(s) NOT in the '
              'firestore.rules hasOnly() allowlist:\n'
              '    ${offending.join(', ')}\n\n'
              'This is the payload the app ACTUALLY writes — a real device will '
              'get PERMISSION_DENIED and the failure is swallowed (offline-first), '
              'so it only shows as a "Backup & Sync unavailable" banner.\n'
              'FIX: add the field(s) to the `$collection` hasOnly() list in '
              'firestore.rules AND `firebase deploy --only firestore:rules`, or '
              'stop emitting them.\n',
        );
      });
    }
  });
}

/// Parse `match /<collection>/{...}` blocks out of firestore.rules and, for each,
/// extract the field names inside its first `hasOnly([...])` (if any).
Map<String, Set<String>> _parseRuleWhitelists(String rules) {
  final result = <String, Set<String>>{};
  final matchRe = RegExp(r'match\s+/(\w+)/\{');
  final hasOnlyRe = RegExp(r'hasOnly\(\[([^\]]*)\]\)', dotAll: true);
  final keyRe = RegExp("'([^']+)'");

  final matches = matchRe.allMatches(rules).toList();
  for (var i = 0; i < matches.length; i++) {
    final collection = matches[i].group(1)!;
    final segmentStart = matches[i].end;
    final segmentEnd = (i + 1 < matches.length)
        ? matches[i + 1].start
        : rules.length;
    final segment = rules.substring(segmentStart, segmentEnd);

    final hasOnly = hasOnlyRe.firstMatch(segment);
    if (hasOnly == null) continue;
    result[collection] = keyRe
        .allMatches(hasOnly.group(1)!)
        .map((m) => m.group(1)!)
        .toSet();
  }
  return result;
}

/// Extract the top-level string keys from a serializer method's returned map
/// literal (e.g. `encode(...)` or `toFirestore(...)`).
///
/// Handles both `=> { ... }` and `{ return { ... }; }` forms via a
/// balanced-brace scan, so conditional (`if (x != null) 'k': ...`) keys are
/// captured too. The serializers emit flat maps, so every `'key':` found is
/// top-level.
Set<String> _parseMethodMapKeys(String src, String method) {
  final encodeIdx = src.indexOf(RegExp('\\b$method\\s*\\('));
  if (encodeIdx < 0) return const <String>{};

  // Find where the returned map begins: first `{` after `=>` or `return`.
  final arrow = src.indexOf('=>', encodeIdx);
  final ret = src.indexOf('return', encodeIdx);
  var anchor = -1;
  if (arrow >= 0 && (ret < 0 || arrow < ret)) {
    anchor = arrow;
  } else if (ret >= 0) {
    anchor = ret;
  }
  if (anchor < 0) return const <String>{};

  final mapStart = src.indexOf('{', anchor);
  if (mapStart < 0) return const <String>{};

  // Balanced-brace scan to the matching `}`.
  var depth = 0;
  var mapEnd = -1;
  for (var i = mapStart; i < src.length; i++) {
    final ch = src[i];
    if (ch == '{') depth++;
    if (ch == '}') {
      depth--;
      if (depth == 0) {
        mapEnd = i;
        break;
      }
    }
  }
  if (mapEnd < 0) return const <String>{};

  final body = src.substring(mapStart + 1, mapEnd);
  // Keys are `'name':` — the colon disambiguates them from string *values*.
  return RegExp(r"'([^']+)'\s*:")
      .allMatches(body)
      .map((m) => m.group(1)!)
      .toSet();
}
