/// The revoked tutored session boundary (Story 4.4, DNI-512, T3/T5;
/// FR-28, AD-53, UX-DR-136).
///
/// One outcome for every way a tutor learns that his access to the open
/// talmid has ended:
/// - the live grant verdict / learner listener of the open scope reports the
///   grant gone or a `permission-denied` read ([tutorSessionAccessWatchProvider]
///   over DNI-523's `learnerStateForScopeProvider`);
/// - a write callable is rejected because the grant no longer authorizes the
///   learner (`TutorWriteService.onAccessLost`);
/// - the authoritative active-grant list no longer holds the open grant
///   (`incomingTutorGrantsProvider`, also re-read on reconnect — T5).
///
/// [TutorAccessEndedNotifier.end] resolves the learner's name BEFORE anything
/// is cleared, exits the tutored selection (every learner-scoped provider
/// keyed on it drops its value), drops the session-wide governed action
/// ledger, re-reads the active-grant list so the roster loses the row on its
/// next update, and publishes a [TutorAccessEnded] for the shell's
/// [TutorAccessEndedListener] to show "Access to {name} has ended." and
/// return to the tutor's roster (discarding any open form or picker).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/tutor_scope_grant_source.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_for_scope_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_grant_aggregate.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/manage_tutors_providers.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_learning_providers.dart';

/// A tutored session that ended because the grant stopped authorizing it.
final class TutorAccessEnded {
  /// Creates the event.
  const TutorAccessEnded({required this.grantId, this.learnerName});

  /// The grant whose access ended.
  final String grantId;

  /// The learner's display name, resolved before the session was cleared;
  /// null when it was not known (the copy then names no one).
  final String? learnerName;

  @override
  bool operator ==(Object other) =>
      other is TutorAccessEnded &&
      other.grantId == grantId &&
      other.learnerName == learnerName;

  @override
  int get hashCode => Object.hash(grantId, learnerName);

  @override
  String toString() => 'TutorAccessEnded($grantId)';
}

/// The pending access-ended notice, or null. Kept alive for the app's
/// lifetime. [tutorSessionAccessWatchProvider] is armed separately (by the
/// shell's listener) because it reports into this notifier.
final tutorAccessEndedProvider =
    NotifierProvider<TutorAccessEndedNotifier, TutorAccessEnded?>(
      TutorAccessEndedNotifier.new,
    );

/// Ends a tutored session whose access is gone (see the library doc).
class TutorAccessEndedNotifier extends Notifier<TutorAccessEnded?> {
  @override
  TutorAccessEnded? build() => null;

  /// Ends the open tutored session if it is still [grantId]'s. A no-op when
  /// no session is open or another learner is open (the signal is stale).
  ///
  /// [refreshRoster] re-reads the active-grant list; the list itself passes
  /// false (it is the source of the signal and already fresh).
  void end(String grantId, {bool refreshRoster = true}) {
    final selection = ref.read(activeTutoredProfileSelectionProvider);
    if (selection == null || selection.grantId != grantId) return;
    final name = _learnerName(selection);
    ref.read(activeTutoredProfileSelectionProvider.notifier).exit();
    // Frozen action ids of the ended learner's unconfirmed writes: never
    // retried (the server would refuse them) and never shown again.
    ref.invalidate(tutorGovernedActionLedgerProvider);
    if (refreshRoster) _reReadActiveGrants(ref);
    state = TutorAccessEnded(grantId: grantId, learnerName: name);
  }

  /// The shell has shown [notice]; clear it (a later end publishes anew).
  void acknowledge(TutorAccessEnded notice) {
    if (state == notice) state = null;
  }

  /// The open learner's name: the tutored profile mirror when it is the
  /// selection's learner, else the grant's denormalised child name.
  String? _learnerName(TutoredProfileSelection selection) {
    final profile = ref.read(activeProfileProvider).asData?.value;
    if (profile != null && profile.profileId == selection.profileId) {
      final name = profile.displayName.trim();
      if (name.isNotEmpty) return name;
    }
    if (ref.exists(incomingTutorGrantsProvider)) {
      final grants = ref.read(incomingTutorGrantsProvider).asData?.value;
      for (final grant in grants ?? const <TutorGrant>[]) {
        if (grant.grantId != selection.grantId) continue;
        final name = grant.childName?.trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }
}

/// Whether [value] of `learnerStateForScopeProvider` says the tutor lost
/// access: the grant is missing or not active, or a read was refused. A
/// signed-out account is not a revocation (the account switch clears the
/// selection on its own).
bool tutorScopeAccessLost(AsyncValue<Object?> value) => switch (value) {
  AsyncError(error: TutorScopeAccessDeniedException(:final reason)) =>
    reason != TutorScopeDenialReason.notSignedIn,
  _ => false,
};

/// While a tutored session is open, listens to its learner scope through
/// DNI-523's grant-gated read and to connectivity:
/// - access lost → [TutorAccessEndedNotifier.end];
/// - back online → the active-grant list is re-read before the learner is
///   trusted again, so an offline revocation ends the session on reconnect
///   (AC-5).
final tutorSessionAccessWatchProvider = Provider<void>((ref) {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  if (selection == null) return;
  final LearnerScope scope;
  try {
    scope = LearnerScope(
      ownerUid: selection.ownerUid,
      profileId: selection.profileId,
    );
  } on ArgumentError {
    return;
  }
  ref.listen(learnerStateForScopeProvider(scope), (_, next) {
    if (tutorScopeAccessLost(next)) {
      ref.read(tutorAccessEndedProvider.notifier).end(selection.grantId);
    }
  });
  ref.listen(connectivityStreamProvider, (previous, next) {
    final wasOffline = previous?.value == false;
    if (wasOffline && next.value == true) _reReadActiveGrants(ref);
  });
});

/// Starts a fresh read of the active-grant list now, when it is in use (a
/// list not yet read is fresh on its first read anyway), so the roster's
/// next update does not wait for a later frame to pull it.
void _reReadActiveGrants(Ref ref) {
  if (!ref.exists(incomingTutorGrantsProvider)) return;
  ref.invalidate(incomingTutorGrantsProvider);
  ref.read(incomingTutorGrantsProvider);
}
