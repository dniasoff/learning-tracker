import 'package:learning_tracker/features/profiles/domain/models/profile_model.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_profile_provider.g.dart';

/// Holds the active profile ID for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active and the
/// synthetic mirror has been populated ([resolvedTutoredLocalProfileIdProvider]
/// is non-null), returns the mirror's local id so the entire UI renders the
/// talmid.  Otherwise delegates to [selectedProfileIdProvider] (own profile).
///
/// `keepAlive` ensures the state survives route changes.
/// Default value 0 represents the legacy/default profile.
@Riverpod(keepAlive: true)
class ActiveProfileId extends _$ActiveProfileId {
  @override
  int build() {
    final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider);
    if (tutoredSelection != null) {
      // Return the synthetic local profile id when the mirror is ready; fall
      // back to 0 (shows empty/loading state) while the pull is in progress.
      final resolvedId = ref.watch(resolvedTutoredLocalProfileIdProvider);
      return resolvedId ?? 0;
    }
    final selected = ref.watch(selectedProfileIdProvider);
    return selected ?? 0;
  }
}

/// The *active* profile model — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's synthetic local mirror, so this returns the TALMID's profile —
/// the dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].
@riverpod
Future<ProfileModel?> activeProfile(Ref ref) async {
  final id = ref.watch(activeProfileIdProvider);
  // id == 0 is the legacy/default sentinel (no real profile row), so there is
  // no displayName to surface — let the caller fall back to its default.
  if (id == 0) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfileById(id);
}
