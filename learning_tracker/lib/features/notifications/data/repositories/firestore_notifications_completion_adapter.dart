/// Firestore-backed completion-read adapter for the notifications feature —
/// follows the reference pattern `FirestoreProgressRepositoryAdapter`
/// (`lib/features/progress/data/repositories/firestore_progress_repository_adapter.dart`)
/// and `FirestoreCompletionRepositoryAdapter`
/// (`lib/features/learning/data/repositories/completion_repository_impl.dart`).
///
/// Presentation and domain code must not import the data-access ring directly
/// (AD-23/AD-28 — `tool/check_dependency_direction.dart` exempts exactly the
/// `/data/repositories/` path segment). [StreakAlertService] therefore takes
/// an injected `hasCompletionsInRange` predicate instead of a repository, and
/// this adapter supplies it from the composition root, constructed as
/// `FirestoreNotificationsCompletionAdapter(ref: ref)`.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/repository_providers.dart';
import 'package:learning_tracker/data/repositories/firestore_completion_repository.dart';

/// Thrown when [FirestoreNotificationsCompletionAdapter.hasCompletionsInRange]
/// cannot resolve the active profile's completion repository.
///
/// Owner ruling D-E, applied to an ACHIEVEMENT-shaped read: "has this learner
/// completed anything in this window" must never silently report `false` when
/// the answer is merely unknown (no active account, or no active learner
/// profile). A fabricated `false` here would wrongly fire a "streak at risk"
/// alert for a learner whose record simply is not resolvable yet.
class NotificationCompletionsNotReadyException implements Exception {
  const NotificationCompletionsNotReadyException([
    this.providerName = 'firestoreCompletionRepositoryProvider',
  ]);

  /// Which provider resolved to `null`.
  ///
  /// Three can, on this path — the completion repository, the active profile
  /// doc id, and the learner profile repository — and they fail for different
  /// reasons. Naming the one that failed is what makes this diagnosable from a
  /// log, which is where it will be read: this is thrown on the notification
  /// path, not in front of a debugger. Same shape as
  /// [ProgressRepositoryNotReadyException].
  final String providerName;

  @override
  String toString() =>
      'NotificationCompletionsNotReadyException: '
      '$providerName resolved to null (no active account, or no active '
      'learner profile) — refusing to answer whether this learner has '
      'completions in a range.';
}

/// Thrown when the range read returns empty AND the local Firestore cache has
/// never been populated for the active profile — an empty answer is then
/// indistinguishable from a cold cache, so a `false` would be fabricated.
class NotificationCompletionsDataNotHydratedException implements Exception {
  const NotificationCompletionsDataNotHydratedException();

  @override
  String toString() =>
      'NotificationCompletionsDataNotHydratedException: the local Firestore '
      'cache has not been populated for this profile, so an empty completion '
      'range cannot be distinguished from a real "nothing completed" — '
      'refusing to report one.';
}

/// Resolves the active profile's Firestore completions repository through
/// Riverpod and answers date-range existence reads against it.
///
/// The repository is profile-scoped by its collection path, so every read is
/// already scoped to the active learner profile — matching the profile whose
/// streak alert [StreakAlertService] is evaluating.
class FirestoreNotificationsCompletionAdapter {
  FirestoreNotificationsCompletionAdapter({required Ref ref}) : _ref = ref;

  final Ref _ref;

  /// Re-reads `firestoreCompletionRepositoryProvider`, resolving to `null`
  /// exactly when it does (no active account, or no active learner profile).
  Future<FirestoreCompletionRepository?> _resolveOrNull() {
    return _ref.read(firestoreCompletionRepositoryProvider.future);
  }

  /// Like [_resolveOrNull], but throws [NotificationCompletionsNotReadyException]
  /// instead of returning `null`.
  Future<FirestoreCompletionRepository> _resolve() async {
    final repo = await _resolveOrNull();
    if (repo == null) {
      throw const NotificationCompletionsNotReadyException();
    }
    return repo;
  }

  /// Raises [NotificationCompletionsDataNotHydratedException] when an empty
  /// completion read cannot be trusted, i.e. the local cache was never
  /// populated. Called ONLY on an empty result — a non-empty one is
  /// self-evidently hydrated, so the common path adds no Firestore read.
  Future<void> _assertHydrated() async {
    final profileId = _ref.read(activeProfileDocIdProvider);
    if (profileId == null) {
      throw const NotificationCompletionsNotReadyException(
        'activeProfileDocIdProvider',
      );
    }
    final repo = await _ref.read(
      firestoreLearnerProfileRepositoryProvider.future,
    );
    if (repo == null) {
      throw const NotificationCompletionsNotReadyException(
        'firestoreLearnerProfileRepositoryProvider',
      );
    }
    if (!await repo.hasHydratedCache(profileId)) {
      throw const NotificationCompletionsDataNotHydratedException();
    }
  }

  /// `true` if the active profile has any completion in `[start, end]`
  /// inclusive. Satisfies [StreakAlertService]'s injected
  /// `hasCompletionsInRange` predicate.
  Future<bool> hasCompletionsInRange(DateTime start, DateTime end) async {
    final repo = await _resolve();
    final inRange = await repo.hasCompletionsInDateRange(
      start: start,
      end: end,
    );
    if (!inRange) await _assertHydrated();
    return inRange;
  }
}
