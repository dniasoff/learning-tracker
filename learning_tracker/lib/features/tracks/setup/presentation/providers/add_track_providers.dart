import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/enums/curriculum_id.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/features/learner_state/data/repositories/learner_state_sources.dart';
import 'package:learning_tracker/features/onboarding/presentation/providers/onboarding_providers.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/shnayim_mikra/domain/shnayim_mikra_settings_change.dart';
import 'package:learning_tracker/features/tracks/setup/data/repositories/add_track_action_repository_impl.dart';
import 'package:learning_tracker/features/tracks/setup/domain/repositories/add_track_action_repository.dart';
import 'package:learning_tracker/features/tracks/setup/domain/services/track_creation_service.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The governed Add track action writer (DNI-476 AC-5).
final addTrackActivationChangesProvider = Provider<AddTrackActivationChanges>(
  (ref) => (curriculumId) async {
    if (curriculumId != CurriculumId.shnayimMikra) return const [];
    final scope = await ref.read(activeLearnerScopeProvider.future);
    if (scope == null) throw const AddTrackNotReadyException();
    final settingsSubscription = ref.listen(
      learnerLockSettingsProvider(scope).future,
      (_, _) {},
    );
    late final LearnerSettingsHistory history;
    try {
      history = await settingsSubscription.read();
    } finally {
      settingsSubscription.close();
    }
    if (history.current.shnayimMikraParshaSchedule != null) return const [];
    return shnayimMikraSettingsAction(
      scope.profileId,
      initialShnayimMikraSettings(
        yomTovDays: history.current.yomTovDays,
        legacyInIsrael: history.current.inIsrael,
      ),
    ).changes;
  },
);

/// The governed Add track action writer (DNI-476 AC-5).
final addTrackActionRepositoryProvider = Provider<AddTrackActionRepository>(
  (ref) => FirestoreAddTrackActionRepository(
    ref: ref,
    activationChanges: ref.watch(addTrackActivationChangesProvider),
  ),
);

/// Provider for [TrackCreationService] used by AddTrackFlow.
final trackCreationServiceProvider = Provider<TrackCreationService>((ref) {
  return TrackCreationService(
    actionRepository: ref.watch(addTrackActionRepositoryProvider),
    wizardService: ref.watch(learningProcessWizardServiceProvider),
    analytics: ref.watch(analyticsServiceProvider),
    isTutoredSession: () =>
        ref.read(activeTutoredProfileSelectionProvider) != null,
  );
});
