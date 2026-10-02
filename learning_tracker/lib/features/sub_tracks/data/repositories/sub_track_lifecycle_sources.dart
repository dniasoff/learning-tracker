/// The sub-track lifecycle's repository layer (AD-23 `R`): the one place
/// `sub_track_lifecycle_providers.dart` reaches the data-access ring
/// (`tool/check_dependency_direction.dart` Rule A).
///
/// Re-exports the learner-state providers (DNI-464, C0 DNI-524, DNI-470)
/// without a second declaration (ruling B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        governedIntentRepositoryProvider,
        subTrackRepositoryProvider;
