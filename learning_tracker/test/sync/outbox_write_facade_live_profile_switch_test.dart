/// Regression test for AUD-core-sync-10.
///
/// `syncOrchestratorProvider` is a `keepAlive` singleton that wires ONE
/// [OutboxSyncWriteFacade] instance for the whole app session and — by R1's
/// own design (see that provider's class doc) — does NOT rebuild when the
/// active profile switches. Before this fix, [OutboxSyncWriteFacade] and
/// [LocalDataUploadService] captured `profileId` as a plain `int` at
/// construction time, so every write made by that long-lived facade AFTER a
/// profile switch was still stamped with the STALE boot-time profile —
/// silently orphaning the data (`OutboxProcessor._doDrain` only sweeps the
/// active profile + account-level 0, so a row stamped with a
/// no-longer-active profile is never drained).
///
/// This test drives the REAL Riverpod active-profile chain
/// (`SelectedProfileId` → `activeProfileIdProvider` → `resolveProfileIdProvider`,
/// exactly what `syncOrchestratorProvider` reads and threads into the
/// facade) so a regression that reverts the composition root back to a
/// captured `int profileId` — defeating the resolver contract — is caught,
/// even though building the full `syncOrchestratorProvider` singleton here
/// would additionally require a live Firestore gateway.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/core/database/user/user_database.dart';
import 'package:learning_tracker/core/sync/outbox/outbox_processor.dart';
import 'package:learning_tracker/core/sync/providers/resolve_profile_id_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/sync/data/outbox_sync_write_facade.dart';

import '../helpers/drift_memory.dart';

const _profileA = 11;
const _profileB = 22;

/// Matches the shape `syncOrchestratorProvider` gates on
/// (`authState.isCloudBorn`) — this facade is only ever constructed for a
/// cloud-born account.
const _cloudBornAuthState = AuthState.signedIn(
  user: AuthUser(
    profileId: _profileA,
    email: 'parent@example.com',
    displayName: 'Parent',
  ),
  tier: Tier.cloudBorn,
);

void main() {
  late UserDatabase db;
  late ProviderContainer container;

  setUp(() async {
    db = inMemoryDb();
    await seedProfile(db);
    container = ProviderContainer(
      overrides: [authStateProvider.overrideWithValue(_cloudBornAuthState)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test(
    'a long-lived OutboxSyncWriteFacade stamps a post-switch write with the '
    'NEW active profile, not the profile captured at construction time',
    () async {
      // Cloud-born (see setUp) with profile A active — the state at the
      // moment syncOrchestratorProvider would have built the facade.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_profileA, ulid: 'ulid-$_profileA');
      expect(container.read(activeProfileIdProvider), _profileA);

      // Wire ONE facade with the live resolver, exactly like
      // syncOrchestratorProvider does — never a captured `int` snapshot.
      final resolveProfileId = container.read(resolveProfileIdProvider);
      final facade = OutboxSyncWriteFacade(
        outboxDao: db.outboxDao,
        database: db,
        resolveProfileId: resolveProfileId,
        clock: FakeLocalDayClock(DateTime.utc(2026, 7, 10)),
      );

      // Write #1 while A is active.
      await facade.pushBookmark({
        'curriculum_id': 'mishnayos',
        'sefaria_ref': 'Berakhot 1:1',
        'updated_at': '2026-07-10T00:00:00.000Z',
      });

      // A household profile switch. Per R1, syncOrchestratorProvider does
      // NOT rebuild here — the SAME facade instance stays wired — only
      // activeProfileIdProvider's value changes.
      container
          .read(selectedProfileIdProvider.notifier)
          .select(_profileB, ulid: 'ulid-$_profileB');
      expect(container.read(activeProfileIdProvider), _profileB);

      // Write #2 on the SAME facade instance, performed AFTER the switch.
      await facade.pushBookmark({
        'curriculum_id': 'bavli',
        'sefaria_ref': 'Shabbat 2a',
        'updated_at': '2026-07-10T00:05:00.000Z',
      });

      final rowsUnderB = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        _profileB,
      );
      expect(
        rowsUnderB,
        hasLength(1),
        reason:
            'AUD-core-sync-10: the write performed AFTER switching the '
            'active profile must be stamped with the NEW profile (B) — a '
            'facade that still captured the construction-time snapshot (A) '
            'would leave this empty and orphan the row under A forever '
            '(the drain only sweeps the active profile + account-level 0)',
      );

      final rowsUnderA = await db.outboxDao.getPendingByKind(
        OutboxEntityKind.bookmark,
        _profileA,
      );
      expect(
        rowsUnderA,
        hasLength(1),
        reason: 'only the pre-switch write should remain stamped under A',
      );
    },
  );
}
