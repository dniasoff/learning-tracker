/// Feature-safe forwarding seam for the active account's Firebase handles.
library;

import 'package:learning_tracker/data/firestore/active_account_providers.dart'
    as account_providers;

/// The active account's Firebase handles, exposed from the core provider seam.
final activeAccountFirebaseProvider =
    account_providers.activeAccountFirebaseProvider;
