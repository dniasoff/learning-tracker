import 'package:learning_tracker/core/providers/database_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_session.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:learning_tracker/features/sync/presentation/providers/sync_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// The active account's local `accounts.id` within the currently-mounted
/// per-account user DB (FR22, Story 25.21).
///
/// Resolves from [authStateProvider] — when a user is signed-in, the
/// `currentUser.profileId` is the int FK that `learner_profiles.accountId`
/// and the snapshot collections key off. Falls back to `1` during the
/// brief signed-out window (e.g. between sign-up and the
/// `setLocalBornSession` call that lands onboarding) so DAO calls that
/// happen before auth-state settles keep their previous behavior.
@Riverpod(keepAlive: true)
int currentAccountId(Ref ref) {
  final authState = ref.watch(authStateProvider);
  return authState.currentUser?.profileId ?? 1;
}

/// Provider for the ProfileRepository implementation.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  return ProfileRepositoryImpl(db, syncEngine: syncFacade);
}

/// The currently selected profile ID. Null means no profile selected yet.
@Riverpod(keepAlive: true)
class SelectedProfileId extends _$SelectedProfileId {
  @override
  int? build() => null;

  void select(int id) {
    state = id;
  }

  void clear() {
    state = null;
  }
}

/// Auto-selects the account's first profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (which is the only
/// place that calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`, so `activeProfileIdProvider`
/// returns `0` and any write into a `profile_id`-FK'd table (e.g.
/// `stage_definitions` during track creation) fails with
/// `SqliteException(787): FOREIGN KEY constraint failed`.
///
/// Mirrors the single-profile branch of `_finishOnboardingRouting` (line ~536
/// of sign_in_controller): whenever auth transitions to signed-in AND no
/// profile is selected yet, select the account's first profile. Multi-profile
/// accounts route through the picker, which selects explicitly — so we only
/// auto-select when exactly one profile is the unambiguous choice; for >1 we
/// leave the selection null (the picker owns it). When there is exactly one we
/// select it; when there are several we pick the first as a safe non-null
/// default so cold-start writes never hit `profile_id=0`.
///
/// Watched by the app shell so it runs on every auth-valid mount. Returns the
/// id that was (or already had been) selected, or null when signed-out / no
/// profiles exist yet.
@Riverpod(keepAlive: true)
Future<int?> autoSelectedProfileId(Ref ref) async {
  final authState = ref.watch(authStateProvider);
  if (!authState.isSignedIn) return null;

  // Already selected (e.g. by the sign-in flow or the picker) — leave it.
  final current = ref.read(selectedProfileIdProvider);
  if (current != null) return current;

  final repo = ref.read(profileRepositoryProvider);
  final accountId = ref.read(currentAccountIdProvider);
  final profiles = await repo.getProfilesByAccount(accountId);
  if (profiles.isEmpty) return null;

  final id = profiles.first.id;
  // Re-check after the await: the picker / sign-in flow may have selected
  // a profile while we were fetching. Don't clobber an explicit choice.
  if (ref.read(selectedProfileIdProvider) == null) {
    ref.read(selectedProfileIdProvider.notifier).select(id);
    return id;
  }
  return ref.read(selectedProfileIdProvider);
}

/// Profiles for the current account.
@riverpod
Future<List<ProfileModel>> profileList(Ref ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  final accountId = ref.watch(currentAccountIdProvider);
  return repo.getProfilesByAccount(accountId);
}

/// Stream of profiles for the current account, for reactive UI.
@riverpod
Stream<List<ProfileModel>> profileListStream(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final accountId = ref.watch(currentAccountIdProvider);
  return db.profileDao
      .watchProfilesByAccount(accountId)
      .map((rows) => rows.map(ProfileModel.fromDriftRow).toList());
}

/// The currently selected profile model.
@riverpod
Future<ProfileModel?> selectedProfile(Ref ref) async {
  final id = ref.watch(selectedProfileIdProvider);
  if (id == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfileById(id);
}

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers
/// talk about "a session" rather than a nullable integer. This is the
/// canonical read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).
@Riverpod(keepAlive: true)
ProfileSession profileSession(Ref ref) {
  final id = ref.watch(selectedProfileIdProvider);
  return id != null
      ? ProfileSession(profileId: id)
      : const ProfileSession.none();
}
