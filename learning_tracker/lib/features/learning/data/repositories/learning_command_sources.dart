/// The learning feature's repository layer for `LearningCommands` (AD-23
/// `R`): the one place `learning_command_providers.dart` reaches the
/// data-access ring (`tool/check_dependency_direction.dart` Rule A).
///
/// Re-exports the learner-state providers the commands are built from
/// (DNI-464, C0 DNI-524, DNI-469), without a second declaration (ruling
/// B4).
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeAuthUidProvider,
        activeLearnerScopeProvider,
        learningEventRepositoryProvider,
        learningWritePortProvider,
        pointsAmountReaderProvider;
