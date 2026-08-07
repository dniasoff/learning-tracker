/// Riverpod provider layer that resolves the Firestore repositories under
/// `lib/data/repositories/` from the active device account + active
/// learner profile, so a feature can obtain a ready-to-use repository
/// instance without touching account/auth resolution itself.
///
/// ## Design decisions (read before adding a 14th provider here)
///
/// **Nullable-async, not "construct and hope."** Every provider below is a
/// [FutureProvider] that resolves to the repository type OR `null` — never
/// a repository built on a placeholder/empty uid, which would just be a
/// landmine that fails on its first real call. `null` means "genuinely not
/// ready yet" (no active account, or — for profile-scoped repositories — no
/// active profile). A real resolution failure (e.g.
/// [AccountNotAuthenticatedException]) is NOT swallowed into that `null` —
/// it still propagates as this [FutureProvider]'s `AsyncError`, exactly as
/// [activeAccountFirebaseProvider] already surfaces it. A caller reading one
/// of these providers is expected to treat `null` as "show a loading/empty
/// state", the same contract [activeAccountFirebaseProvider] itself already
/// asks its callers to honor.
///
/// **The active-profile bridge is a new, deliberately separate seam.**
/// `activeProfileIdProvider`
/// (`lib/features/profiles/presentation/providers/active_profile_provider.dart`)
/// resolves to the Drift `int` primary key of `LearnerProfiles` — a row
/// that has no Firestore existence. The Firestore doc-id for
/// `learner_profiles/{profileId}` is a ULID `String`
/// (`lib/data/firestore/doc_ids.dart`), an entirely different identity
/// space with no stored int→ULID mapping today, so converting one into the
/// other here would be inventing a fact, not reading one. [
/// activeProfileDocIdProvider] below is instead a second, independent
/// "which profile is active" seam, deliberately shaped like
/// `ActiveAccountId` (`active_account_providers.dart`): a settable
/// [Notifier] that starts at `null`. **Wired into production.**
/// [ActiveProfileDocId.set] is called from
/// `lib/features/profiles/presentation/providers/profile_providers.dart`
/// (`SelectedProfileId.select`, and profile creation) and from
/// `lib/features/profiles/data/repositories/profile_repository_impl.dart`
/// — every profile-scoped provider below resolves once one of those call
/// sites has run.
///
/// **Not `.autoDispose`.** [activeAccountFirebaseProvider] and
/// [activeAccountIdProvider] are themselves not `.autoDispose` (a named
/// `FirebaseApp` is expensive, so the registry that backs them is
/// `keepAlive` — see `account_firebase_providers.dart`), and every provider
/// in this file is a thin, side-effect-free wrapper around already-cached
/// fields of that resolved handle: constructing one of these repositories
/// costs nothing beyond a constructor call (no I/O, no native resource).
/// There is nothing here to economize by tearing it down between widget
/// subscriptions, and matching the providers upstream avoids a needless
/// rebuild — and therefore a needless new repository instance — every time
/// the last widget watching one briefly unsubscribes during navigation.
///
/// ## Reaching this file from `lib/features/**` — audit check 102
///
/// `tool/check_dependency_direction.dart` (AD-23/AD-28, `make audit` check
/// 102) fails any `lib/features/**` or `lib/domain/**` file that imports
/// `package:learning_tracker/data/firestore/...` UNLESS the importing
/// file's own path contains the segment `/data/repositories/`. That
/// exemption is a pure path-segment match, not scoped to a specific
/// feature — and every feature already has exactly that directory
/// (`lib/features/<feature>/data/repositories/`, e.g.
/// `lib/features/learning/data/repositories/completion_repository_impl.dart`),
/// holding today's Drift-backed implementation of that feature's own
/// domain repository interface. Those files are the sanctioned seam: when
/// Epic C rewires a feature onto Firestore, its own
/// `..._repository_impl.dart` is exactly the file that imports this one and
/// adapts a provider below to the feature's domain interface — its path
/// already satisfies the check-102 exemption, so no barrel file and no new
/// directory are needed. A feature file OUTSIDE that directory (a screen, a
/// presentation provider, a notifier) must keep going through its
/// feature's own repository interface, never through this file directly —
/// exactly what AD-23 already requires today for the Drift repositories.
/// This is a call worth a second look, not a certainty: confirmed by
/// reading `tool/check_dependency_direction.dart` directly, not assumed.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/content/content_index.dart';
import 'package:learning_tracker/data/firestore/account_firebase.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_account_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_bookmark_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_scope_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_curriculum_track_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_goal_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_order_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_points_ledger_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';
// Direct import, not the tutoring barrel: this file lives outside
// lib/features/** and lib/domain/**, so it is outside audit check 102's
// (`tool/check_dependency_direction.dart`) scan in either direction — the
// check restricts lib/features/**'s imports of lib/data/**, never the
// reverse, and it never inspects lib/data/** at all. See
// _watchActiveAccountAndProfile below for why this one symbol is needed
// here rather than in each of the 13 providers it feeds.
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// Holds the Firestore ULID doc-id of the "active" learner profile, or
/// `null` when no profile is active.
///
/// See the library doc comment ("The active-profile bridge...") for why
/// this exists as a second seam alongside the Drift-era
/// `activeProfileIdProvider` rather than converting between the two id
/// spaces. Deliberately dumb, mirroring `ActiveAccountId`
/// (`active_account_providers.dart`): this notifier only records which
/// profile id is active, never resolves, validates, or creates one.
class ActiveProfileDocId extends Notifier<String?> {
  @override
  String? build() => null;

  /// Sets the active learner profile's Firestore doc-id, or clears it with
  /// `null` (e.g. on profile switch away / sign-out).
  void set(String? profileId) => state = profileId;
}

/// The active learner profile's Firestore doc-id — `null` until some
/// caller calls `ref.read(activeProfileDocIdProvider.notifier).set(id)`.
/// See the library doc comment for the production call sites that now do.
final activeProfileDocIdProvider =
    NotifierProvider<ActiveProfileDocId, String?>(ActiveProfileDocId.new);

/// Resolves the active account's handles and active profile id together as
/// one optional pair. Every profile-scoped provider below funnels through
/// this so "no account active", "no profile active" and "a tutor is acting
/// inside a talmid's context" all collapse to the same `null` signal
/// instead of each provider — or each feature's own repository adapter —
/// re-deriving it.
///
/// **The tutored-session check below is deliberately first, before any
/// handle resolution.** [activeProfileDocIdProvider] still holds the
/// TUTOR's own profile ULID during a tutored session — nothing under
/// `lib/features/tutoring/` sets it. **Corrected reason (P2-12; the
/// previous wording here was false and is Phase 3's T-37 trap):** the
/// tutored mirror row is NOT missing a ULID — `ProfileDao.upsertTutoredProfile`
/// has recorded the talmid's own remote id as `ulid` since P2-2
/// (`profile_dao.dart`'s `ulid: Value(remoteChildProfileId)`, inside its
/// insert branch). The real reason nothing wires that value in here is
/// architectural, not an absent value: this provider pairs whatever id it
/// is given with [activeAccountFirebaseProvider]'s handles, which during a
/// tutored session are the **signed-in tutor's own** handles — so setting
/// the talmid's ULID here would resolve to
/// `users/{TUTOR}/learner_profiles/{talmid ULID}`, a document that does not
/// exist, not the parent's real `users/{ownerUid}/learner_profiles/{talmid
/// ULID}`. Reading the parent's tree needs an owner-uid-scoped handle
/// seam — Phase 3's `T-37`, not a value plugged in here. Resolving handles
/// first and only then checking would still hand back `(tutorHandles, tutorOwnProfileId)`
/// on every path that doesn't itself repeat the check — which is exactly
/// the bug this hoist closes: before this, only the bookmark adapter
/// carried its own copy of this guard, so the other 12 profile-scoped
/// providers silently served the tutor's own tree during a tutored
/// session. Checking here makes all 13 refuse uniformly, with one seam
/// instead of 13 (or 1, as it was).
Future<(AccountFirebaseHandles, String)?> _watchActiveAccountAndProfile(
  Ref ref,
) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return null;
  final handles = await ref.watch(activeAccountFirebaseProvider.future);
  if (handles == null) return null;
  final profileId = ref.watch(activeProfileDocIdProvider);
  if (profileId == null) return null;
  return (handles, profileId);
}

/// `users/{uid}` — the account document and its legacy free-form profile
/// snapshot. Account-scoped: needs no active learner profile.
final firestoreAccountRepositoryProvider =
    FutureProvider<FirestoreAccountRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return FirestoreAccountRepository(
        firestore: handles.firestore,
        uid: handles.uid,
      );
    });

/// `users/{uid}/learner_profiles/{profileId}` — the profile list itself.
/// Account-scoped, not profile-scoped: this repository manages the SET of
/// profiles under an account, so — unlike every other provider below — it
/// needs no *active* profile id.
///
/// **`retry: (retryCount, error) => null` (T-43).** `await
/// ref.watch(activeAccountFirebaseProvider.future)` above propagates that
/// provider's RAW error on failure — `ElementWithFuture.onError`
/// (`package:riverpod`) completes `.future`'s `Completer` with the
/// original exception, unwrapped, not a `ProviderException` — so
/// Riverpod's default retry does not recognize it as "another provider's
/// error" and retries it here too, independently of whatever
/// [activeAccountFirebaseProvider] itself decided. Disabling retry on that
/// provider alone (see its own doc comment) was not sufficient: this
/// provider's OWN default retry still turned a fast upstream failure into
/// another ~38+-second stall before `.future` — what
/// `FirestoreProfileRepositoryAdapter._ensureFirestoreProfile` awaits —
/// finally settled. Confirmed by reproduction: with only the upstream fix,
/// `profile_repository_impl_test.dart`'s "does not propagate out of
/// createProfile" test still hung to its 2-minute timeout, now reporting
/// disposal of THIS provider instead. Every other provider in this file
/// shares the identical `await ref.watch(activeAccountFirebaseProvider
/// .future)` (directly or via [_watchActiveAccountAndProfile]) shape and
/// therefore the same latent risk; only this one is reachable from T-40/
/// T-43's call chain (`createProfile` → `ensureDefaultProfile` →
/// `ensureRemoteProfile`), so only this one is fixed here — the rest are
/// carried, not silently fixed, in `docs/planning/firestore-cutover-log.md`'s
/// `T-43` entries.
final firestoreLearnerProfileRepositoryProvider =
    FutureProvider<FirestoreLearnerProfileRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return FirestoreLearnerProfileRepository(
        firestore: handles.firestore,
        uid: handles.uid,
      );
    }, retry: (retryCount, error) => null);

/// The two local, non-Firestore collaborators [FirestoreBookmarkRepository]
/// needs, supplied by the caller. This file resolves Firestore handles and
/// nothing else: `ContentRepository` lives under `lib/features/`, and the
/// policy for what to do while `contentIndexProvider` is still loading
/// (pass `null`, fall back to the O(N) scan) belongs to the feature layer
/// that already owns it — see
/// `lib/features/learning/presentation/providers/bookmark_providers.dart`.
typedef BookmarkRepositoryDeps = ({
  ContentRepository contentRepository,
  ContentIndex? contentIndex,
});

/// `.../bookmarks/{curriculumId}`.
///
/// Family-parameterized on [BookmarkRepositoryDeps]:
/// [FirestoreBookmarkRepository] requires a [ContentRepository] for its
/// natural-content-order fallback (see that class's "Custom learning order
/// is honoured" doc section) and accepts an optional [ContentIndex] for the
/// O(1) adjacent-item fast path — both are local, non-Firestore domain
/// collaborators this file has no business resolving on its own; this file
/// only knows how to resolve Firestore handles. The caller (a feature's own
/// `data/repositories/bookmark_repository_impl.dart`, see the library doc
/// comment on reaching this file) already has, or can reach, its feature's
/// own `contentRepositoryProvider`/`contentIndexProvider` and supplies the
/// resolved pair here as one record. The [FirestoreLearningOrderRepository]
/// [FirestoreBookmarkRepository] also requires is NOT part of that record
/// — unlike the two above, it IS a Firestore repository this file already
/// knows how to build, so it is constructed inline below from the exact
/// same `(handles, profileId)` pair every other provider in this file
/// resolves through, with no extra `await` and no second provider
/// dependency.
final firestoreBookmarkRepositoryProvider =
    FutureProvider.family<FirestoreBookmarkRepository?, BookmarkRepositoryDeps>(
      (ref, deps) async {
        final resolved = await _watchActiveAccountAndProfile(ref);
        if (resolved == null) return null;
        final (handles, profileId) = resolved;
        return FirestoreBookmarkRepository(
          firestore: handles.firestore,
          uid: handles.uid,
          profileId: profileId,
          contentRepository: deps.contentRepository,
          contentIndex: deps.contentIndex,
          learningOrderRepository: FirestoreLearningOrderRepository(
            firestore: handles.firestore,
            uid: handles.uid,
            profileId: profileId,
          ),
        );
      },
    );

/// `.../completions/{completionId}`.
final firestoreCompletionRepositoryProvider =
    FutureProvider<FirestoreCompletionRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreCompletionRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../curriculum_scopes/{scopeId}`.
final firestoreCurriculumScopeRepositoryProvider =
    FutureProvider<FirestoreCurriculumScopeRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreCurriculumScopeRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../curriculum_tracks/{curriculumId}`.
final firestoreCurriculumTrackRepositoryProvider =
    FutureProvider<FirestoreCurriculumTrackRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreCurriculumTrackRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../goals/{goalId}`.
final firestoreGoalRepositoryProvider =
    FutureProvider<FirestoreGoalRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreGoalRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../learning_ledger/{entryId}`.
final firestoreLearningLedgerRepositoryProvider =
    FutureProvider<FirestoreLearningLedgerRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreLearningLedgerRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../learning_order/{orderId}`.
final firestoreLearningOrderRepositoryProvider =
    FutureProvider<FirestoreLearningOrderRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreLearningOrderRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../points_ledger/{entryId}`.
final firestorePointsLedgerRepositoryProvider =
    FutureProvider<FirestorePointsLedgerRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestorePointsLedgerRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../profile_programs/{programId}`.
final firestoreProfileProgramRepositoryProvider =
    FutureProvider<FirestoreProfileProgramRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreProfileProgramRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../stage_definitions/{stageId}`.
final firestoreStageDefinitionRepositoryProvider =
    FutureProvider<FirestoreStageDefinitionRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreStageDefinitionRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../track_learning_order/{orderId}`.
///
/// Distinct from [firestoreLearningOrderRepositoryProvider]: that one serves
/// WHOLE-CURRICULUM ordering, this one serves per-track (sedarim/masechtos)
/// reordering. They are separate collections precisely because
/// `DocIds.trackLearningOrderDocId` and `DocIds.learningOrderDocId` compute
/// the IDENTICAL string for the same `(curriculumId, sefariaRef)` — only the
/// collection path keeps them apart. Sharing one collection would let a
/// track-level order silently clobber a curriculum-level one.
final firestoreTrackLearningOrderRepositoryProvider =
    FutureProvider<FirestoreTrackLearningOrderRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreTrackLearningOrderRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../streak_events/{eventId}`.
final firestoreStreakEventRepositoryProvider =
    FutureProvider<FirestoreStreakEventRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreStreakEventRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });

/// `.../study_day_configs/{configId}`.
final firestoreStudyDayConfigRepositoryProvider =
    FutureProvider<FirestoreStudyDayConfigRepository?>((ref) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreStudyDayConfigRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
      );
    });
