import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_ledger_repository_impl.dart';
import 'package:learning_tracker/features/learning/domain/entities/learning_ledger_entry.dart';
import 'package:learning_tracker/features/learning/domain/repositories/learning_ledger_repository.dart';
import 'package:learning_tracker/features/learning/domain/use_cases/manual_completion_use_case.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'learning_ledger_providers.g.dart';

/// Fetches the [ProfileMode] for the active profile.
///
/// Routes through [profileRepositoryProvider] (the profiles feature's own
/// repository interface) rather than reading `profileDao` directly — this
/// provider lives outside `data/repositories/`, so it must not touch Drift
/// (or Firestore) storage on its own (audit check 102's caller-goes-through-
/// its-feature's-repository rule).
///
/// Falls back to [ProfileMode.adult] for a missing profile or an
/// unrecognised raw mode value — [ProfileModel.profileMode] already applies
/// that same fallback.
final _activeProfileModeProvider = FutureProvider.autoDispose<ProfileMode>((
  ref,
) async {
  final repository = ref.watch(profileRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profile = await repository.getProfileById(profileId);
  if (profile == null) return ProfileMode.adult;
  return profile.profileMode;
});

/// Provides the learning ledger repository.
@riverpod
LearningLedgerRepository learningLedgerRepository(Ref ref) {
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode =
      ref.watch(_activeProfileModeProvider).value ?? ProfileMode.adult;
  final pinSessionProfileId = ref.watch(
    parentPinAuthenticatedProfileIdProvider,
  );
  // The PIN match is computed entirely in the Drift id space, and stays there:
  // it only asks "was the PIN verified for the SAME profile that is active?",
  // which is a comparison between two ids of the same kind. It deliberately
  // does not involve the ULID.
  final parentPinSessionMatches =
      pinSessionProfileId != null && pinSessionProfileId == profileId;

  // The adapter reads the profile's ULID doc-id itself: that seam lives in the
  // data-access ring, which `check_dependency_direction` (AD-23/AD-28) forbids
  // presentation from importing. See the adapter's `_activeProfileUlid`.
  return FirestoreLearningLedgerRepositoryAdapter(
    ref: ref,
    activeProfileMode: profileMode,
    parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
  );
}

/// Provides the manual completion use case.
@riverpod
ManualCompletionUseCase manualCompletionUseCase(Ref ref) {
  final repository = ref.watch(learningLedgerRepositoryProvider);
  final profileId = ref.watch(activeProfileIdProvider);
  final profileMode =
      ref.watch(_activeProfileModeProvider).value ?? ProfileMode.adult;
  final pinSessionProfileId = ref.watch(
    parentPinAuthenticatedProfileIdProvider,
  );
  final parentPinSessionMatches =
      pinSessionProfileId != null && pinSessionProfileId == profileId;
  return ManualCompletionUseCase(
    repository: repository,
    activeProfileId: profileId,
    activeProfileMode: profileMode,
    parentPinSessionMatchesActiveProfile: parentPinSessionMatches,
  );
}

/// Resolves a storage-key string to its [CurriculumId].
///
/// The three family providers below keep a `String` family key so their ~8
/// existing watchers are untouched; the conversion to the enum happens here, at
/// the boundary, exactly as `FirestoreCompletionRepositoryAdapter` does it.
/// Throws rather than defaulting: an unknown curriculum key is a programming
/// error, and silently substituting one would mis-attribute a learner's ledger.
CurriculumId _curriculumFor(String storageKey) {
  final curriculum = CurriculumId.fromStorageKey(storageKey);
  if (curriculum == null) {
    throw ArgumentError('Unknown curriculumId: $storageKey');
  }
  return curriculum;
}

/// Watches all ledger entries for the active profile.
///
/// No `profileId` argument: the Firestore ledger is profile-scoped by its
/// collection path, so the repository already knows whose ledger this is.
final learningLedgerProvider =
    FutureProvider.autoDispose<List<LearningLedgerEntry>>((ref) async {
      final repository = ref.watch(learningLedgerRepositoryProvider);
      return repository.getLifetimeLedger();
    });

/// Watches ledger entries filtered by curriculum for the active profile.
final curriculumLedgerProvider = FutureProvider.autoDispose
    .family<List<LearningLedgerEntry>, String>((ref, curriculumId) async {
      final repository = ref.watch(learningLedgerRepositoryProvider);
      return repository.getLedgerByCurriculum(_curriculumFor(curriculumId));
    });

/// Computed completion stats for a curriculum.
final completionStatsProvider = FutureProvider.autoDispose
    .family<Map<String, int>, String>((ref, curriculumId) async {
      final repository = ref.watch(learningLedgerRepositoryProvider);
      return repository.getCompletionStats(_curriculumFor(curriculumId));
    });
