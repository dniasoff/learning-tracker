/// The learner-state feature's repository layer (AD-23 `R`): the one place
/// `lib/features/learner_state/**` reaches the data-access ring.
///
/// AD-23/AD-28 forbid a feature's presentation code from importing
/// `lib/data/firestore/**` directly (`tool/check_dependency_direction.dart`
/// Rule A); the `data/repositories/` layer is the permitted `R --> A` edge.
/// This library re-exports the learner-scope and learner-state port
/// providers (DNI-464, C0 DNI-524) for the feature's providers, so
/// `learnerStateProvider` (DNI-474) composes them without a second
/// declaration (ruling B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        changeLogRepositoryProvider,
        governedIntentRepositoryProvider,
        learningEventRepositoryProvider,
        learningWritePortProvider,
        oversizedGovernedWritePortProvider,
        subTrackRepositoryProvider;
