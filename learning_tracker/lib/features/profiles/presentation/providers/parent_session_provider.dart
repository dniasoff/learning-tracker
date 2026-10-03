/// Whether the active session is a parent session (UX-DR-153).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// True for a parent session: an adult profile (the adult learner is their
/// own parent), or a child profile whose parent PIN was verified this app
/// session. False for a tutored session (a tutor PIN never counts as
/// parent authorization), a child profile without that PIN session, no
/// active profile, or any error resolving the profile (fail closed).
///
/// The same rule as `learningSessionActor`'s parent role and Story 2.4's
/// sub-track parent session (DNI-495); parent-only surfaces outside parent
/// mode (the lifetime report, Story 5.2) read it here.
final parentSessionProvider = FutureProvider.autoDispose<bool>((ref) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return false;
  final pinProfileId = ref.watch(parentPinAuthenticatedProfileIdProvider);
  try {
    final profile = await ref.watch(activeProfileProvider.future);
    if (profile == null) return false;
    if (profile.mode != ProfileMode.child) return true;
    return pinProfileId != null && pinProfileId == profile.profileId;
  } on Object {
    return false;
  }
});
