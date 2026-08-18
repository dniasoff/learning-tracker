/// Feature-safe re-export of `accountFirebaseRegistryProvider`.
///
/// Same rationale as `active_account_id_provider.dart` in this directory:
/// `AccountFirebase` (`lib/data/firestore/account_firebase.dart`) is
/// registered in `lib/data/firestore/account_firebase_providers.dart`, which
/// `lib/features/**` call sites (sign-in, sign-up, account switch) may not
/// import directly — `tool/check_dependency_direction.dart` (AD-23/AD-28,
/// `make audit` check 102) forbids it for any `lib/features/**` file
/// outside its own `data/repositories/` directory. This file exists solely
/// so those call sites can reach `accountFirebaseRegistryProvider` — to
/// call `signInCloudAccountWithEmail`/`signInCloudAccountWithGoogleIdToken`
/// when establishing a fresh cloud session — without importing
/// `package:learning_tracker/data/firestore/...` themselves. A plain
/// `export` re-exposes the SAME top-level provider, not a copy.
library;

export 'package:learning_tracker/data/firestore/account_firebase_providers.dart'
    show accountFirebaseRegistryProvider;
