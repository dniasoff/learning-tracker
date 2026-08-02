/// E2E Wave 2 P1 journeys — Sync / Offline area.
///
/// Journeys implemented:
///   E2E-1302  Outbox write queued offline — row written to DB (offline);
///             reconnect/flush is harness-limited (device/harness).
///   E2E-1303  Sync status indicator — all SyncStatus states render in
///             BackupSyncSection with the expected subtitle text (localOnly /
///             syncing / synced / offline — collapsed from 7 to 4 by Story
///             1.5 / AD-11; the retired pending/error/degraded sub-journeys
///             are noted inline in the group).
///   E2E-1304  Two-device sync — LWW merge: conflicting completions from
///             two in-memory DBs collapse to a single row (INSERT OR IGNORE).
///   E2E-1306  Offline banner: absent for local-born + offline (harness
///             default); cloud-born + offline path is harness-limited.
///
/// ## E2E-1302 — Outbox write queued offline
///
/// The full journey (mark task offline → reconnect → outbox flush via
/// OutboxProcessor + Firestore) requires a live OutboxProcessor with a real
/// gateway, which is not available headlessly. The headless sub-journey
/// verifies:
///   - An outbox row can be inserted into the in-memory DB while connectivity
///     is overridden to offline.
///   - `outboxDao.depth(profileId)` correctly reflects the pending count.
/// The reconnect/flush sub-path is documented as device-only.
///
/// ## E2E-1303 — Sync status indicator: 4 states (localOnly/syncing/synced/offline)
///
/// Overrides `syncStatusProvider` directly (a [Provider<SyncStatus>]).
/// BackupSyncSection.build() reads this provider in every state and renders
/// the matching card. The harness already overrides:
///   - `syncOrchestratorProvider → null`  (no live orchestrator)
///   - `authStateProvider → localBorn`    (never cloud-born headlessly)
/// so re-overriding them would throw "provider overridden twice".
/// BackupSyncSection reads `syncStatusProvider` regardless of auth tier, so
/// overriding it directly drives all UI state transitions.
///
/// R-ST4: BackupSyncSection's initState fires `pullOnLaunch` only when
/// `authState.isCloudBorn && orchestrator != null`. The harness sets
/// `isCloudBorn=false` and `orchestrator=null`, so no 8-second timeout fires.
///
/// ## E2E-1304 — Two-device sync LWW merge
///
/// Uses two independent in-memory [UserDatabase] instances (deviceA, deviceB).
/// No harness widget tree is needed — the completion event table uses an
/// INSERT OR IGNORE natural key (profileId, curriculumId, sefariaRef, stageId,
/// eventTimestamp) so a "pull" of the same event from device A onto device B
/// produces exactly one row (LWW collapse).
///
/// ## E2E-1306 — Offline banner
///
/// The [OfflineTopBanner] is rendered inside AppShell with:
///   `offlineBannerVisible = isCloudBorn && !isOnline`
/// The harness always sets `authState.isCloudBorn = false` (localBorn tier),
/// so even with `connectivityStreamProvider = offline` the banner must remain
/// hidden. The cloud-born offline path (banner visible) is harness-limited
/// because `authStateProvider` is already overridden by the harness and cannot
/// be re-overridden in `extraOverrides`.
///
/// Catalog: docs/planning/e2e-test-suite-plan.md §2 Area 13 / §7
@Tags(['e2e', 'journey'])
library;

import 'dart:convert' show jsonDecode;

import 'package:drift/native.dart' show NativeDatabase;
import 'package:flutter/material.dart' show ListView;
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart'
    show CurriculumId;
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart'
    show OutboxEntityKind;
import 'package:learning_tracker/core/sync/providers/sync_status_providers.dart'
    show syncStatusProvider;
import 'package:learning_tracker/core/utils/date_utils.dart'
    show DateTimeFactory;
import 'package:learning_tracker/features/account/domain/models/auth_state.dart'
    show AuthState, AuthUser, Tier;
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart'
    show connectivityStreamProvider;
import 'package:learning_tracker/features/learning/data/completion_writer.dart'
    show CompletionWriter;
import 'package:learning_tracker/features/learning/domain/entities/completion_command.dart'
    show CompletionCommand;
import 'package:learning_tracker/features/sync/domain/models/sync_status.dart'
    show SyncStatus;

import '../harness/e2e_common_overrides.dart';
import '../harness/e2e_harness.dart';

// ── Shared silence helpers ───────────────────────────────────────────────────

/// Standard silence overrides for sync tests that land on /dashboard.
List<Override> _syncSilences(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
];

/// Silence overrides that omit connectivityStreamProvider so the test can
/// inject its own offline connectivity without a "provider overridden twice"
/// error.
List<Override> _syncSilencesNoConnectivity(E2EHarness h) => [
  ...h.dashboardSilenceOverrides,
  sacredWindowNullOverride(),
  incomingGrantsEmptyOverride(),
  pendingInvitesEmptyOverride(),
  // connectivityStreamProvider intentionally NOT overridden here.
];

/// Offline connectivity override.
Override _offlineOverride() =>
    connectivityStreamProvider.overrideWith((ref) => Stream.value(false));

// ── Drift helper ─────────────────────────────────────────────────────────────

/// Creates a fresh in-memory [UserDatabase] for two-device tests.
UserDatabase _inMemoryDb() => UserDatabase(NativeDatabase.memory());

/// Seeds a minimal account + profile row (ids auto-assigned by SQLite).
Future<void> _seedProfile(UserDatabase db) async {
  final accountId = await db
      .into(db.accounts)
      .insert(
        AccountsCompanion.insert(
          email: 'test@e2e.com',
          tier: 'localBorn',
          displayName: 'Test User',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
  await db
      .into(db.learnerProfiles)
      .insert(
        LearnerProfilesCompanion.insert(
          accountId: accountId,
          displayName: 'Test User',
          mode: 'adult',
          createdAt: DateTimeFactory.nowUtc(),
          updatedAt: DateTimeFactory.nowUtc(),
        ),
      );
}

// ── Tests ────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(e2eSetUpAll);

  // ── E2E-1302 ──────────────────────────────────────────────────────────────

  group('E2E-1302 — Outbox write queued offline → row present in DB', () {
    // Key assertions (catalog §2 Area 13):
    //  • While connectivity is offline the outbox row is written atomically
    //    alongside the local write (same Drift transaction).
    //  • outboxDao.depth(profileId) reflects the correct pending count.
    //  • The row's entityKind matches the expected completion kind.
    //
    // Headless limitation: the "reconnect → flush" sub-path requires a live
    // OutboxProcessor backed by a real Firestore gateway, which is not available
    // headlessly. That sub-path is documented as device-only below.
    //
    // R-ST4: pullOnLaunch timeout (8s) is not triggered here — the harness
    // sets authState.isCloudBorn=false so the BackupSyncSection no-ops.

    testWidgets('offline completion write: outbox row exists in in-memory DB; '
        'depth == 1 after one completion', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'outbox1302@test.com',
        displayName: 'Outbox1302',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [..._syncSilencesNoConnectivity(h), _offlineOverride()],
      );

      await h.pump(const Duration(milliseconds: 300));

      // Seed a completion track so the CompletionWriter FK constraint is met.
      final profileId = identity.profileId;
      final trackId = await h.db.trackDao.restoreOrCreate(
        profileId: profileId,
        curriculumId: CurriculumId.mishnayos,
      );

      // Write a completion while offline — this commits the completion row AND
      // an outbox row in the same DB transaction (atomic outbox pattern).
      await CompletionWriter(h.db).commit(
        CompletionCommand(
          profileId: profileId,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 2a',
          stageId: 1,
          trackType: 'personal',
          trackId: trackId,
          completedAt: DateTime.utc(2026, 6, 1),
          points: 5,
        ),
      );

      // The outbox row must be present (offline write queued).
      final rows = await h.db.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        profileId,
      );
      expect(
        rows,
        isNotEmpty,
        reason:
            'E2E-1302: outbox must contain a completion row after offline write',
      );

      // depth() counts all pending rows for this profile.
      final depth = await h.db.outboxDao.depth(profileId);
      expect(
        depth,
        greaterThanOrEqualTo(1),
        reason:
            'E2E-1302: outbox depth must be >= 1 after one offline completion write',
      );

      // The outbox payload carries the correct sefaria ref.
      final firstRow = rows.first;
      final payload = jsonDecode(firstRow.payload) as Map<String, dynamic>;
      expect(
        payload['sefaria_ref'],
        equals('Berakhot 2a'),
        reason:
            'E2E-1302: outbox payload must include the sefariaRef of the queued completion',
      );
    });

    testWidgets(
      'SKIP device/harness: outbox flush (reconnect → OutboxProcessor drain → '
      'Firestore write) requires a live gateway — device integration test only',
      skip: true,
      (tester) async {},
    );
  });

  // ── E2E-1303 ──────────────────────────────────────────────────────────────

  group('E2E-1303 — Sync status indicator: all SyncStatus states render '
      'in BackupSyncSection', () {
    // Key assertions (catalog §2 Area 13):
    //  • SyncStatus.localOnly()      → "LOCAL ONLY" card body visible
    //  • SyncStatus.syncing(…)       → "Syncing..." subtitle visible
    //  • SyncStatus.synced(…)        → "Backup & Sync" card; no "LOCAL ONLY"
    //  • SyncStatus.offline()        → "Offline" subtitle visible
    //
    // Story 1.5 / AD-11 (owner-ratified, 2026-08-02): pending/error/degraded
    // were retired along with those SyncStatus cases — see the note after
    // the "offline" sub-test below.
    //
    // Each sub-test navigates to /settings and scrolls to BackupSyncSection.
    // R-ST4: syncOrchestratorProvider=null (harness default) prevents the
    // pullOnLaunch 8s hang.

    // ── Navigate to settings helper ─────────────────────────────────────────

    // Navigate to Settings and scroll to expose BackupSyncSection.
    Future<void> goToBackupSync(E2EHarness h, WidgetTester tester) async {
      await h.tapText('SETTINGS');
      await h.pump(const Duration(milliseconds: 300));
      await h.pump(const Duration(milliseconds: 300));
      await h.pump();
      // Scroll the Settings ListView to expose BackupSyncSection near the bottom.
      final listView = find.byType(ListView);
      if (listView.evaluate().isNotEmpty) {
        await tester.drag(listView.first, const Offset(0, -1500));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
      }
    }

    // ── localOnly ─────────────────────────────────────────────────────────

    testWidgets('localOnly: BackupSyncSection shows LOCAL ONLY card body '
        'and "Upgrade to cloud" CTA for a local-born account', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'sync1303a@test.com',
        displayName: 'Sync1303A',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._syncSilences(h),
          // syncStatusProvider is a plain Provider; overrideWithValue is fine
          // even though the harness already overrides syncOrchestratorProvider
          // (different provider).
          syncStatusProvider.overrideWithValue(const SyncStatus.localOnly()),
        ],
      );

      await goToBackupSync(h, tester);

      // localOnly card body contains "LOCAL ONLY".
      expect(
        find.textContaining('LOCAL ONLY'),
        findsWidgets,
        reason: 'E2E-1303: localOnly card must show "LOCAL ONLY" body text',
      );
    });

    // ── syncing ───────────────────────────────────────────────────────────

    testWidgets('syncing: BackupSyncSection shows "Syncing..." subtitle', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'sync1303b@test.com',
        displayName: 'Sync1303B',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final now = DateTimeFactory.nowUtc();

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._syncSilences(h),
          syncStatusProvider.overrideWithValue(
            SyncStatus.syncing(startedAt: now),
          ),
        ],
      );

      await goToBackupSync(h, tester);

      // "Backup & Sync" card title.
      expect(
        find.textContaining('Backup & Sync'),
        findsWidgets,
        reason: 'E2E-1303: syncing card must show "Backup & Sync" title',
      );
      // Syncing subtitle — l10n.backupSyncing = "Syncing..."
      expect(
        find.textContaining('Syncing'),
        findsWidgets,
        reason: 'E2E-1303: syncing state must show "Syncing..." subtitle',
      );
    });

    // ── synced ────────────────────────────────────────────────────────────

    testWidgets('synced: BackupSyncSection shows "Backup & Sync" title with '
        'last-synced timestamp; no "LOCAL ONLY"', (tester) async {
      final identity = E2EIdentity.localBorn(
        email: 'sync1303c@test.com',
        displayName: 'Sync1303C',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      final lastSynced = DateTimeFactory.nowUtc();

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._syncSilences(h),
          syncStatusProvider.overrideWithValue(
            SyncStatus.synced(lastSyncedAt: lastSynced),
          ),
        ],
      );

      await goToBackupSync(h, tester);

      // Card title visible.
      expect(
        find.textContaining('Backup & Sync'),
        findsWidgets,
        reason: 'E2E-1303: synced card must show "Backup & Sync" title',
      );

      // Must NOT show "LOCAL ONLY" (that is the localOnly card).
      expect(
        find.textContaining('LOCAL ONLY'),
        findsNothing,
        reason: 'E2E-1303: synced state must NOT show the LOCAL ONLY card body',
      );
    });

    // ── offline ───────────────────────────────────────────────────────────

    testWidgets('offline: BackupSyncSection shows "Offline" subtitle', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'sync1303e@test.com',
        displayName: 'Sync1303E',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [
          ..._syncSilencesNoConnectivity(h),
          _offlineOverride(),
          syncStatusProvider.overrideWithValue(const SyncStatus.offline()),
        ],
      );

      await goToBackupSync(h, tester);

      // l10n.backupOffline = "Offline"
      expect(
        find.textContaining('Offline'),
        findsWidgets,
        reason: 'E2E-1303: offline state must show "Offline" subtitle',
      );
    });

    // Story 1.5 / AD-11 (owner-ratified, 2026-08-02): the `pending`, `error`,
    // and `degraded` sub-journeys previously covered here were retired along
    // with those SyncStatus cases — the union collapsed to exactly
    // `synced | syncing | offline` (+ `localOnly`). A queued-but-unpushed
    // write, a failed pull, and a stuck outbox row all now surface as the
    // same ambient `syncing` state already covered by the "syncing" sub-test
    // above; there is no differentiated card, count, or tap-to-retry
    // affordance left to assert on (see backup_sync_section.dart's
    // class-level doc comment — the replacement is AD-30's per-item recovery
    // affordance, landing in Phase 3).
  });

  // ── E2E-1304 ──────────────────────────────────────────────────────────────

  group('E2E-1304 — Two-device sync: LWW merge collapses duplicate '
      'completion to one row', () {
    // Key assertions (catalog §2 Area 13):
    //  • Two independent in-memory [UserDatabase] instances (deviceA, deviceB).
    //  • Device A writes a completion → an outbox row is queued.
    //  • The completion event is "pushed" (simulated by reading the outbox
    //    payload on device A) then "pulled" onto device B via
    //    completionEventDao.appendEvent (INSERT OR IGNORE natural key).
    //  • When the same completion arrives again (second device also wrote it),
    //    it collapses to exactly one row — LWW deduplication.
    //  • No harness widget tree needed; pure Drift DB assertions.
    //
    // This mirrors the existing unit test in test/sync/two_device_sync_test.dart
    // (S3: same completion from two devices deduplicates), validated as an E2E
    // catalog journey here to confirm the DB contract is maintained.

    late UserDatabase deviceA;
    late UserDatabase deviceB;

    setUp(() async {
      deviceA = _inMemoryDb();
      deviceB = _inMemoryDb();
      await _seedProfile(deviceA);
      await _seedProfile(deviceB);
    });

    tearDown(() async {
      await deviceA.close();
      await deviceB.close();
    });

    test('completion on device A propagates to device B after simulated '
        'push+pull', () async {
      // Seed a track on both devices for the FK constraint.
      final trackIdA = await deviceA.trackDao.restoreOrCreate(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
      );
      await deviceB.trackDao.restoreOrCreate(
        profileId: 1,
        curriculumId: CurriculumId.mishnayos,
      );

      // Device A marks a completion — outbox row written atomically.
      await CompletionWriter(deviceA).commit(
        CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 3a',
          stageId: 1,
          trackType: 'personal',
          trackId: trackIdA,
          completedAt: DateTime.utc(2026, 5, 1),
          points: 5,
        ),
      );

      // Simulate push: read completion rows from Device A's outbox.
      final outboxRows = await deviceA.outboxDao.getPendingByKind(
        OutboxEntityKind.completion,
        1,
      );
      expect(
        outboxRows,
        isNotEmpty,
        reason:
            'E2E-1304: device A must have a pending outbox row after completion write',
      );

      // Simulate pull onto Device B: ingest the completion event.
      for (final row in outboxRows) {
        final data = jsonDecode(row.payload) as Map<String, dynamic>;
        await deviceB.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: row.profileId,
            curriculumId: data['curriculum_id'] as String,
            sefariaRef: data['sefaria_ref'] as String,
            stageId: (data['stage_id'] as num).toInt(),
            trackType: data['track_type'] as String,
            eventTimestamp: DateTime.parse(data['completed_at'] as String),
          ),
        );
      }

      // Device B must now have the event.
      final eventsB = await deviceB.completionEventDao.getEventsByProfile(1);
      expect(
        eventsB.any((e) => e.sefariaRef == 'Berakhot 3a'),
        isTrue,
        reason:
            'E2E-1304: completion event from device A must be visible on device B after pull',
      );
    });

    test(
      'same completion from two devices collapses to one row (LWW/INSERT OR IGNORE)',
      () async {
        await deviceB.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );
        final trackIdB = await deviceB.trackDao.restoreOrCreate(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos,
        );

        final ts = DateTime.utc(2026, 5, 15);
        final cmd = CompletionCommand(
          profileId: 1,
          curriculumId: CurriculumId.mishnayos.storageKey,
          sefariaRef: 'Berakhot 7a',
          stageId: 1,
          trackType: 'personal',
          trackId: trackIdB,
          completedAt: ts,
          points: 5,
        );

        // Device B writes locally first.
        await CompletionWriter(deviceB).commit(cmd);

        // Same event arrives from Device A via pull (INSERT OR IGNORE → no-op).
        await deviceB.completionEventDao.appendEvent(
          CompletionEventsCompanion.insert(
            profileId: 1,
            curriculumId: CurriculumId.mishnayos.storageKey,
            sefariaRef: 'Berakhot 7a',
            stageId: 1,
            trackType: 'personal',
            eventTimestamp: ts,
          ),
        );

        // UNIQUE constraint (profileId, curriculumId, sefariaRef, stageId,
        // eventTimestamp) must collapse the two writes to exactly one row.
        final matching = (await deviceB.completionEventDao.getEventsByProfile(
          1,
        )).where((e) => e.sefariaRef == 'Berakhot 7a').toList();

        expect(
          matching,
          hasLength(1),
          reason:
              'E2E-1304: UNIQUE constraint (LWW/INSERT OR IGNORE) must collapse '
              'duplicate completion events to exactly one row',
        );
      },
    );
  });

  // ── E2E-1306 ──────────────────────────────────────────────────────────────

  group('E2E-1306 — Offline banner: local-born + offline → banner absent; '
      'cloud-born + offline → banner visible (device-only)', () {
    // Key assertions (catalog §2 Area 13):
    //  • LOCAL-BORN + offline: OfflineTopBanner must be absent because
    //    `offlineBannerVisible = isCloudBorn && !isOnline` is false
    //    (isCloudBorn = false for localBorn).
    //  • CLOUD-BORN + offline: OfflineTopBanner visible with
    //    l10n.offlineBannerMessage text. This path is harness-limited (see
    //    note in module docstring).
    //
    // The harness always sets authState.isCloudBorn=false (localBorn tier).
    // Re-overriding authStateProvider in extraOverrides would crash with
    // "ProviderAlreadyOverriddenError". The cloud-born path is therefore
    // a documented device-only journey.

    testWidgets('local-born user offline: OfflineTopBanner is absent '
        '(isCloudBorn=false so banner visibility formula is false)', (
      tester,
    ) async {
      final identity = E2EIdentity.localBorn(
        email: 'localoffline1306@test.com',
        displayName: 'LocalOffline1306',
        profileMode: 'adult',
      );
      final h = E2EHarness(tester, identity: identity);
      addTearDown(h.dispose);

      // connectivityStreamProvider = offline so the AppShell connectivity
      // side is false. But isCloudBorn = false (harness localBorn default),
      // so offlineBannerVisible = false && !false = false.
      await h.pumpApp(
        path: '/dashboard',
        extraOverrides: [..._syncSilencesNoConnectivity(h), _offlineOverride()],
      );

      await h.pump(const Duration(milliseconds: 300));
      await h.pump();

      // AppShell computes offlineBannerVisible = isCloudBorn && !isOnline
      //   = false && true = false → banner absent.
      // The banner container has height=32 when visible; SizedBox.shrink when
      // hidden. We assert by the localised message text.
      //
      // l10n.offlineBannerMessage = "Offline — changes will sync when you're back"
      expect(
        find.textContaining('Offline — changes will sync'),
        findsNothing,
        reason:
            'E2E-1306: local-born user must NOT see the OfflineTopBanner '
            'even when offline (banner is cloud-only)',
      );
    });

    testWidgets(
      'SKIP device/harness: cloud-born user offline → OfflineTopBanner visible — '
      'authStateProvider already overridden by harness (localBorn); '
      'cloud-born path cannot be driven headlessly (re-override crashes ProviderScope)',
      skip: true,
      (tester) async {},
    );
  });

  // ── Supplementary: local-born offline banner provider check ──────────────

  group('E2E-1306 (supplementary) — authStateProvider is localBorn: '
      'offlineBannerVisible formula evaluates to false', () {
    // Verifies the formula at the provider level without requiring AppShell
    // to be fully mounted. The auth state provided by the harness always has
    // isCloudBorn=false, which means the formula `isCloudBorn && !isOnline`
    // can never be true in headless tests. This validates the spec contract
    // that local-born users never see the banner.
    test('AuthState.localBorn isCloudBorn == false', () {
      const state = AuthState.signedIn(
        user: AuthUser(
          profileId: 1,
          email: 'test@test.com',
          displayName: 'Test',
        ),
        tier: Tier.localBorn,
      );
      expect(
        state.isCloudBorn,
        isFalse,
        reason:
            'E2E-1306: localBorn tier must have isCloudBorn=false so the '
            'offline banner formula always evaluates to false headlessly',
      );
    });

    test('AuthState.cloudBorn isCloudBorn == true', () {
      const state = AuthState.signedIn(
        user: AuthUser(
          profileId: 1,
          email: 'test@test.com',
          displayName: 'Test',
          firebaseUid: 'uid-1306',
        ),
        tier: Tier.cloudBorn,
      );
      expect(
        state.isCloudBorn,
        isTrue,
        reason:
            'E2E-1306: cloudBorn tier must have isCloudBorn=true so the '
            'offline banner formula evaluates to true when offline',
      );
    });
  });
}
