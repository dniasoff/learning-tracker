/// The ground picker's repository layer (AD-23 `R`): the one place the
/// picker (Story 2.7 / DNI-498) reaches the data-access ring.
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
        governedIntentRepositoryProvider,
        subTrackRepositoryProvider;
