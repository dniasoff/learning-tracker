/// Presentation-safe re-exports of data-layer sub-track dependencies.
///
/// AD-23/AD-28 forbid feature presentation code from importing
/// `lib/data/firestore/**` directly. The data-access layer owns these providers.
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        governedIntentRepositoryProvider,
        subTrackRepositoryProvider;
