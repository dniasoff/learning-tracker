import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/profile_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'active_profile_provider.g.dart';

/// Holds the active profile's ULID (AD-24) for the current session.
///
/// Single chokepoint (§4.2): when a tutored selection is active, returns the
/// talmid's own profileId directly — `hasActiveTutorAccess` grants the tutor
/// direct Firestore read/write on the talmid's tree, so there is no local
/// mirror to resolve. Otherwise delegates to [selectedProfileIdProvider]
/// (own profile).
///
/// `keepAlive` ensures the state survives route changes.
// keepAlive: read from many screens across navigation, must survive route/widget-tree changes.
@Riverpod(keepAlive: true)
class ActiveProfileId extends _$ActiveProfileId {
  @override
  String? build() {
    final tutoredSelection = ref.watch(activeTutoredProfileSelectionProvider);
    if (tutoredSelection != null) return tutoredSelection.profileId;
    return ref.watch(selectedProfileIdProvider);
  }
}

/// The *active* profile — the identity the UI is currently rendering.
///
/// BUG-NEW-2: unlike [selectedProfileProvider] (which always tracks the
/// signed-in user's own chosen profile = the tutor in a tutored session), this
/// resolves through [activeProfileIdProvider]. In a tutored session that id is
/// the talmid's own profileId, so this returns the TALMID's profile — the
/// dashboard greeting must show the talmid's name and identity, not the
/// tutor's. Outside a tutored session it resolves to the same profile as
/// [selectedProfileProvider].
@riverpod
Future<LearnerProfileEntity?> activeProfile(Ref ref) async {
  final id = ref.watch(activeProfileIdProvider);
  if (id == null) return null;
  final repo = ref.watch(profileRepositoryProvider);
  return repo.getProfileById(id);
}
