/// Feature-safe re-export of `activeAccountIdProvider`.
///
/// `ActiveAccountId` (defined in
/// `lib/data/firestore/active_account_providers.dart`) is a pure,
/// side-effect-free "which device account id is active" seam — a
/// `Notifier<String?>` that only ever assigns to its own `state`. It holds
/// no Firestore handle and performs no I/O, so architecturally it is the
/// exact counterpart of [AccountDbFileName] (`database_provider.dart`,
/// this same directory): both exist so `lib/features/**` call sites
/// (sign-in, sign-up, account switch, sign-out/delete — see
/// `active_account_providers.dart`'s own doc comment for the full list)
/// can record "this account is now active" the moment they establish it.
///
/// It is defined in `lib/data/firestore/`, not here, because it is
/// co-located with `activeAccountFirebaseProvider` in the same file — that
/// second provider DOES resolve a real Firebase handle via
/// [AccountFirebaseHandles] and legitimately belongs to the data-access
/// ring. Splitting or moving that file is out of scope for wiring these two
/// providers.
///
/// This file exists solely so `lib/features/**` call sites can reach
/// `activeAccountIdProvider` without importing
/// `package:learning_tracker/data/firestore/...` directly, which
/// `tool/check_dependency_direction.dart` (AD-23/AD-28, `make audit` check
/// 102) forbids for any `lib/features/**` file outside its own
/// `data/repositories/` directory — see that checker's doc comment. A plain
/// `export` re-exposes the SAME top-level provider declared in
/// `active_account_providers.dart`, not a copy: `repository_providers.dart`
/// (which watches `activeAccountIdProvider` inside
/// `activeAccountFirebaseProvider`) and every feature call site that sets
/// it through this file are reading/writing the identical provider
/// instance.
library;

export 'package:learning_tracker/data/firestore/active_account_providers.dart'
    show activeAccountIdProvider;
