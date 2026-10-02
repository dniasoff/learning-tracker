/// The change-history feature's repository layer (AD-23 `R`): the one place
/// its presentation reaches the data-access ring
/// (`tool/check_dependency_direction.dart` Rule A).
///
/// Re-exports, without a second declaration (ruling B4), the providers the
/// parent Change history is built from: its own page port (DNI-513), the
/// active learner scope and the sub-track read (DNI-464), and the learner
/// settings history (DNI-470).
library;

export 'package:learning_tracker/data/firestore/change_history_repository_providers.dart'
    show changeHistoryRepositoryProvider;
export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show activeLearnerScopeProvider, subTrackRepositoryProvider;
