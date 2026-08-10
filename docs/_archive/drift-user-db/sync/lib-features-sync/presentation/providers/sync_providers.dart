import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/logging/logger.dart';
import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/core/sync/providers/outbox_providers.dart';
import 'package:learning_tracker/core/sync/providers/sync_orchestrator_providers.dart';
import 'package:learning_tracker/core/sync/sync_write_facade.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';
import 'package:learning_tracker/features/tutoring/tutoring.dart';

// AUD-core-sync-19: the sync-status stream/current providers formerly
// declared here (syncStatusStreamProvider / syncStatusProvider) were an
// unread, character-for-character duplicate of the canonical providers in
// `core/sync/providers/sync_status_providers.dart` (zero production
// consumers imported this copy). Deleted to remove the shotgun-surgery risk
// of the two copies drifting; consumers must import the core-layer
// providers directly.

/// Drains the outbox for [profileId] then records the attempt on the sync
/// orchestrator so the sync-status badge updates immediately to reflect push
/// success or failure. Without the `recordDrainAttempt` call the badge stays
/// at its old value (e.g. a stale "Synced") until the next periodic drain
/// fires (~60 s later) — a false-Synced when the push failed
/// (permission-denied or offline). Shared by both outbox-backed facade
/// providers below (`onEnqueueDrain`).
///
/// SM-4 (AUD-sync-04): [ref] can be torn down between the two awaits — both
/// providers below watch `activeProfileIdProvider`/`authStateProvider`,
/// which change on every profile switch or sign-out, realistic during the
/// network round trip a drain takes. `ref.mounted` is checked after the
/// first await so a stale [ref] is never touched for the second; a torn-down
/// ref simply skips `recordDrainAttempt` for this attempt (the provider's
/// own rebuild already re-established status tracking under the new
/// profile/auth state).
///
/// Not `_`-prefixed so it can be unit-tested directly against a
/// [ProviderContainer] without driving the full outbox-write path — see
/// `test/features/sync/presentation/providers/sync_providers_test.dart`.
Future<void> outboxDrainAndRecordAttempt(Ref ref, int profileId) async {
  await (ref.read(outboxProcessorProvider)?.drain(profileId) ??
      Future<int>.value(0));
  if (!ref.mounted) return;
  await ref.read(syncOrchestratorProvider)?.recordDrainAttempt();
}

// W2.31 — outbox-backed SyncWriteFacade provider ────────────────────────────

/// Outbox-backed [SyncWriteFacade] provider.
///
/// Tier-gated: returns `null` for local-born accounts (same rule as the
/// deleted syncEngineProvider). Cloud-born accounts get an
/// [OutboxSyncWriteFacade] that enqueues mutations into the outbox table for
/// async push.
///
/// When a tutor session is active ([activeTutoredProfileSelectionProvider] !=
/// null) the outbox facade is wrapped by a [TutoredWriteRouter] that intercepts
/// entity writes and routes them to the matching TutorWriteService Cloud
/// Function instead. The outbox [isProfileTutored] guard remains as the
/// belt-and-suspenders safety net.
///
/// W2.35: [syncEngineProvider] deleted — this is the sole write-path provider.
final syncWriteFacadeProvider = Provider<SyncWriteFacade?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final clock = ref.watch(localDayClockProvider);

  final outboxFacade = OutboxSyncWriteFacade(
    outboxDao: database.outboxDao,
    database: database,
    // AUD-core-sync-10: this provider already rebuilds a fresh facade on
    // every profile switch (it `ref.watch`es activeProfileIdProvider above),
    // so wrapping the already-fresh `profileId` value keeps behaviour
    // unchanged while matching the OutboxSyncWriteFacade resolver contract.
    resolveProfileId: () => profileId,
    clock: clock,
    // Phase 1 — write-tee: kick the outbox processor after every enqueue
    // so writes reach Firestore in the same network round as the local
    // commit. Resolved lazily so the processor's rebuild lifetime is
    // independent of the facade. See [outboxDrainAndRecordAttempt]'s doc
    // comment for the recordDrainAttempt rationale and the SM-4 ref.mounted
    // guard (AUD-sync-04).
    onEnqueueDrain: () => outboxDrainAndRecordAttempt(ref, profileId),
    // AUD-sync-03 (EH-3): so a swallowed drain-tee failure is observable
    // instead of vanishing into a log-less catchError.
    logger: AppLogger.instance,
  );

  final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider);
  if (tutoredSelection == null) return outboxFacade;

  return TutoredWriteRouter(
    delegate: outboxFacade,
    writeService: ref.watch(tutorWriteServiceProvider),
    selection: tutoredSelection,
    gamificationSnapshotBuilder: outboxFacade.buildGamificationSnapshot,
  );
});

/// Cloud-born concrete [OutboxSyncWriteFacade] for repositories/services that
/// need access to outbox-only helpers (`enqueueLedgerEntry`,
/// `enqueueNotificationSettings`, `enqueueProfileProgram`,
/// `enqueueStreakPayload`, `enqueueStudyDayConfig`).
///
/// Returns `null` for local-born accounts so callers can null-guard cleanly,
/// matching the [syncWriteFacadeProvider] tier-gate. The instance and the one
/// returned by [syncWriteFacadeProvider] are NOT shared on purpose: each
/// provider builds its own facade so widening the surface here cannot
/// accidentally retire the `SyncWriteFacade` type on the other consumers.
///
/// AUD-sync-08 (SM-2 Enforce backstop): tracks which profile ids have
/// already had their pre-sink ledger rows recovered this session, so the
/// one-shot D14 recovery scan below (see [outboxSyncWriteFacadeProvider])
/// fires at most once per profile per session — not once per rebuild.
/// [outboxSyncWriteFacadeProvider] watches several dependencies (auth tier,
/// tutored selection, database, profile id, day clock) that can each change
/// independently of a genuine profile switch, and would otherwise re-fire
/// the scan on every one of those unrelated rebuilds.
final _recoveredLedgerProfileIdsProvider = Provider<Set<int>>((ref) {
  // keepAlive: this Set is session-lifetime bookkeeping, not build state —
  // it must survive outboxSyncWriteFacadeProvider's own (much more
  // frequent) rebuilds/disposals.
  ref.keepAlive();
  return <int>{};
});

/// R1-H1: returns `null` during a tutored session so the mirror profile id is
/// never used as the outbox enqueue target.  Direct readers handle null
/// gracefully; the isProfileTutored drain guard remains as the fallback.
final outboxSyncWriteFacadeProvider = Provider<OutboxSyncWriteFacade?>((ref) {
  final authState = ref.watch(authStateProvider);
  if (!authState.isCloudBorn) return null;

  // R1-H1: suppress the outbox sink entirely during a tutored session so the
  // mirror profile id is never used as the outbox enqueue target.
  final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider);
  if (tutoredSelection != null) {
    // Clear any previously wired sink so the DAO does not retain a stale
    // facade from before the tutored session started. AUD-sync-08 (SM-2):
    // deferred to a microtask so build's synchronous body never mutates the
    // DAO directly — `ref.mounted` guards against this provider having been
    // disposed before the microtask runs (SM-4 discipline for deferred
    // callbacks).
    final database = ref.read(userDatabaseProvider);
    scheduleMicrotask(() {
      if (!ref.mounted) return;
      database.pointsBalanceDao.syncSink = null;
    });
    return null;
  }

  final database = ref.watch(userDatabaseProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final clock = ref.watch(localDayClockProvider);

  final facade = OutboxSyncWriteFacade(
    outboxDao: database.outboxDao,
    database: database,
    // AUD-core-sync-10: see the matching comment in syncWriteFacadeProvider
    // above — this provider also rebuilds on every profile switch, so this
    // wrapped snapshot stays live in practice.
    resolveProfileId: () => profileId,
    clock: clock,
    // Same write-tee + recordDrainAttempt pattern as [syncWriteFacadeProvider]
    // so points/redemption writes also update the badge immediately. See
    // [outboxDrainAndRecordAttempt]'s doc comment for the SM-4 ref.mounted
    // guard (AUD-sync-04).
    onEnqueueDrain: () => outboxDrainAndRecordAttempt(ref, profileId),
    // AUD-sync-03 (EH-3): so a swallowed drain-tee failure is observable
    // instead of vanishing into a log-less catchError.
    logger: AppLogger.instance,
  );

  // AUD-sync-08 (SM-2): the sink wiring and the D14 recovery scan used to be
  // synchronous statements directly in build's body — a DAO field mutation
  // and an unawaited fire-and-forget call, exactly the side effects build
  // must stay pure of ("no writes, no request-firing, no side effects").
  // Deferred to a microtask so build's synchronous body only constructs and
  // returns the facade; `ref.mounted` guards against this provider having
  // been disposed (e.g. a second rapid profile switch) before the microtask
  // runs. The recovery scan is additionally gated by
  // [_recoveredLedgerProfileIdsProvider] so it fires at most once per
  // profile per session rather than once per rebuild — the sink wiring
  // itself still re-fires on every rebuild, which is correct: a stale sink
  // would otherwise misroute writes to a previous profile's facade.
  final recoveredProfileIds = ref.read(_recoveredLedgerProfileIdsProvider);
  scheduleMicrotask(() {
    if (!ref.mounted) return;
    // WS9 Wave-B (C#2): register this facade as the points-sync sink so
    // every ledger insert + redemption mutation made via PointsBalanceDao is
    // pushed to the outbox. The DAO lives in core/ and cannot import the
    // facade, so the wiring happens here at the features-layer composition
    // root.
    database.pointsBalanceDao.syncSink = facade;
    if (recoveredProfileIds.add(profileId)) {
      // D14: recover any ledger rows written before this sink was wired
      // (e.g. a cloud-born account's first credit) by re-enqueuing every row
      // still lacking a sync marker. Idempotent + fire-and-forget so it
      // never blocks the UI.
      unawaited(
        database.pointsBalanceDao.reEnqueueUnsyncedLedgerRows(profileId),
      );
    }
  });
  return facade;
});
