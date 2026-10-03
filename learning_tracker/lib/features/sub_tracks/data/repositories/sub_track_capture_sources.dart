/// The sub-tracks feature's repository layer (AD-23 `R`): the one place
/// its providers reach the data-access ring
/// (`tool/check_dependency_direction.dart` Rule A).
///
/// Re-exports the learner-scope and sub-track repository providers
/// (DNI-464, C0 DNI-524) without a second declaration (ruling B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show activeLearnerScopeProvider, subTrackRepositoryProvider;
