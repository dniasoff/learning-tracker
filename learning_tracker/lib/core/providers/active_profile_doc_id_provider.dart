/// Feature-safe re-export of `activeProfileDocIdProvider`.
///
/// `ActiveProfileDocId` (defined in
/// `lib/data/firestore/repository_providers.dart`) is a pure,
/// side-effect-free "which Firestore learner-profile ULID is active" seam —
/// a `Notifier<String?>` that only ever assigns to its own `state`. It holds
/// no Firestore handle and performs no I/O, so architecturally it is the
/// exact counterpart of [ActiveAccountId]
/// (`lib/data/firestore/active_account_providers.dart`, re-exported by
/// `active_account_id_provider.dart` in this same directory) — this file
/// mirrors that one exactly, for the same reason.
///
/// It is defined in `lib/data/firestore/`, not here, because it is
/// co-located with every profile-scoped `FutureProvider` in
/// `repository_providers.dart` that resolves through it (see that file's
/// library doc comment, "The active-profile bridge..."). Splitting or
/// moving that file is out of scope for wiring this one provider.
///
/// This file exists solely so `lib/features/**` call sites —
/// `SelectedProfileId.select`/`.clear` and `AutoSelectedProfileId`'s own
/// guarded re-affirm branch (`lib/features/profiles/presentation/providers/
/// profile_providers.dart`, this provider's only writers as of T-49/P2-30
/// — the profile repository adapter's own creation path was a writer from
/// P2-23 through P2-28 but never closed the race that motivated it, and
/// the write was deleted rather than relocated a fourth time; that adapter
/// lives under `data/repositories/` and always imported
/// `repository_providers.dart` directly under check 102's own exemption
/// for that directory, never through this re-export, so this file's writer
/// set was never actually reachable through it in the first place) — can
/// reach `activeProfileDocIdProvider` without
/// importing `package:learning_tracker/data/firestore/...` directly, which
/// `tool/check_dependency_direction.dart` (AD-23/AD-28, `make audit` check
/// 102) forbids for any `lib/features/**` file outside its own
/// `data/repositories/` directory — see that checker's doc comment. A plain
/// `export` re-exposes the SAME top-level provider declared in
/// `repository_providers.dart`, not a copy: every profile-scoped provider in
/// that file (which watches [activeProfileDocIdProvider] via
/// `_watchActiveAccountAndProfile`) and every feature call site that sets it
/// through this file are reading/writing the identical provider instance.
library;

export 'package:learning_tracker/data/firestore/repository_providers.dart'
    show activeProfileDocIdProvider;
