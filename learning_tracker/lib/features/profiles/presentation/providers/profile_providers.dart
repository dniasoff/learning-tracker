import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/providers/active_account_id_provider.dart';
import 'package:learning_tracker/core/providers/active_profile_doc_id_provider.dart';
import 'package:learning_tracker/features/account/presentation/providers/auth_state_provider.dart';
import 'package:learning_tracker/features/profiles/data/repositories/profile_repository_impl.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/domain/models/profile_session.dart';
import 'package:learning_tracker/features/profiles/domain/repositories/profile_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'profile_providers.g.dart';

/// Provider for the ProfileRepository implementation.
// keepAlive: stateless repository facade, cheap to keep for the app's lifetime.
@Riverpod(keepAlive: true)
ProfileRepository profileRepository(Ref ref) =>
    FirestoreProfileRepositoryAdapter(ref: ref);

/// The currently selected profile's ULID (AD-24). Null means no profile
/// selected yet.
// keepAlive: the session's profile selection must survive route changes and unrelated rebuilds.
@Riverpod(keepAlive: true)
class SelectedProfileId extends _$SelectedProfileId {
  @override
  String? build() => null;

  /// Selects [profileId] and, purely synchronously, activates its Firestore
  /// identity via [activeProfileDocIdProvider] — no I/O, no async work. See
  /// that provider's doc comment: every profile-scoped Firestore adapter in
  /// the app keys off it.
  void select(String profileId) {
    state = profileId;
    ref.read(activeProfileDocIdProvider.notifier).set(profileId);
  }

  void clear() {
    state = null;
    ref.read(activeProfileDocIdProvider.notifier).set(null);
  }
}

/// Auto-selects (or self-heals) the account's profile on an auth-valid startup.
///
/// BUG D1: on a force-stop + cold start with a still-valid Firebase/local
/// session, the app skips the interactive sign-in flow (the only place that
/// otherwise calls `selectedProfileIdProvider.notifier.select(...)`, see
/// `sign_in_controller.dart`). Without this effect the in-memory
/// `selectedProfileIdProvider` stays `null`.
///
/// AUD-profiles-21 (SM-2 — provider `build` must be pure): the self-heal
/// logic lives in [ensureSelected], not `build()` — see `app_shell.dart`'s
/// post-frame auth-valid effect for the caller.
// keepAlive: the app shell triggers ensureSelected() once per auth transition, must survive unrelated rebuilds.
@Riverpod(keepAlive: true)
class AutoSelectedProfileId extends _$AutoSelectedProfileId {
  @override
  Future<String?> build() async => ref.watch(selectedProfileIdProvider);

  /// Runs the BUG D1 self-heal / auto-select effect and returns the id that
  /// ends up selected (existing, healed, or null when signed-out).
  Future<String?> ensureSelected() async {
    state = const AsyncLoading();
    final guarded = await AsyncValue.guard(_resolveSelection);
    // SM-4: this notifier is keepAlive so disposal mid-await is not expected
    // in practice, but guard against touching `state` after one anyway.
    if (!ref.mounted) return guarded.value;
    state = guarded;
    return guarded.value;
  }

  Future<String?> _resolveSelection() async {
    final authState = ref.read(authStateProvider);
    if (!authState.isSignedIn) return null;
    // Cheap in-memory gate so a test container that overrides only
    // `selectedProfileIdProvider` (bypassing the real account stack, as most
    // narrow widget tests do) never attempts a live repository resolve.
    if (ref.read(activeAccountIdProvider) == null) return null;

    final repo = ref.read(profileRepositoryProvider);

    // FK-CONSTRAINT-ONBOARDING-01 lineage: if a profileId is already
    // selected (e.g. by the sign-in flow or the picker), verify it still
    // exists under the CURRENT account before early-returning — a stale id
    // from a previous account can survive in memory across a switch.
    final current = ref.read(selectedProfileIdProvider);
    if (current != null) {
      final existingProfile = await repo.getProfileById(current);
      if (existingProfile != null) {
        // Re-check after the await: the picker / sign-in flow may have
        // selected a DIFFERENT profile while we were fetching this one.
        final stillCurrent = ref.read(selectedProfileIdProvider);
        if (stillCurrent == current) {
          ref
              .read(activeProfileDocIdProvider.notifier)
              .set(existingProfile.profileId);
        }
        return stillCurrent;
      }
      // Stale id — clear it and fall through to the auto-select/self-heal path.
      ref.read(selectedProfileIdProvider.notifier).clear();
    }

    final profiles = await repo.getProfiles();
    final String id;
    if (profiles.isNotEmpty) {
      id = profiles.first.profileId;
    } else {
      // Self-heal: an authenticated account with no profile yet. Create a
      // default adult profile named from the account.
      final fallbackName = authState.currentUser?.displayName.trim() ?? '';
      final created = await repo.createProfile(
        displayName: fallbackName.isNotEmpty ? fallbackName : 'Me',
        mode: ProfileMode.adult,
      );
      ref.invalidate(profileListProvider);
      id = created.profileId;
    }

    // Re-check after the await: the picker / sign-in flow may have selected
    // a profile while we were fetching. Don't clobber an explicit choice.
    if (ref.read(selectedProfileIdProvider) == null) {
      ref.read(selectedProfileIdProvider.notifier).select(id);
      return id;
    }
    return ref.read(selectedProfileIdProvider);
  }
}

/// Profiles for the active account.
@riverpod
Future<List<LearnerProfileEntity>> profileList(Ref ref) async {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfiles();
}

/// Stream of profiles for the active account, for reactive UI.
@riverpod
Stream<List<LearnerProfileEntity>> profileListStream(Ref ref) {
  final repo = ref.watch(profileRepositoryProvider);
  return repo.watchProfiles();
}

/// The currently selected profile.
@riverpod
Future<LearnerProfileEntity?> selectedProfile(Ref ref) async {
  final id = ref.watch(selectedProfileIdProvider);
  if (id == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfileById(id);
}

/// The active profile session as a typed domain aggregate.
///
/// Wraps [selectedProfileIdProvider] into a [ProfileSession] so callers talk
/// about "a session" rather than a nullable String. This is the canonical
/// read path for profile-selection state; write path stays on
/// `selectedProfileIdProvider.notifier` (select / clear).
// keepAlive: wraps selectedProfileIdProvider, which is itself keepAlive — must not defeat that.
@Riverpod(keepAlive: true)
ProfileSession profileSession(Ref ref) {
  final id = ref.watch(selectedProfileIdProvider);
  return id != null ? ProfileSession(profileId: id) : ProfileSession.none();
}
