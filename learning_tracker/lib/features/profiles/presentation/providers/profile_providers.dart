import 'package:learning_tracker/core/providers/active_profile_doc_id_provider.dart';
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
///
/// Resolves to [FirestoreProfileRepositoryAdapter], not a bare
/// [ProfileRepositoryImpl] — see that adapter's class doc comment
/// (`profile_repository_impl.dart`) for why every caller of this provider
/// (add/edit-profile screens, onboarding, the self-heal path below) now
/// also mints a Firestore identity for a genuinely new profile and
/// activates it, with zero changes needed at any of those call sites.
// keepAlive: stateless repository facade over the DB, cheap to keep for the app's lifetime.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) {
  final db = ref.watch(userDatabaseProvider);
  final syncFacade = ref.watch(syncWriteFacadeProvider);
  final drift = ProfileRepositoryImpl(db, syncEngine: syncFacade);
  return FirestoreProfileRepositoryAdapter(ref: ref, driftRepository: drift);
}

/// The currently selected profile ID. Null means no profile selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.
@Riverpod(keepAlive: true)
class SelectedProfileId extends _$SelectedProfileId {
  @override
  int? build() => null;

  /// Selects profile [id] and, purely synchronously, activates its Firestore
  /// identity via [activeProfileDocIdProvider] — set to [ulid] verbatim, no
  /// I/O, no async work.
  ///
  /// **Why a caller-supplied [ulid], not an internal DB read:** an early
  /// version of this method read `learner_profiles.ulid` back itself via
  /// `ref.read(profileRepositoryProvider).getProfileById(id)`. That is
  /// genuinely async, and `select` is called from synchronous tap/callback
  /// contexts across the app (`profile_switcher_sheet.dart`,
  /// `router_provider.dart`'s `ProfileGuard`, a notification-tap handler in
  /// `notifications_bootstrap.dart`, ...) that do not, and should not have
  /// to, await or pump a `void` state setter. In a widget test that taps and
  /// asserts without a follow-up `pumpAndSettle`, that left-over async work
  /// surfaced as "A Timer is still pending even after the widget tree was
  /// disposed." — a real regression, not a test-only artifact: the same
  /// dangling work would run in production too, just silently.
  ///
  /// Every caller that already holds the [ProfileModel] it is switching to
  /// (profile creation, the switcher, sign-in, the self-heal path below)
  /// passes `ulid: model.ulid` — no new read, it was already in hand. A
  /// caller with only a bare `int` (the two exceptions above) omits [ulid],
  /// which clears [activeProfileDocIdProvider] to `null` — the same "not
  /// ready yet" signal every profile-scoped repository already treats as
  /// "show a loading/empty state", never a wrong-profile leak. This is
  /// strictly safer than the alternative of leaving a PREVIOUS profile's
  /// ulid active across a switch to a profile whose identity is unknown
  /// here.
  void select(int id, {String? ulid}) {
    state = id;
    ref.read(activeProfileDocIdProvider.notifier).set(ulid);
  }

  void clear() {
    state = null;
    ref.read(activeProfileDocIdProvider.notifier).set(null);
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
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): all of the above
/// self-heal logic used to run directly inside `build()`, so merely
/// watching/reading this provider silently wrote to
/// `selectedProfileIdProvider` (a sibling provider) and to the database
/// (`ensureDefaultProfile`). `build()` now only mirrors the current
/// selection; the effect lives in [ensureSelected], an explicit method
/// invoked by the app shell's post-frame auth-valid effect (see
/// `app_shell.dart`) — never from `build()`.
// keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.
@Riverpod(keepAlive: true)
class AutoSelectedProfileId extends _$AutoSelectedProfileId {
  @override
  Future<int?> build() async => ref.watch(selectedProfileIdProvider);

  /// Runs the BUG D1 self-heal / auto-select effect and returns the id that
  /// ends up selected (existing, healed, or null when signed-out).
  ///
  /// MUST be invoked explicitly by a caller reacting to an auth transition
  /// (see `app_shell.dart`) — never from [build] (AUD-profiles-21 / SM-2).
  Future<int?> ensureSelected() async {
    state = const AsyncLoading();
    final guarded = await AsyncValue.guard(_resolveSelection);
    // SM-4: this notifier is keepAlive so disposal mid-await is not expected
    // in practice, but guard against touching `state` after one anyway.
    if (!ref.mounted) return guarded.value;
    state = guarded;
    return guarded.value;
  }

  Future<int?> _resolveSelection() async {
    final authState = ref.read(authStateProvider);
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
      if (existingProfile != null) {
        // Already selected, still valid — just (re-)activate its Firestore
        // identity from the model we already fetched to confirm it exists.
        ref.read(activeProfileDocIdProvider.notifier).set(existingProfile.ulid);
        return current;
      }
      // Stale id — clear it and fall through to the auto-select/self-heal path.
      ref.read(selectedProfileIdProvider.notifier).clear();
    }
    final profiles = await repo.getProfilesByAccount(accountId);

    final int id;
    String? ulid;
    if (profiles.isNotEmpty) {
      id = profiles.first.id;
      ulid = profiles.first.ulid;
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
      ulid = (await repo.getProfileById(id))?.ulid;
    }

    // Re-check after the await: the picker / sign-in flow may have selected
    // a profile while we were fetching. Don't clobber an explicit choice.
    if (ref.read(selectedProfileIdProvider) == null) {
      ref.read(selectedProfileIdProvider.notifier).select(id, ulid: ulid);
      return id;
    }
    return ref.read(selectedProfileIdProvider);
  }
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
  return id != null ? ProfileSession(profileId: id) : ProfileSession.none();
}
