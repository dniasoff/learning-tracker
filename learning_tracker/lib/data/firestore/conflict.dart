/// The canonical conflict-resolution module (AD-7, MCF-1) — **currently
/// UNUSED, and unused by design.**
///
/// ⚠️ This header previously claimed that "every reconciliation path in the
/// app — every LWW merger, every DAO-level remote-row upsert, the listener
/// cache-echo guard — routes its ordering decision through this file". That
/// is false of EVERY path: nothing in `lib/` imports this module at all.
///
/// It is false by DESIGN, not by oversight. `docs/firestore-rewrite-map.md`
/// lists `conflict.dart` among the machinery Firestore makes unnecessary —
/// beside the merge routers, mergers, codecs, outbox/push pipeline and sync
/// orchestrator — with the rationale **"one writer per account"**. Firestore
/// resolves concurrent writes server-side, so the client has no merge
/// pipeline whose ordering needs deciding. The paths the old claim named are
/// exactly the deleted ones: "DAO-level remote-row upsert" is Drift, and the
/// outbox listener that needed the cache-echo guard no longer exists.
/// `docs/planning/epics-firestore-migration-phase2.md` had already recorded
/// this module as "called by nothing outside its own unit tests today".
///
/// Kept rather than deleted because removing it — and the two test files
/// pinning it, which Phase 0 lists as deliverables (CAP-3, AD-7, AD-29) — is
/// an owner decision, not a migration side-effect. If a genuine second writer
/// ever appears on a collection, the algorithm here is still correct and
/// still tested; wire it then. Until then, treat it as dormant.
///
/// The original rationale, still worth preserving: a hand-copied test double
/// of the LWW rule re-derived the algorithm, omitted the D15 fallback, and
/// shipped a silent lost-update bug (AUD-t-cross-68). If this is ever
/// reactivated, it must stay the ONLY implementation — a bespoke second
/// predicate elsewhere is, by construction, a drift hazard.
///
/// **This module is deliberately pure.** It takes plain `DateTime` / `bool`
/// / `Duration` values and imports nothing from `cloud_firestore`: callers
/// read the `synced_at` server timestamps and the FB-3
/// `hasPendingWrites` / `isFromCache` metadata flags out of the SDK and pass
/// them in as plain values. That keeps the decision unit-testable without a
/// Firestore fake (the fake cannot model those signals at all — AD-29) and
/// keeps this file off the Firebase-confinement grep's radar.
library;

/// Clock-skew tolerance for [canonicalRemoteIsNewer].
///
/// When two devices' client clocks differ by no more than this, the client
/// `updated_at` values are not trusted to order the two writes on their own
/// and the Firestore `synced_at` server timestamp arbitrates instead.
///
/// The boundary is **inclusive**: a difference of exactly this duration is
/// still treated as "inside the window".
const Duration kClockSkewTieBreakWindow = Duration(seconds: 5);

/// The canonical last-writer-wins predicate: `true` when the remote row
/// should overwrite the current local row.
///
/// Rule order (this is the whole algorithm — nothing else decides LWW
/// anywhere in the codebase):
///
///  1. **No remote timestamp** → `false`. Nothing to arbitrate with; keep
///     local.
///  2. **No local timestamp** → `true`. No local row has been applied yet,
///     so the remote is the only candidate ("remote wins on first sync").
///  3. **Outside the ±5 s clock-skew window**
///     (`|remote - local| > `[kClockSkewTieBreakWindow]) → the strict
///     `remote > local` comparison on the client `updated_at` decides; ties
///     go to local (the long-standing flapping-free behaviour).
///  4. **Inside the window, BOTH sides carry a `synced_at`** → the Firestore
///     server timestamp is authoritative for two already-pushed writes.
///     Strictly-newer `synced_at` wins; an exact `synced_at` tie falls
///     through to rule 5.
///  5. **D15 — inside the window, no decisive server timestamp** → at least
///     one side has not been pushed yet (it has an `updated_at` but no
///     `synced_at`). Do NOT blindly prefer remote here: that silently
///     clobbers a demonstrably-newer un-pushed local edit with an OLDER
///     remote value (this is precisely the AUD-t-cross-68 defect). Compare
///     the client `updated_at` and keep the strictly-newer side.
///  6. **The one true tie** (equal `updated_at`, no decisive server
///     timestamp) → `true`. Preferring remote makes two devices that wrote
///     the same value at the same instant converge instead of bouncing.
///
/// [localUpdatedAt] / [remoteUpdatedAt] may be in any time zone — both are
/// normalised to UTC before comparison. [localSyncedAt] / [remoteSyncedAt]
/// are compared as absolute instants ([DateTime.isAfter] is zone-agnostic).
///
/// [clockSkewWindow] is injectable for tests only; production callers must
/// use the default.
bool canonicalRemoteIsNewer({
  required DateTime? localUpdatedAt,
  required DateTime? remoteUpdatedAt,
  DateTime? localSyncedAt,
  DateTime? remoteSyncedAt,
  Duration clockSkewWindow = kClockSkewTieBreakWindow,
}) {
  // 1 / 2 — null handling.
  if (remoteUpdatedAt == null) return false;
  if (localUpdatedAt == null) return true;

  final localUtc = localUpdatedAt.toUtc();
  final remoteUtc = remoteUpdatedAt.toUtc();
  final diff = remoteUtc.difference(localUtc).abs();

  // 3 — outside the clock-skew window: strict `remote > local` wins; ties go
  // to local (matches the long-standing flapping-free behaviour).
  if (diff > clockSkewWindow) {
    return remoteUtc.isAfter(localUtc);
  }

  // 4 — inside the window: when BOTH sides carry a Firestore server
  // timestamp, it is the authoritative ordering for two already-pushed
  // writes.
  if (remoteSyncedAt != null && localSyncedAt != null) {
    if (remoteSyncedAt.isAfter(localSyncedAt)) return true;
    if (localSyncedAt.isAfter(remoteSyncedAt)) return false;
    // Equal synced_at — fall through to the updated_at / convergence tie.
  }

  // 5 — D15: at least one side has no usable server timestamp — typically a
  // fresh LOCAL edit that has `updated_at` but no `synced_at` yet (it has
  // not been pushed). Do NOT blindly prefer remote here: that silently
  // clobbers a demonstrably-newer un-pushed local edit with an OLDER remote
  // value. Compare the client `updated_at` and keep the strictly-newer side.
  if (remoteUtc.isAfter(localUtc)) return true;
  if (localUtc.isAfter(remoteUtc)) return false;

  // 6 — the one true tie (equal `updated_at`, no decisive server timestamp)
  // is resolved by preferring remote so two devices that wrote the same
  // value at the same instant converge instead of bouncing.
  return true;
}

/// The FB-3 local-echo / cache-echo guard, as a pure predicate (MCF-26).
///
/// A snapshot document is **unresolved** — and must not be fed to the merge
/// pipeline as authoritative for LWW — while it is either:
///   - an un-acked local write ([hasPendingWrites]) — re-processing this
///     device's own write through the merge pipeline would loop it, or
///   - an unconfirmed read served purely from the SDK's on-disk persistence
///     cache ([isFromCache]) — e.g. the first snapshot delivered on listener
///     reattach, before the live snapshot catches up.
///
/// Neither case has arrived via a server round-trip, so neither has a
/// resolved `FieldValue.serverTimestamp()` yet; treating either as
/// authoritative risks clobbering fresher local state with data the server
/// may already have superseded.
///
/// Callers read the two flags off `SnapshotMetadata` and pass them in — this
/// module never imports `cloud_firestore` (see the library doc comment).
bool isUnresolvedSnapshotMetadata({
  required bool hasPendingWrites,
  required bool isFromCache,
}) => hasPendingWrites || isFromCache;
