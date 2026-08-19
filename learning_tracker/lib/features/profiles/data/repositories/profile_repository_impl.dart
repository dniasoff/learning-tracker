import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/utils/date_utils.dart';
import 'package:learning_tracker/data/firestore/doc_ids.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_learner_profile_repository.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';

/// Firestore-backed [ProfileRepository] — the sole implementation now that
/// the Drift user database is deleted. Resolves
/// `firestoreLearnerProfileRepositoryProvider` for whatever account is
/// active, following the same `SomeAdapter({required Ref ref})` shape as
/// every other Firestore adapter in this codebase (AD-23/AD-28: this file
/// lives under `data/repositories/`, the one place `lib/features/**` may
/// import `DocIds`/`repository_providers.dart`).
///
/// **No local eager-mint-plus-dual-write scaffolding.** The dual-write
/// adapter this replaces minted a ULID before an accompanying Drift insert
/// so both sides agreed on an id, then separately healed a missing remote
/// document on every activation (T-40) because the two writes could fail
/// independently. With only one backing store left, [createProfile] mints
/// and writes in the same call and there is nothing left to heal —
/// Firestore's own offline queue (local persistence is enabled,
/// `account_firebase.dart`) already retries a queued write once
/// connectivity returns.
class FirestoreProfileRepositoryAdapter implements ProfileRepository {
  FirestoreProfileRepositoryAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  static const maxProfilesPerAccount = 10;

  /// Emits whether the account-scoped Firestore profile repository is ready.
  ///
  /// This is the feature-owned readiness seam for presentation providers.
  /// Consumers must not depend on the raw repository-resolution provider in
  /// `lib/data/firestore/`; this adapter is the boundary that owns that
  /// dependency.
  Stream<bool> watchReadiness() {
    final controller = StreamController<bool>();
    ProviderSubscription<AsyncValue<FirestoreLearnerProfileRepository?>>?
    repositorySubscription;

    controller.onListen = () {
      repositorySubscription = _ref
          .listen<AsyncValue<FirestoreLearnerProfileRepository?>>(
            firestoreLearnerProfileRepositoryProvider,
            (_, next) => controller.add(next.hasValue && next.value != null),
            fireImmediately: true,
          );
    };
    controller.onCancel = () async {
      repositorySubscription?.close();
      await controller.close();
    };

    return controller.stream;
  }

  Future<FirestoreLearnerProfileRepository> _resolve() async {
    final repo = await _ref.read(
      firestoreLearnerProfileRepositoryProvider.future,
    );
    if (repo == null) {
      throw const ProfileRepositoryNotReadyException();
    }
    return repo;
  }

  @override
  Future<List<LearnerProfileEntity>> getProfiles() async =>
      (await _resolve()).getProfiles();

  @override
  Stream<List<LearnerProfileEntity>> watchProfiles() {
    final controller = StreamController<List<LearnerProfileEntity>>();
    StreamSubscription<List<LearnerProfileEntity>>? profilesSubscription;
    ProviderSubscription<AsyncValue<FirestoreLearnerProfileRepository?>>?
    repositorySubscription;
    var bindGeneration = 0;
    var isClosed = false;

    Future<void> bind(
      AsyncValue<FirestoreLearnerProfileRepository?> state,
    ) async {
      final generation = ++bindGeneration;
      await profilesSubscription?.cancel();
      profilesSubscription = null;
      if (isClosed || generation != bindGeneration) return;

      if (state.hasError) {
        controller.addError(state.error!, state.stackTrace);
        return;
      }
      if (!state.hasValue || state.value == null) return;

      profilesSubscription = state.value!.watchProfiles().listen(
        controller.add,
        onError: controller.addError,
      );
    }

    controller.onListen = () {
      repositorySubscription = _ref
          .listen<AsyncValue<FirestoreLearnerProfileRepository?>>(
            firestoreLearnerProfileRepositoryProvider,
            (_, next) => unawaited(bind(next)),
            fireImmediately: true,
          );
    };
    controller.onCancel = () async {
      isClosed = true;
      await profilesSubscription?.cancel();
      repositorySubscription?.close();
      await controller.close();
    };

    return controller.stream;
  }

  @override
  Future<LearnerProfileEntity?> getProfileById(String profileId) async =>
      (await _resolve()).getProfile(profileId);

  @override
  Future<int> countProfiles() async => (await getProfiles()).length;

  @override
  Future<LearnerProfileEntity> createProfile({
    required String displayName,
    required ProfileMode mode,
    String avatar = '',
  }) async {
    final repo = await _resolve();
    final trimmedName = displayName.trim();
    final existing = await repo.getProfiles();
    if (existing.length >= maxProfilesPerAccount) {
      throw const MaxProfilesExceededException();
    }
    if (existing.any(
      (p) => p.displayName.toLowerCase() == trimmedName.toLowerCase(),
    )) {
      throw DuplicateProfileNameException(trimmedName);
    }
    return repo.ensureProfile(
      profileId: DocIds.mintProfileUlid(),
      displayName: trimmedName,
      mode: mode,
      createdAt: DateTimeFactory.nowUtc(),
      avatar: avatar,
    );
  }

  @override
  Future<LearnerProfileEntity> updateProfile({
    required String profileId,
    String? displayName,
    ProfileMode? mode,
    String? avatar,
  }) async {
    final repo = await _resolve();
    final current = await repo.getProfile(profileId);
    if (current == null) {
      throw StateError('Profile $profileId not found');
    }
    if (displayName != null) {
      final trimmedName = displayName.trim();
      final existing = await repo.getProfiles();
      if (existing.any(
        (p) =>
            p.profileId != profileId &&
            p.displayName.toLowerCase() == trimmedName.toLowerCase(),
      )) {
        throw DuplicateProfileNameException(trimmedName);
      }
    }
    return repo.updateProfile(
      profile: current,
      displayName: displayName?.trim(),
      mode: mode,
      avatar: avatar,
    );
  }

  @override
  Future<void> deleteProfile(String profileId, {bool allowLast = false}) async {
    if (!allowLast) {
      final count = await countProfiles();
      if (count <= 1) {
        throw const LastProfileException();
      }
    }
    // firestore.rules denies client-side delete on learner_profiles;
    // deleteLearnerProfile (functions/src/deletes.ts) performs a
    // server-side recursiveDelete across every subcollection. Talmid
    // profile deletion is not a tutor right, so this is never tutor-routed.
    final callable = FirebaseFunctions.instance.httpsCallable(
      'deleteLearnerProfile',
    );
    await callable.call<Map<String, dynamic>>(<String, dynamic>{
      'profileId': profileId,
    });
  }
}

/// Feature-owned readiness signal for profile presentation consumers.
final profileRepositoryReadinessProvider = StreamProvider<bool>((ref) {
  final adapter = FirestoreProfileRepositoryAdapter(ref: ref);
  return adapter.watchReadiness();
});
