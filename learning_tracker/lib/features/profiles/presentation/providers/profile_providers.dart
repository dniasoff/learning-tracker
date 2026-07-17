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
// keepAlive: read from DAO call sites throughout the account's session, must survive unrelated rebuilds.
@Riverpod(keepAlive: true)
int currentAccountId(Ref ref) {
  final authState = ref.watch(authStateProvider);
  return authState.currentUser?.profileId ?? 1;
}

/// Provider for the ProfileRepository implementation.
// keepAlive: stateless repository facade over the DB, cheap to keep for the app's lifetime.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  return ProfileRepositoryImpl(db, syncEngine: syncFacade);
}

/// The currently selected profile ID. Null means no profile selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.
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

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
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
/// Mirrors the single-profile branch of `_navigateAfterSignIn` (line ~536 of
/// sign_in_controller): whenever auth transitions to signed-in AND no profile
/// is selected yet, select the account's first profile.
///
/// BUG D1 (round 2 — the real crux): the previous fix only handled the case
/// where ≥1 profile already existed. This account (a cloud account whose
/// profiles never materialised locally — restored / skipped-onboarding) has
/// ZERO rows in `learner_profiles`, so `profiles.first` had nothing to select
/// and `profileId` stayed `0`. An authenticated account must NEVER operate at
/// `profile_id = 0`. So when the account has no profile we self-heal by
/// creating a default adult profile (and adopting any orphaned `profile_id = 0`
/// rows, e.g. a pre-existing track) and select it. After this an authenticated
/// account always has ≥1 profile selected.
///
/// Watched by the app shell so it runs on every auth-valid mount. Returns the
/// id that was selected (existing or newly healed), or null when signed-out.
// keepAlive: the app shell watches this once per auth transition, must survive unrelated rebuilds.
@Riverpod(keepAlive: true)
Future<int?> autoSelectedProfileId(Ref ref) async {
  final authState = ref.watch(authStateProvider);
  if (!authState.isSignedIn) return null;

  final repo = ref.read(profileRepositoryProvider);
  final accountId = ref.read(currentAccountIdProvider);

  // FK-CONSTRAINT-ONBOARDING-01: if a profileId is already selected (e.g.
  // by the sign-in flow or the picker), verify it still exists in the
  // CURRENT account's DB before early-returning. On an account switch the
  // stale id from the previous account can survive in memory even after
  // clear() is called (race or missed call path). Returning a stale id that
  // has no row in this account's learner_profiles table causes
  // SqliteException(787): FOREIGN KEY constraint failed on any
  // profile_id-scoped INSERT (e.g. track creation → stage_definitions).
  final current = ref.read(selectedProfileIdProvider);
  if (current != null) {
    final existingProfile = await repo.getProfileById(current);
    if (existingProfile != null) return current;
    // Stale id — clear it and fall through to the auto-select/self-heal path.
    ref.read(selectedProfileIdProvider.notifier).clear();
  }
  final profiles = await repo.getProfilesByAccount(accountId);

  final int id;
  if (profiles.isNotEmpty) {
    id = profiles.first.id;
  } else {
    // Self-heal: an authenticated account with no local profile. Create a
    // default adult profile (named from the account) and adopt any orphaned
    // profile_id=0 rows so existing tracks survive.
    final fallbackName = authState.currentUser?.displayName.trim() ?? '';
    id = await repo.ensureDefaultProfile(
      accountId: accountId,
      defaultDisplayName: fallbackName.isNotEmpty ? fallbackName : 'Me',
    );
    // The freshly created profile changed the account's profile set; refresh
    // any list/stream consumers so the new profile is visible immediately.
    ref.invalidate(profileListProvider);
  }

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
// keepAlive: wraps selectedProfileIdProvider, which is itself keepAlive — must not defeat that.
@Riverpod(keepAlive: true)
ProfileSession profileSession(Ref ref) {
  final id = ref.watch(selectedProfileIdProvider);
  return id != null
      ? ProfileSession(profileId: id)
      : const ProfileSession.none();
}
