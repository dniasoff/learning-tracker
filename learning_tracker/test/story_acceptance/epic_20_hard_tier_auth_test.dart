import 'package:flutter_test/flutter_test.dart';
import 'package:learning_tracker/data/firestore/conflict.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_state_engine.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/features/account/domain/models/auth_state.dart';

import '../helpers/learner_state/engine_fixtures.dart';
import '../helpers/learner_state_fixtures.dart';

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
    // DNI-479 (R6): the streak_events log and its reducer are retired; the
    // streak is derived by the learner-state engine from `learning_events`
    // (AD-40). The convergence promise carries over: any order of the same
    // unioned events yields the same per-curriculum streak.
    group('Story 20.11 — event-log reducers converge', () {
      test('unioned logs from two devices yield identical state', () {
        // Device A: Mon 1/5, Tue 1/6. Device B: Wed 1/7 (A was offline).
        LearningEvent learn(int n, int day) => LearningEvent.learn(
          id: engineUlid(n),
          curriculumId: engineCurriculum,
          ref: 'Mishnah Berakhot 1:$n',
          source: LearningEvent.sourceMain,
          dateState: DateState.dated,
          learnedOn: '2026-01-0$day',
          stage: 1,
          recordedAt: DateTime.utc(2026, 1, day, 12),
          actor: parentActor,
        );
        final union = [learn(1, 5), learn(3, 7), learn(2, 6)];
        CurriculumStreak? streakOf(List<LearningEvent> events) =>
            const LearnerStateEngine()
                .run(
                  engineInputs(
                    events: events,
                    nowUtc: DateTime.utc(2026, 1, 7, 18),
                  ),
                )[engineCurriculum]!
                .streak;
        final fromA = streakOf(union);
        final fromB = streakOf(union.reversed.toList());
        expect(fromA, fromB);
        expect(fromA!.current, 3);
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
    // test pinned the Drift `StreakEvents` table's unique index. The
    // completion-to-streak tee and `streak_events` are retired (DNI-479,
    // R6); a learning event is written once by `LearningCommands`, and
    // duplicate learning on one day counts as one streak day (streak_test).
  });
}
