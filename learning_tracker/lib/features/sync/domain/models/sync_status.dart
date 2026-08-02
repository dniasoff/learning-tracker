import 'package:freezed_annotation/freezed_annotation.dart';

part 'sync_status.freezed.dart';

/// Represents the current state of data synchronization with Firestore.
///
/// Story 1.5 / AD-11 (owner-ratified, slim 3-state sync status): this union
/// was collapsed from a 7-case shape (`localOnly`/`syncing`/`synced`/
/// `pending`/`offline`/`error`/`degraded`) down to exactly the three states
/// below, plus [localOnly] (a genuinely distinct "sync is not applicable"
/// concept — see its own doc comment). The removed states carried app-level
/// "N pending / N stuck" bookkeeping (`pendingChanges` counts) and a
/// dead-letter-ish `degraded` state; AD-11 forbids reviving either.
///
/// Each state is derived ONLY from SDK-observable signals
/// (`hasPendingWrites`, `isFromCache`, connectivity) and per-account app
/// state — never from an app-maintained counter:
///   * [localOnly] — no cloud session exists for this account (per-account
///     app state: local-born tier).
///   * [syncing]   — work is in flight/unsettled: an active pull, an
///     unpushed local write, or connectivity is up but a listener channel is
///     still dead (backoff-capped, per Story 1.1's `deadChannels`/
///     `deadChannelsChanges`). AD-11's total-function honesty rule: a
///     backoff-capped channel while online is surfaced as `syncing` —
///     *never* falsely `synced` and never `offline` (the network is fine).
///   * [synced]    — a pull has completed, nothing is queued, and every
///     listener channel is live.
///   * [offline]   — connectivity itself is down (regardless of any queued
///     work — there is no separate "offline with N pending" shape anymore).
///
/// **Out of scope (deliberately, not an oversight):** a permanently-rejected
/// *write* (a genuine non-retryable rules rejection, distinct from an
/// offline/backoff case the SDK queue will drain on its own) is NOT
/// represented anywhere in this tri-state. Its user-facing recovery is
/// AD-30's per-item "tap to retry" affordance, landing in Phase 3 — out of
/// scope for this story. Until then there is a known, owner-ratified
/// regression: a permanently-failed write surfaces only as ambient
/// `syncing`, with no differentiated card and no retry affordance (the
/// differentiated appCheck/permissionDenied/timeout cards and their
/// tap-to-retry UI that `backup_sync_section.dart` used to render for this
/// case were removed in Story 1.5; see that file's doc comment).
@freezed
sealed class SyncStatus with _$SyncStatus {
  /// Local-born tier — sync permanently disabled (v2 §4.5).
  ///
  /// Distinct from [offline]: this is a per-account, structural "there is no
  /// cloud session to sync" state (a local-born account never had one), not
  /// a transient connectivity condition. It survives the Story 1.5 collapse
  /// unchanged because it answers a different question than the tri-state
  /// (is there a cloud session at all?) and drives entirely different UI
  /// (the upgrade-to-cloud CTA, never a connectivity-style card).
  const factory SyncStatus.localOnly() = SyncStatusLocalOnly;

  /// Work is in flight or unsettled: an active pull, an unpushed local
  /// write, or a listener channel that is still dead (backoff-capped) while
  /// connectivity is up. See the class doc for the AD-11 honesty rule this
  /// state exists to satisfy.
  const factory SyncStatus.syncing({required DateTime startedAt}) =
      SyncStatusSyncing;

  /// All data is successfully synchronized with Firestore: the last pull
  /// completed, nothing is queued, and no listener channel is dead.
  const factory SyncStatus.synced({required DateTime lastSyncedAt}) =
      SyncStatusSynced;

  /// Connectivity itself is down. No `pendingChanges` count — the SDK
  /// offline queue (or, pre-migration, the outbox) is the sole durability
  /// owner; the status chip only ever answers "is the network up", never
  /// "how many rows are queued" (AD-11).
  const factory SyncStatus.offline() = SyncStatusOffline;
}
