/// The sacred-time feature's repository layer for
/// `learnerLockSettingsProvider` (AD-23 `R`): the one place that provider
/// reaches the data-access ring (`tool/check_dependency_direction.dart`
/// Rule A).
///
/// Re-exports the learner-state providers the settings history is built
/// from (DNI-470), without a second declaration (ruling B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeLearnerScopeProvider,
        changeLogRepositoryProvider,
        learnerSettingsReaderProvider,
        ownAccountPathUidProvider;
