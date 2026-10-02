/// The sub-tracks feature's repository layer (AD-23 `R`): the one place
/// `lib/features/sub_tracks/**` reaches the data-access ring.
///
/// AD-23/AD-28 forbid a feature's presentation code from importing
/// `lib/data/firestore/**` directly (`tool/check_dependency_direction.dart`
/// Rule A). This library re-exports the learner-scope and sub-track
/// repository providers (DNI-464) so the Learn-tab rows and Dashboard cards
/// (DNI-500) read them without a second declaration (ruling B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show activeLearnerScopeProvider, subTrackRepositoryProvider;
