import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/conflict.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';
import 'package:learning_tracker/features/gamification/streak/streak_log_event.dart';
import 'package:learning_tracker/features/gamification/streak/streak_reducer.dart';

/// End-to-end story acceptance tests for Epic 20 — v2 hard-tier
/// auth refactor. Covers the contract promised by the v2 architecture
/// doc §3 and §4 against the implementation that landed in stories
/// 20.3 through 20.12.
void main() {
  group('Epic 20 — v2 hard-tier auth', () {
    // ─── Story 20.3 removed (Phase 3 Drift archival, 04897ebc) ─────
    // The old "v2 schema" group here asserted directly on the Drift
    // `UserProfiles` table — that email/firebaseUid/passwordHash/tier
    // were real columns. The whole `lib/core/database/**` Drift layer is
    // now archived under `docs/_archive/drift-user-db/`, and Firestore
    // documents are schemaless, so there is no table to assert on. The
    // successor coverage is split in two: the persisted document shape is
    // owned by test/data/repositories/firestore_account_repository_test.dart
    // (via the AccountEntity codec), and the writable-field whitelist is
    // enforced by `firestore.rules`' `.hasOnly()` clause on
    // `match /users/{uid}`. This group was structurally obsolete, not
    // portable.

    // ─── Story 20.5: Unified AuthState ──────────────────────────────
    group('Story 20.5 — AuthState', () {
      test('exposes tier + session status as a single shape', () {
        const signedOut = AuthState.signedOut();
        expect(signedOut.isSignedIn, isFalse);
        expect(signedOut.isCloudBorn, isFalse);
        expect(signedOut.isLocalBorn, isFalse);

        const signedInLocal = AuthState.signedIn(
          user: AuthUser(
            uid: 'acct-local-1',
            email: 'a@test.local',
            displayName: 'A',
          ),
          tier: Tier.local,
        );
        expect(signedInLocal.isSignedIn, isTrue);
        expect(signedInLocal.isLocalBorn, isTrue);
        expect(signedInLocal.isCloudBorn, isFalse);
      });
    });

    // ─── Story 20.11: Event log + reducers ──────────────────────────
    group('Story 20.11 — event-log reducers converge', () {
      test('unioned logs from two devices yield identical state', () {
        // Device A: 1/1, 1/2
        // Device B: 1/3 (while A was offline)
        final union = [
          StreakLogEvent(
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 1),
            clientDeviceId: 'A',
          ),
          StreakLogEvent(
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 3),
            clientDeviceId: 'B',
          ),
          StreakLogEvent(
            eventType: 'completion',
            eventTimestamp: DateTime.utc(2026, 1, 2),
            clientDeviceId: 'A',
          ),
        ];
        final today = DateTime.utc(2026, 1, 3);
        final fromA = const StreakReducer().reduce(union, today: today);
        final fromB = const StreakReducer().reduce(
          union.reversed,
          today: today,
        );
        expect(fromA.currentStreak, fromB.currentStreak);
        expect(fromA.currentStreak, 3);
      });
    });

    // ─── Story 20.12: LWW + merge-forward ───────────────────────────
    // lwwMerge / mergeForwardMaxInt were deleted from merge_rules.dart as
    // dead code (AUD-core-sync-37) — no production merger called them.
    //
    // Story 2.5 / AD-7: merge_rules.dart itself is now gone. Its plain
    // `remoteIsNewer` had zero production callers (every merger, including
    // StudyDayConfigMerger, already went through the Phase-3 store gate),
    // and the LWW decision now lives in exactly one module —
    // [canonicalRemoteIsNewer] in lib/data/firestore/conflict.dart. This
    // group is repointed at it; the branch-by-branch golden pinning lives in
    // test/data/firestore/conflict_test.dart.
    group('Story 20.12 — merge rules', () {
      test('canonical predicate matches sync engine pull semantics', () {
        expect(
          canonicalRemoteIsNewer(
            localUpdatedAt: DateTime.utc(2026, 1, 1),
            remoteUpdatedAt: DateTime.utc(2026, 2, 1),
          ),
          isTrue,
        );
        // Outside the ±5 s clock-skew window an older remote never wins —
        // the flapping-free promise this story pinned.
        final ts = DateTime.utc(2026, 1, 1);
        expect(
          canonicalRemoteIsNewer(
            localUpdatedAt: ts,
            remoteUpdatedAt: ts.subtract(const Duration(minutes: 1)),
          ),
          isFalse,
        );
        // BEHAVIOUR NOTE (AD-7): the deleted merge_rules.dart predicate
        // returned FALSE on an exact `updated_at` tie ("ties go local").
        // The canonical predicate resolves that one true tie in favour of
        // remote so two devices that wrote the same value at the same
        // instant converge instead of bouncing. Pinned here so the
        // supersession is explicit rather than silent.
        expect(
          canonicalRemoteIsNewer(localUpdatedAt: ts, remoteUpdatedAt: ts),
          isTrue,
        );
      });
    });

    // ─── Story 20.11 completion-tee group removed (Phase 3) ────────
    // The old "idempotent tee: same completion twice → one event row"
    // test pinned a property that was never application logic: it was the
    // Drift `StreakEvents` table's `UNIQUE (profileId, dayUtc, eventType)`
    // index combined with `InsertMode.insertOrIgnore`. The dedup WAS the
    // index, so there is no pure function left to feed once the table is
    // archived.
    //
    // More importantly the behaviour itself is deliberately gone, not
    // merely relocated: `DocIds.streakEventDocId` keys `streak_events` by
    // ULID alone, so two independently-triggered completions for the same
    // day now write TWO documents and a caller needing "already logged
    // today?" must check `FirestoreStreakEventRepository.getEventsForDay`
    // first. That change is documented on [StreakEventEntry] in
    // lib/features/gamification/streak/streak_event_entry.dart and pinned
    // by test/data/repositories/firestore_streak_event_repository_test.dart
    // ('two documents, not one' + the getEventsForDay group). Rewriting
    // this assertion to expect two rows would leave a story banner
    // promising an idempotency guarantee the system no longer makes.
  });
}
