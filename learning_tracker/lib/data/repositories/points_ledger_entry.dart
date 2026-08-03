import 'package:learning_tracker/core/codec/firestore_codec.dart';
import 'package:learning_tracker/features/learning/domain/entities/completion_source.dart';

/// Domain model for one append-only `points_ledger/{ulid}` document
/// (`docs/firestore-rewrite-map.md`, `firestore.rules` `match
/// /points_ledger/{entryId}`).
///
/// **Firestore-shaped, built directly against the target schema — there is
/// no portable Drift-era domain model to port from.** `PointsLedgerData`
/// (`lib/core/database/tables/points_balance.dart`'s generated Drift row) is
/// a device-local row: autoincrement `id`, local-int `profileId`, local-int
/// `redemptionId` FK — none of it survives the rewrite (AD-5: no
/// autoincrement id may appear inside a synced payload).
///
/// **Lives under `lib/data/repositories/`, not `lib/features/**`.** Its two
/// closest siblings — [LearningLedgerEntryFirestoreCodec]'s
/// `LearningLedgerEntry` and `StreakEventEntry` — each got a brand-new
/// Firestore-shaped model too, but both live inside their owning feature's
/// `domain/entities/` (`lib/features/learning/...`,
/// `lib/features/gamification/...`). This entity has no such feature-domain
/// home available in this build (this task's scope is `lib/data/**` only,
/// deliberately not `lib/features/**` — concurrent work is underway there).
/// Colocating it with [FirestorePointsLedgerRepository] instead of inventing
/// a new `lib/features/gamification/...` file needs no new dependency-gate
/// carve-out either way: `tool/check_dependency_direction.dart` (check 102)
/// already exempts any path containing the segment `/data/repositories/`
/// from the "a domain model may only reach `lib/data/firestore/` via that
/// segment" rule, and this file's path satisfies that regardless of which
/// side of the boundary it is considered to sit on. Flagged as a deliberate
/// placement call, not an oversight — a future rewire of the gamification
/// feature onto Firestore may want to move this into
/// `lib/features/gamification/...` once that directory is back in scope;
/// nothing here depends on staying put.
///
/// ### What changed vs. the Drift `PointsLedger` row
///
/// - **No autoincrement `id`.** [ulid] is this entry's only identity, and IS
///   the Firestore doc-id (`DocIds.pointsLedgerDocId`). `UNIQUE(profileId,
///   ulid)` (MCF-8, schema v34) depended on this same ulid; the Firestore
///   doc-id formula continues that invariant directly.
/// - **No `profileId`.** Already the path segment above this subcollection
///   (`users/{uid}/learner_profiles/{profileId}/points_ledger/{ulid}`).
/// - **No `redemptionId`.** The Drift column is a local-int FK →
///   `RewardRedemptions.id` — exactly the kind of device-local autoincrement
///   id AD-5 forbids inside a payload (MCF-11). [redemptionUlid] carries
///   that redemption's own stable ulid instead, mirroring
///   `PointsBalanceDao._redemptionUlidFor`'s resolution. `RewardRedemptions`
///   is a separate, MUTABLE state machine (`docs/firestore-rewrite-map.md`)
///   — out of this repository's scope entirely; this entry only ever carries
///   a REFERENCE to one, never redemption data itself.
/// - **[entryKind] and [delta] are both preserved as-is** — the actual
///   economic content of the row, unchanged from the Drift column shapes.
///
/// **[source] is new — added for the same reason
/// `LearningLedgerEntry.source` was.** See that class's doc comment ("
/// [source] is new") for the fuller reasoning: a downstream cleanup sweep
/// (e.g. retracting a bulk-mark's side effects) needs to distinguish a
/// `live` points award — the one class of entry that may never be silently
/// retracted — from a `bulkInTrack`/`lifetimeOnly` entry that should never
/// have credited engagement points in the first place. See
/// [PointsLedgerEntryFirestoreCodec.toFirestore] /
/// [pointsLedgerEntryFromFirestore] for the encoding, and the latter's doc
/// comment for why a missing/unrecognised value decodes as
/// [CompletionSource.live] rather than throwing — the same fail-safe
/// direction `LearningLedgerEntry` uses.
class PointsLedgerEntry {
  const PointsLedgerEntry({
    required this.ulid,
    required this.entryKind,
    required this.delta,
    required this.createdAt,
    required this.source,
    this.note,
    this.redemptionUlid,
  });

  /// This entry's identity — also its Firestore doc-id
  /// (`DocIds.pointsLedgerDocId`, keyed off this same value). Never
  /// re-derived on a retry — see
  /// [FirestorePointsLedgerRepository.append]'s doc comment.
  final String ulid;

  /// `'completion'` | `'redemption_debit'` | `'redemption_refund'` |
  /// `'parent_add'` | `'parent_deduct'` — plain `String`, matching the Drift
  /// column (`PointsLedger.entryKind`); no enum exists for this field.
  final String entryKind;

  /// Signed delta applied to the derived balance
  /// ([FirestorePointsLedgerRepository.getBalance]). Positive = credit;
  /// negative = debit.
  final int delta;

  /// Optional description (note from parent, reward title, etc.).
  final String? note;

  /// The referenced redemption's own stable ulid (`reward_redemptions/
  /// {ulid}`), for `redemption_debit`/`redemption_refund` entries — `null`
  /// for every other [entryKind]. A REFERENCE only, per the class doc
  /// comment's "No `redemptionId`" section.
  final String? redemptionUlid;

  /// Real-world instant this entry was recorded. Round-trips through a raw
  /// Firestore `timestamp`, not an ISO-8601 string — see the codec
  /// extension's doc comment for why.
  final DateTime createdAt;

  /// Which write-time policy tier produced this entry — see the class doc
  /// comment's "[source] is new" section.
  final CompletionSource source;
}

/// Firestore document codec for `points_ledger/{ulid}`. Self-contained, no
/// dependency on the old sync-engine `lib/core/sync/codec/` module — same
/// reasoning as `LearningLedgerEntryFirestoreCodec`/
/// `StreakEventEntryFirestoreCodec` (both self-contained for the same
/// reason; that whole module is marked for deletion once the sync engine
/// goes, `docs/firestore-rewrite-map.md`, "Deleted concepts").
///
/// **`created_at` is a raw [DateTime], NOT `FirestoreCodec.encodeDateTime`'s
/// ISO-8601 `String`.** Required so the field lands with real Firestore
/// `timestamp` type: `firestore.rules`' `points_ledger` create rule (SR-3)
/// requires, when `created_at` is present, that it `is timestamp` — a plain
/// Dart `String` value is type `string` in Firestore's eyes, not
/// `timestamp`, so writing one here would rules-deny every
/// [FirestorePointsLedgerRepository.append] call in production. See
/// `firestore_learning_ledger_repository.dart`'s class doc comment
/// ("`completed_at` round-trips through a real `Timestamp`") for the fuller
/// explanation of this exact trap — identical mechanism, here on
/// `created_at` instead of `completed_at`
/// (`docs/firestore-rewrite-map.md`'s trap #2 names all three: `streak_events`,
/// `learning_ledger`, `points_ledger`).
///
/// **`source` is written via [CompletionSource.name]** — same reasoning as
/// `LearningLedgerEntryFirestoreCodec`: `CompletionSource`'s three member
/// names already ARE the exact storage vocabulary, so `.name` is the single
/// source of truth, no second mapping to keep in sync. `points_ledger`'s
/// create rule has no `.hasOnly()` field whitelist (verified against
/// `firestore.rules`), so adding this key needs no rules change.
extension PointsLedgerEntryFirestoreCodec on PointsLedgerEntry {
  /// Encodes this entry for a Firestore write. [note]/[redemptionUlid] are
  /// OMITTED entirely when absent, not written as an explicit `null` — same
  /// convention `StreakEventEntryFirestoreCodec` uses for
  /// `client_device_id`, so a byte-identical replay
  /// (`firestore.rules`' SR-1 append-only update rule) never trips over a
  /// present-vs-absent-key mismatch for an optional field left unset both
  /// times.
  Map<String, dynamic> toFirestore() => {
    'ulid': ulid,
    'entry_kind': entryKind,
    'delta': delta,
    if (note != null) 'note': note,
    if (redemptionUlid != null) 'redemption_ulid': redemptionUlid,
    'created_at': createdAt.toUtc(),
    'source': source.name,
  };
}

/// Decodes a `points_ledger/{ulid}` document into a [PointsLedgerEntry].
///
/// [data]'s `created_at` must already be a [DateTime] by the time it reaches
/// here — see [FirestorePointsLedgerRepository]'s class doc comment for why
/// the repository, not this function, is responsible for converting a real
/// Firestore `Timestamp` object back into one first.
/// [FirestoreCodec.parseDateTime] still handles it either way (its `raw is
/// DateTime` branch), so this function itself needs no `cloud_firestore`
/// import.
///
/// Throws [FormatException] for a missing required field — a caller-visible
/// decode failure by design, surfaced via `resilientQueryStream`'s
/// per-document error handling (skips just that document) or
/// [FirestorePointsLedgerRepository]'s one-shot-read leniency, never
/// silently defaulted.
///
/// **`source` is the one exception to "never silently defaulted" — by
/// design, not oversight**, mirroring `learningLedgerEntryFromFirestore`
/// exactly. A document with no `source` key or an unrecognised value decodes
/// as [CompletionSource.live] rather than throwing — see [_parseSource].
/// [CompletionSource.live] is the fail-SAFE default here too: it is the one
/// value a deletion/retraction sweep keyed on `source == 'bulkInTrack'` (or
/// similar) can never match, so an entry with unknown provenance is never
/// mistakenly treated as safe to retract. Throwing instead (like every other
/// field here) would make a pre-existing, perfectly valid entry invisible
/// from every read purely because it predates this field — worse than
/// decoding it into the safe-by-construction default.
PointsLedgerEntry pointsLedgerEntryFromFirestore(Map<String, dynamic> data) {
  final ulid = data['ulid'] as String?;
  final entryKind = data['entry_kind'] as String?;
  final delta = FirestoreCodec.parseInt(data['delta']);
  final createdAt = FirestoreCodec.parseDateTime(data['created_at']);
  if (ulid == null || entryKind == null || delta == null || createdAt == null) {
    throw FormatException(
      'points_ledger document missing a required field: $data',
    );
  }

  return PointsLedgerEntry(
    ulid: ulid,
    entryKind: entryKind,
    delta: delta,
    note: data['note'] as String?,
    redemptionUlid: data['redemption_ulid'] as String?,
    createdAt: createdAt,
    source: _parseSource(data['source']),
  );
}

/// Parses `source`, defaulting to [CompletionSource.live] when [raw] is
/// missing or does not match any [CompletionSource.name] — see
/// [pointsLedgerEntryFromFirestore]'s doc comment for why this field alone
/// defaults instead of throwing.
CompletionSource _parseSource(Object? raw) {
  if (raw is String) {
    for (final value in CompletionSource.values) {
      if (value.name == raw) return value;
    }
  }
  return CompletionSource.live;
}
