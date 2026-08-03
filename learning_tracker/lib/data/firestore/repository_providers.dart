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
/// [Notifier] that starts at `null`. **Not yet wired** — nothing in
/// production calls [ActiveProfileDocId.set] yet; the real call site
/// (bridging profile selection/creation to its Firestore ULID) belongs to
/// Epic C, which does not exist yet. Until then this stays `null` for the
/// whole app session, and every profile-scoped provider below resolves to
/// `null` alongside it — same status as [activeAccountIdProvider].
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
import 'package:learning_tracker/data/repositories/firestore_profile_program_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_stage_definition_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_streak_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_study_day_config_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_track_learning_order_repository.dart';
import 'package:learning_tracker/features/content_browsing/domain/repositories/content_repository.dart';

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
/// See the library doc comment: nothing does that yet.
final activeProfileDocIdProvider =
    NotifierProvider<ActiveProfileDocId, String?>(ActiveProfileDocId.new);

/// Resolves the active account's handles and active profile id together as
/// one optional pair. Every profile-scoped provider below funnels through
/// this so "no account active" and "no profile active" collapse to the
/// same `null` signal instead of each provider re-deriving it.
Future<(AccountFirebaseHandles, String)?> _watchActiveAccountAndProfile(
  Ref ref,
) async {
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
final firestoreLearnerProfileRepositoryProvider =
    FutureProvider<FirestoreLearnerProfileRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return FirestoreLearnerProfileRepository(
        firestore: handles.firestore,
        uid: handles.uid,
      );
    });

/// `.../bookmarks/{curriculumId}`.
///
/// Family-parameterized on [ContentRepository]: [FirestoreBookmarkRepository]
/// requires one for its natural-content-order fallback (see that class's
/// "Known, deliberate gap" doc section), and that is a local, non-Firestore
/// domain collaborator this file has no business resolving on its own —
/// this file only knows how to resolve Firestore handles. The caller (a
/// feature's own `data/repositories/bookmark_repository_impl.dart`, see the
/// library doc comment on reaching this file) already has, or can reach,
/// its feature's own `contentRepositoryProvider` and supplies the resolved
/// [ContentRepository] here.
final firestoreBookmarkRepositoryProvider =
    FutureProvider.family<FirestoreBookmarkRepository?, ContentRepository>((
      ref,
      contentRepository,
    ) async {
      final resolved = await _watchActiveAccountAndProfile(ref);
      if (resolved == null) return null;
      final (handles, profileId) = resolved;
      return FirestoreBookmarkRepository(
        firestore: handles.firestore,
        uid: handles.uid,
        profileId: profileId,
        contentRepository: contentRepository,
      );
    });

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
