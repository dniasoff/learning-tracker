/// Golden-branch pinning for the single canonical conflict-resolution
/// module, `lib/data/firestore/conflict.dart` (AD-7, AD-29 tier 1).
///
/// Two jobs:
///
///  1. **Pin every branch of [canonicalRemoteIsNewer] with a golden case** —
///     the ±5 s clock-skew window (including its exact, inclusive boundary),
///     the `synced_at` server-timestamp tie-break, the D15
///     prefer-newer-un-pushed-local fallback, and remote-wins-on-the-true-tie.
///     A change to any branch has to change a golden here, which makes it a
///     deliberate act rather than an accident.
///
///  2. **Close the hand-copy-drift class (AUD-t-cross-68).** The golden table
///     below is also run against `_driftedNoD15RemoteIsNewer` — a faithful
///     reproduction of the drifted hand-copy that actually shipped: identical
///     to the canonical rule except that it omits the D15 fallback and
///     blindly prefers remote once no decisive `synced_at` is available. The
///     suite asserts the table **catches** that copy (it must disagree, and
///     specifically on the lost-update case). If someone ever weakens the
///     goldens to the point where a drifted copy would slip through, this
///     test fails.
///
/// TQ-6: pure Dart, fixed timestamps, no wall clock, no I/O, no shared
/// mutable state — order-independent under
/// `--test-randomize-ordering-seed=random`.
library;

import 'package:learning_tracker/data/firestore/conflict.dart';
import 'package:test/test.dart';

// ─── The drifted hand-copy (AUD-t-cross-68) ──────────────────────────────────

/// The defect, reproduced exactly: everything the canonical predicate does
/// EXCEPT the D15 fallback. Once no decisive `synced_at` is available inside
/// the clock-skew window it blindly returns `true`, so a strictly-newer
/// un-pushed LOCAL edit is silently clobbered by an OLDER remote value.
///
/// This exists only so the goldens can be shown to have teeth. It is never
/// called by production code.
bool _driftedNoD15RemoteIsNewer({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
  DateTime? localSyncedAt,
  DateTime? remoteSyncedAt,
}) {
  if (remoteUpdatedAt == null) return false;
  if (localUpdatedAt == null) return true;

  final localUtc = localUpdatedAt.toUtc();
  final remoteUtc = remoteUpdatedAt.toUtc();
  final diff = remoteUtc.difference(localUtc).abs();

  if (diff > kClockSkewTieBreakWindow) {
    return remoteUtc.isAfter(localUtc);
  }
  if (remoteSyncedAt != null && localSyncedAt != null) {
    if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
    if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
  }
  // ── the drift: no D15 comparison, remote just wins ──
  return true;
}

// ─── Golden table ────────────────────────────────────────────────────────────

typedef _Case = ({
  String name,
  DateTime? localUpdatedAt,
  DateTime? remoteUpdatedAt,
  DateTime? localSyncedAt,
  DateTime? remoteSyncedAt,
  bool expected,
});

_Case _c({
  required String name,
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
  DateTime? localSyncedAt,
  DateTime? remoteSyncedAt,
  required bool expected,
}) => (
  name: name,
  localUpdatedAt: localUpdatedAt,
  remoteUpdatedAt: remoteUpdatedAt,
  localSyncedAt: localSyncedAt,
  remoteSyncedAt: remoteSyncedAt,
  expected: expected,
);

final _base = DateTime.utc(2026, 5, 21, 12);

/// One golden per branch (plus the boundary cases that decide which branch
/// is taken at all).
final List<_Case> _goldens = [
  // ── Rule 1/2 — null handling ───────────────────────────────────────────
  _c(
    name: 'rule 1 — null remote updated_at → local keeps the row',
    localUpdatedAt: _base,
    remoteUpdatedAt: null,
    expected: false,
  ),
  _c(
    name: 'rule 1 — null on both sides → local keeps the row',
    localUpdatedAt: null,
    remoteUpdatedAt: null,
    expected: false,
  ),
  _c(
    name: 'rule 2 — null local updated_at → remote wins on first sync',
    localUpdatedAt: null,
    remoteUpdatedAt: _base,
    expected: true,
  ),

  // ── Rule 3 — outside the ±5 s clock-skew window ────────────────────────
  _c(
    name: 'rule 3 — outside the window, remote strictly newer → applies',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(hours: 1)),
    expected: true,
  ),
  _c(
    name: 'rule 3 — outside the window, remote older → rejected',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.subtract(const Duration(hours: 1)),
    expected: false,
  ),
  _c(
    name:
        'rule 3 — outside the window, remote newer, and a NEWER local '
        'synced_at does NOT rescue local (the tie-break is window-scoped)',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(hours: 1)),
    localSyncedAt: _base.add(const Duration(hours: 9)),
    remoteSyncedAt: _base,
    expected: true,
  ),

  // ── Window boundary — inclusive at exactly 5 s, on both signs ──────────
  // At exactly ±5 s the pair is still INSIDE the window, so the decisive
  // local synced_at wins even though remote's updated_at looks newer. One
  // millisecond further out and rule 3 takes over and remote wins.
  _c(
    name:
        'boundary — remote exactly +5 s is INSIDE the window '
        '(local synced_at still decides)',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 5)),
    localSyncedAt: _base.add(const Duration(minutes: 1)),
    remoteSyncedAt: _base,
    expected: false,
  ),
  _c(
    name:
        'boundary — remote +5 s 1 ms is OUTSIDE the window '
        '(strict updated_at comparison takes over)',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 5, milliseconds: 1)),
    localSyncedAt: _base.add(const Duration(minutes: 1)),
    remoteSyncedAt: _base,
    expected: true,
  ),
  _c(
    name:
        'boundary — the window is symmetric: remote exactly -5 s is '
        'INSIDE (remote synced_at still decides)',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.subtract(const Duration(seconds: 5)),
    localSyncedAt: _base,
    remoteSyncedAt: _base.add(const Duration(minutes: 1)),
    expected: true,
  ),
  _c(
    name:
        'boundary — remote -5 s 1 ms is OUTSIDE the window, so an older '
        'remote loses however new its synced_at is',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.subtract(
      const Duration(seconds: 5, milliseconds: 1),
    ),
    localSyncedAt: _base,
    remoteSyncedAt: _base.add(const Duration(minutes: 1)),
    expected: false,
  ),

  // ── Rule 4 — synced_at server-timestamp tie-break ──────────────────────
  _c(
    name: 'rule 4 — inside the window, remote synced_at newer → applies',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 2)),
    localSyncedAt: _base.add(const Duration(seconds: 5)),
    remoteSyncedAt: _base.add(const Duration(seconds: 10)),
    expected: true,
  ),
  _c(
    name:
        'rule 4 — D15 fast-clock case: remote updated_at LOOKS newer but '
        'the server recorded it as pushed first → rejected',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 2)),
    localSyncedAt: _base.add(const Duration(seconds: 5)),
    remoteSyncedAt: _base.subtract(const Duration(seconds: 10)),
    expected: false,
  ),
  _c(
    name:
        'rule 4 — only the REMOTE side has a synced_at → not decisive, '
        'falls through to D15 (which keeps the newer local)',
    localUpdatedAt: _base.add(const Duration(seconds: 2)),
    remoteUpdatedAt: _base,
    localSyncedAt: null,
    remoteSyncedAt: _base.add(const Duration(hours: 1)),
    expected: false,
  ),
  _c(
    name:
        'rule 4 — only the LOCAL side has a synced_at → not decisive, '
        'falls through to D15 (which takes the newer remote)',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 2)),
    localSyncedAt: _base.add(const Duration(hours: 1)),
    remoteSyncedAt: null,
    expected: true,
  ),

  // ── Rule 5 — D15 prefer-newer-un-pushed-local ──────────────────────────
  // THE AUD-t-cross-68 lost-update: inside the window, no decisive server
  // timestamp, and the local edit is strictly newer. Blindly preferring
  // remote here clobbers a newer un-pushed local edit with an OLDER value.
  _c(
    name:
        'rule 5 (D15) — newer un-pushed local vs older remote, no '
        'synced_at anywhere → local is NOT clobbered',
    localUpdatedAt: _base.add(const Duration(seconds: 3)),
    remoteUpdatedAt: _base,
    expected: false,
  ),
  _c(
    name:
        'rule 5 (D15) — newer un-pushed local vs older remote, equal '
        'synced_at on both sides → local is NOT clobbered',
    localUpdatedAt: _base.add(const Duration(seconds: 3)),
    remoteUpdatedAt: _base,
    localSyncedAt: _base.add(const Duration(hours: 2)),
    remoteSyncedAt: _base.add(const Duration(hours: 2)),
    expected: false,
  ),
  _c(
    name:
        'rule 5 (D15) — newer remote vs older local, no synced_at '
        'anywhere → remote applies',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base.add(const Duration(seconds: 3)),
    expected: true,
  ),

  // ── Rule 6 — the one true tie → remote wins (convergence) ──────────────
  _c(
    name:
        'rule 6 — equal updated_at, no synced_at → remote wins so two '
        'devices converge instead of bouncing',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base,
    expected: true,
  ),
  _c(
    name: 'rule 6 — equal updated_at AND equal synced_at → remote wins',
    localUpdatedAt: _base,
    remoteUpdatedAt: _base,
    localSyncedAt: _base.add(const Duration(hours: 1)),
    remoteSyncedAt: _base.add(const Duration(hours: 1)),
    expected: true,
  ),

  // ── Time-zone normalisation ────────────────────────────────────────────
  // `updated_at` values are normalised to UTC before comparison, so a
  // non-UTC local value expressing the SAME instant is still a true tie.
  _c(
    name:
        'updated_at is compared in UTC — a non-UTC local value at the '
        'same instant is still the true tie',
    localUpdatedAt: _base.toLocal(),
    remoteUpdatedAt: _base,
    expected: true,
  ),
];

void main() {
  group('canonicalRemoteIsNewer — golden branch pinning (AD-29 tier 1)', () {
    for (final g in _goldens) {
      test(g.name, () {
        expect(
          canonicalRemoteIsNewer(
            localUpdatedAt: g.localUpdatedAt,
            remoteUpdatedAt: g.remoteUpdatedAt,
            localSyncedAt: g.localSyncedAt,
            remoteSyncedAt: g.remoteSyncedAt,
          ),
          g.expected,
          reason: g.name,
        );
      });
    }

    test('the predicate is deterministic — the same inputs always '
        'produce the same answer', () {
      for (final g in _goldens) {
        final first = canonicalRemoteIsNewer(
          localUpdatedAt: g.localUpdatedAt,
          remoteUpdatedAt: g.remoteUpdatedAt,
          localSyncedAt: g.localSyncedAt,
          remoteSyncedAt: g.remoteSyncedAt,
        );
        final second = canonicalRemoteIsNewer(
          localUpdatedAt: g.localUpdatedAt,
          remoteUpdatedAt: g.remoteUpdatedAt,
          localSyncedAt: g.localSyncedAt,
          remoteSyncedAt: g.remoteSyncedAt,
        );
        expect(second, first, reason: g.name);
      }
    });

    test('the clock-skew window is ±5 s', () {
      expect(kClockSkewTieBreakWindow, const Duration(seconds: 5));
    });
  });

  // ── Red demo: the goldens catch the hand-copy that actually shipped ─────
  group('hand-copy drift is caught (AUD-t-cross-68 red demo)', () {
    test('the drifted no-D15 copy FAILS the golden table', () {
      final disagreements = <String>[];
      for (final g in _goldens) {
        final drifted = _driftedNoD15RemoteIsNewer(
          localUpdatedAt: g.localUpdatedAt,
          remoteUpdatedAt: g.remoteUpdatedAt,
          localSyncedAt: g.localSyncedAt,
          remoteSyncedAt: g.remoteSyncedAt,
        );
        if (drifted != g.expected) disagreements.add(g.name);
      }

      expect(
        disagreements,
        isNotEmpty,
        reason:
            'The golden table must have teeth: a second implementation that '
            'omits the D15 fallback (the exact AUD-t-cross-68 defect) has to '
            'fail at least one golden. If this list is empty the goldens '
            'have been weakened to the point where a drifted hand-copy could '
            'ship unnoticed.',
      );
    });

    test('specifically, the drifted copy re-opens the lost-update: it '
        'clobbers a newer un-pushed local edit with an OLDER remote', () {
      final newerLocal = _base.add(const Duration(seconds: 3));
      final olderRemote = _base;

      expect(
        canonicalRemoteIsNewer(
          localUpdatedAt: newerLocal,
          remoteUpdatedAt: olderRemote,
        ),
        isFalse,
        reason: 'canonical: D15 keeps the strictly-newer local edit',
      );
      expect(
        _driftedNoD15RemoteIsNewer(
          localUpdatedAt: newerLocal,
          remoteUpdatedAt: olderRemote,
        ),
        isTrue,
        reason:
            'drifted copy: blindly prefers remote — the shipped lost-update. '
            'The canonical/drifted disagreement here is what the golden '
            'table pins.',
      );
    });
  });

  // ── FB-3 cache-echo guard (MCF-26) ─────────────────────────────────────
  group('isUnresolvedSnapshotMetadata — FB-3 cache-echo guard', () {
    test('an un-acked local write is unresolved', () {
      expect(
        isUnresolvedSnapshotMetadata(
          hasPendingWrites: true,
          isFromCache: false,
        ),
        isTrue,
      );
    });

    test('a cache-only read is unresolved', () {
      expect(
        isUnresolvedSnapshotMetadata(
          hasPendingWrites: false,
          isFromCache: true,
        ),
        isTrue,
      );
    });

    test('both flags set is unresolved', () {
      expect(
        isUnresolvedSnapshotMetadata(hasPendingWrites: true, isFromCache: true),
        isTrue,
      );
    });

    test('a server-confirmed document is resolved and merges normally', () {
      expect(
        isUnresolvedSnapshotMetadata(
          hasPendingWrites: false,
          isFromCache: false,
        ),
        isFalse,
      );
    });
  });
}
