/// Riverpod providers for the Story 1.2 (DNI-464) learner-state
/// repositories: `learning_events` and `sub_tracks`.
///
/// Kept out of `repository_providers.dart` (orchestrator ruling: new
/// providers in separate files) and built only on the existing seams:
///
/// - the repositories get their Firestore handle ONLY from
///   [activeAccountFirebaseProvider] (parent AD-1/AD-24 named-app handles);
/// - the `{uid}`/`{profileId}` path pair comes ONLY from
///   [resolveActiveAccountAndProfile] (the persisted path uid, or a tutor
///   grant's owner uid), wrapped in a [LearnerScope] (ruling B10) — never
///   from the live Auth user here;
/// - no active account / no active profile resolves to `null` ("not
///   ready"), never a crash, matching the rest of the provider layer.
///
/// The named-app Auth wiring itself (bead `learning-tracker-gd7`, DNI-520)
/// changes what happens INSIDE those seams, not this file.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learning_event_repository.dart';
import 'package:learning_tracker/data/repositories/firestore_sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';

/// The active learner's [LearnerScope], or null while no account or no
/// profile is active. A stale/invalid tutor selection or a non-ULID profile
/// id surfaces as an error (same contract as the profile-scoped providers
/// in `repository_providers.dart`).
final activeLearnerScopeProvider = FutureProvider<LearnerScope?>((ref) async {
  final resolved = await resolveActiveAccountAndProfile(ref);
  if (resolved == null) return null;
  final (_, ownerUid, profileId) = resolved;
  return LearnerScope(ownerUid: ownerUid, profileId: profileId);
}, retry: (retryCount, error) => null);

/// [LearningEventRepository] over the active account's Firestore handle,
/// or null while no account is active. Scope is passed per call.
final learningEventRepositoryProvider =
    FutureProvider<LearningEventRepository?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return FirestoreLearningEventRepository(firestore: handles.firestore);
    }, retry: (retryCount, error) => null);

/// [SubTrackRepository] over the active account's Firestore handle, or
/// null while no account is active. Scope is passed per call.
final subTrackRepositoryProvider = FutureProvider<SubTrackRepository?>((
  ref,
) async {
  final handles = await ref.watch(activeAccountFirebaseProvider.future);
  if (handles == null) return null;
  return FirestoreSubTrackRepository(firestore: handles.firestore);
}, retry: (retryCount, error) => null);
