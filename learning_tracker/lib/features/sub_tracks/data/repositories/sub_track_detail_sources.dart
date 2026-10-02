/// The sub-track detail's repository layer (AD-23 `R`): the one place the
/// detail (Story 2.6 / DNI-497) reaches the data-access ring.
///
/// AD-23/AD-28 forbid a feature's presentation code from importing
/// `lib/data/firestore/**` directly (`tool/check_dependency_direction.dart`
/// Rule A); the `data/repositories/` layer is the permitted `R --> A` edge.
/// It only re-exports the DNI-464 / C0 (DNI-524) learner-scope and port
/// providers (ruling B4: no second declaration, no direct Firestore access).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        learningEventRepositoryProvider,
        subTrackRepositoryProvider;
