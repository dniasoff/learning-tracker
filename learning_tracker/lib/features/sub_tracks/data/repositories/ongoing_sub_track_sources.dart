/// The ongoing sub-track form's repository layer (AD-23 `R`): the one place
/// `lib/features/sub_tracks/**` reaches the data-access ring for Story 2.5
/// (DNI-496).
///
/// AD-23/AD-28 forbid presentation code from importing
/// `lib/data/firestore/**` directly (`tool/check_dependency_direction.dart`
/// Rule A). This library re-exports the learner scope and the Story 2.1
/// (DNI-492) sub-track and governed-intent port providers, so the form adds
/// no Firestore access of its own.
///
/// DNI-495 seam: Story 2.4 was to own the sub-track sources of the hub.
/// When it lands, fold these exports into its file (follow-up bead).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        governedIntentRepositoryProvider,
        subTrackRepositoryProvider;
