/// Repository-layer seam that exposes the signed-in account's path UID to
/// notification providers without importing the data-access ring directly.
library;

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show ownAccountPathUidProvider;
