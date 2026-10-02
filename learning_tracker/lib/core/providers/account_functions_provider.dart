/// Feature-safe re-export of `accountFunctionsProvider` (DNI-520).
///
/// Same rationale as `account_firebase_registry_provider.dart` in this
/// directory: `lib/features/**` files that call Cloud Functions may not
/// import `lib/data/firestore/**` directly
/// (`tool/check_dependency_direction.dart`), but must build their callable
/// client from the active account's named app — see
/// `lib/data/firestore/account_functions.dart`.
library;

export 'package:learning_tracker/data/firestore/account_functions.dart'
    show AccountFunctionsResolver, accountFunctionsProvider;
