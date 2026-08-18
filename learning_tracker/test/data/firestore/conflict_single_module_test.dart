/// Grep-gated single-module check for the canonical conflict predicate
/// (AD-7, AD-28, AD-29 tier 1).
///
/// The golden-branch pinning in `conflict_test.dart` proves the predicate is
/// *correct*. It cannot prove the predicate is *singular* — a second,
/// hand-copied implementation somewhere else in `lib/` would sail past it,
/// which is exactly how AUD-t-cross-68 shipped a lost-update bug. This file
/// closes that hole structurally: it scans `lib/` source text and fails if
/// any reconciliation path re-implements the rule instead of calling
/// `lib/data/firestore/conflict.dart`.
///
/// TQ-6: reads source files only — no network, no clock, no shared mutable
/// state; order-independent.
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../helpers/lib_source.dart';

const _conflictModule = 'lib/data/firestore/conflict.dart';

/// Drops whole-line `//` and `///` comments so prose that *describes* the
/// rule ("instead of the plain `remote.isAfter(local)` comparison") is not
/// mistaken for a re-implementation of it.
String _stripLineComments(String src) =>
    src.split('\n').where((l) => !l.trimLeft().startsWith('//')).join('\n');

/// Every `lib/**.dart` file, as (repo-relative-ish path → source text).
Map<String, String> _libSources() {
  final root = projectRoot();
  final libDir = Directory('${root.path}/lib');
  final prefix = '${libDir.path.replaceAll(r'\', '/')}/';
  final out = <String, String>{};
  for (final entity in libDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (!path.endsWith('.dart')) continue;
    if (path.endsWith('.g.dart') || path.endsWith('.freezed.dart')) continue;
    // Normalise to a `lib/...` relative path.
    out['lib/${path.substring(prefix.length)}'] = entity.readAsStringSync();
  }
  return out;
}

void main() {
  group('AD-7 — the LWW predicate exists in exactly one module', () {
    late Map<String, String> sources;

    setUp(() {
      sources = _libSources();
    });

    test('the canonical module exists and declares the predicate', () {
      expect(
        sources.containsKey(_conflictModule),
        isTrue,
        reason:
            '$_conflictModule must exist — it is the single owner of the '
            'LWW decision (AD-7)',
      );
      expect(
        sources[_conflictModule],
        contains('bool canonicalRemoteIsNewer({'),
        reason: '$_conflictModule must declare the canonical predicate',
      );
    });

    test('exactly one lib/ file declares canonicalRemoteIsNewer', () {
      final declarers =
          sources.entries
              .where((e) => e.value.contains('bool canonicalRemoteIsNewer({'))
              .map((e) => e.key)
              .toList()
            ..sort();
      expect(
        declarers,
        [_conflictModule],
        reason:
            'A second declaration is a hand-copy waiting to drift '
            '(AUD-t-cross-68). Call the canonical predicate instead.',
      );
    });

    test('exactly one lib/ file declares the ±5 s clock-skew window', () {
      final declarers =
          sources.entries
              .where((e) => e.value.contains('kClockSkewTieBreakWindow ='))
              .map((e) => e.key)
              .toList()
            ..sort();
      expect(
        declarers,
        [_conflictModule],
        reason:
            'The window constant belongs to the canonical module; a second '
            'definition can silently diverge from it.',
      );
    });

    test('no lib/ file declares a top-level free `remoteIsNewer` predicate '
        '(the deleted merge_rules.dart shape)', () {
      // A top-level (column-0) `bool remoteIsNewer(` declaration is the
      // superseded merge_rules.dart copy. `MergeStore.remoteIsNewer` and its
      // DriftMergeStore override are class members (indented) and are the
      // legitimate delegating seam, so they are not matched here.
      final topLevel = RegExp(r'^bool remoteIsNewer\(', multiLine: true);
      final offenders =
          sources.entries
              .where((e) => topLevel.hasMatch(e.value))
              .map((e) => e.key)
              .toList()
            ..sort();
      expect(
        offenders,
        isEmpty,
        reason:
            'merge_rules.dart`s plain predicate was removed under AD-7; a '
            'free LWW predicate must not reappear outside $_conflictModule.',
      );
    });

    test('no lib/ file re-implements the synced_at tie-break outside the '
        'canonical module', () {
      // The tell-tale of a re-implementation: a file that reasons about BOTH
      // sides' `synced_at` AND performs its own instant comparison, without
      // delegating to the canonical predicate.
      final offenders = <String>[];
      sources.forEach((path, rawSrc) {
        if (path == _conflictModule) return;
        final src = _stripLineComments(rawSrc);
        // Delegating seams are the point of AD-7, not violations of it.
        if (src.contains('canonicalRemoteIsNewer(')) return;
        if (src.contains('_store.remoteIsNewer(')) return;
        final reasonsAboutBothSyncedAt =
            src.contains('localSyncedAt') && src.contains('remoteSyncedAt');
        if (reasonsAboutBothSyncedAt && src.contains('.isAfter(')) {
          offenders.add(path);
        }
      });
      offenders.sort();
      expect(
        offenders,
        isEmpty,
        reason:
            'These files appear to arbitrate LWW themselves. Route the '
            'decision through canonicalRemoteIsNewer in $_conflictModule '
            '(AD-7 — no per-merger exception).',
      );
    });
  });

  group('AD-7 — the module is dormant by design (no reconciliation path '
      'exists)', () {
    late Map<String, String> sources;

    setUp(() {
      sources = _libSources();
    });

    // Firestore resolves concurrent writes server-side ("one writer per
    // account" — see the module doc comment), so nothing in lib/ currently
    // calls the predicate. That is a deliberate, documented owner decision
    // (docs/firestore-rewrite-map.md), not migration debt. If a genuine
    // second-writer scenario reappears, wire a caller deliberately and
    // update this test rather than leaving it stale.
    test('no lib/ file outside $_conflictModule calls canonicalRemoteIsNewer '
        'or isUnresolvedSnapshotMetadata', () {
      final callers = <String>[];
      sources.forEach((path, src) {
        if (path == _conflictModule) return;
        if (src.contains('canonicalRemoteIsNewer(') ||
            src.contains('isUnresolvedSnapshotMetadata(')) {
          callers.add(path);
        }
      });
      callers.sort();
      expect(
        callers,
        isEmpty,
        reason:
            '$_conflictModule is dormant by design — a caller appearing '
            'here means a second-writer scenario has returned and this '
            'test needs a deliberate update, not a silent pass.',
      );
    });

    test('the superseded merge_rules.dart predicate is gone', () {
      expect(
        sources.containsKey('lib/core/sync/merge/merge_rules.dart'),
        isFalse,
        reason:
            'merge_rules.dart held a second, weaker LWW predicate and had '
            'zero production callers; AD-7 requires it removed.',
      );
    });

    test('the canonical module stays pure — no cloud_firestore import', () {
      // Story 2.5 lands BEFORE Story 2.6 widens the Firebase-confinement
      // grep to lib/data/firestore/**, so an SDK import here would trip
      // `make audit`. It is also what keeps the predicate unit-testable
      // without a Firestore fake (AD-29).
      expect(
        _stripLineComments(sources[_conflictModule]!),
        isNot(contains('cloud_firestore')),
        reason:
            '$_conflictModule must take plain DateTime/bool/Duration values; '
            'callers pass synced_at and the FB-3 metadata flags in.',
      );
    });
  });
}
