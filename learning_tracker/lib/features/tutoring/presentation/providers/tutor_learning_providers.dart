/// Riverpod access to the tutored session's writes (Story 1.24, DNI-486).
///
/// [tutorLearningCommandsProvider] is what `learningCommandsProvider`
/// returns while a tutor is inside a talmid's context, so every capture
/// surface reaches the Story 1.23 callables through [TutorWriteService]
/// (AD-53) instead of the owner's Firestore batches.
/// [tutorGovernedWritesProvider] is the governed main-track counterpart
/// (Story 1.10 callables). Both run [tutorWritePreflightProvider] first.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/account_lock_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/sacred_windows_provider.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';

/// The [TutorWritePreflight] of the active tutored selection, or null
/// outside a tutored session.
///
/// It judges the device user's settings, from the same histories used by
/// the overlay and notification suppression. The talmid's scope is not a
/// lock input (product ruling 2026-10-05).
final tutorWritePreflightProvider = FutureProvider<TutorWritePreflight?>((
  ref,
) async {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  if (selection == null) return null;
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) return null;
  final settings = ref.listen(
    learnerLockSettingsProvider(scope).future,
    (_, _) {},
  );
  final connectivity = ref.listen(connectivityStreamProvider, (_, _) {});
  final histories = ref.watch(accountLockHistoriesProvider);
  return TutorWritePreflight(
    selection: selection,
    settingsHistory: () => settings.read(),
    lockHistories: () async => histories,
    gate: ref.watch(captureGateProvider),
    // A positive probe only: loading, an error or offline all disable
    // tutor writes (AD-53).
    isOnline: () => connectivity.read().value == true,
    clock: ref.watch(learningCommandClockProvider),
  );
}, retry: (retryCount, error) => null);

/// The [TutorLearningCommands] of the active tutored selection, or null
/// outside a tutored session or while the talmid's scope is not ready.
///
/// The commands live as long as the selection and scope do; the talmid's
/// event log and the corpora are read on demand, so a connectivity change
/// never drops a pending failure.
final tutorLearningCommandsProvider = FutureProvider<TutorLearningCommands?>((
  ref,
) async {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  if (selection == null) return null;
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) return null;
  final preflight = await ref.watch(tutorWritePreflightProvider.future);
  final events = await ref.watch(learningEventRepositoryProvider.future);
  if (preflight == null || events == null) return null;
  final corpora = ref.listen(corporaProvider.future, (_, _) {});
  // Listened, not awaited: an unavailable sub-track repository makes only
  // the sub-track commands answer onlineRequired, never captures.
  final subTracks = ref.listen(subTrackRepositoryProvider.future, (_, _) {});
  final commands = TutorLearningCommands(
    selection: selection,
    service: ref.watch(tutorWriteServiceProvider),
    preflight: preflight,
    events: () async {
      final ready = await events
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<LearningEvent>);
      return (ready as CompleteReadReady<LearningEvent>).items;
    },
    corpus: (curriculumId) async => (await corpora.read())[curriculumId],
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
    // Story 4.2 (DNI-510): the talmid's complete sub-track read; a read
    // with undecodable rows is unavailable (AD-35 complete inputs).
    subTracks: () async {
      final repository = await subTracks.read();
      if (repository == null) return null;
      final ready = await repository
          .watchAll(scope)
          .firstWhere((r) => r is CompleteReadReady<SubTrack>);
      final complete = ready as CompleteReadReady<SubTrack>;
      return complete.isClean ? complete.items : null;
    },
    ledger: ref.watch(tutorGovernedActionLedgerProvider),
  );
  ref.onDispose(commands.dispose);
  return commands;
}, retry: (retryCount, error) => null);

/// The session-wide frozen action ids of governed tutor actions awaiting a
/// definitive receipt (DNI-486 AC-5): kept alive so a retry from a
/// re-opened form, or after the writes provider rebuilt, reuses the id.
final tutorGovernedActionLedgerProvider = Provider<TutorGovernedActionLedger>(
  (ref) => TutorGovernedActionLedger(),
);

/// The [TutorGovernedWrites] of the active tutored selection, or null
/// outside a tutored session or while the talmid's scope is not ready.
final tutorGovernedWritesProvider = FutureProvider<TutorGovernedWrites?>((
  ref,
) async {
  final selection = ref.watch(activeTutoredProfileSelectionProvider);
  if (selection == null) return null;
  final preflight = await ref.watch(tutorWritePreflightProvider.future);
  if (preflight == null) return null;
  return TutorGovernedWrites(
    selection: selection,
    service: ref.watch(tutorWriteServiceProvider),
    preflight: preflight,
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
    ledger: ref.watch(tutorGovernedActionLedgerProvider),
  );
}, retry: (retryCount, error) => null);

/// [tutorGovernedWritesProvider] for a write that must happen: throws
/// [StateError] while the tutored context is not ready, so a tutor form
/// shows its save error instead of falling through to a client write.
Future<TutorGovernedWrites> requireTutorGovernedWrites(Ref ref) async {
  final writes = await ref.read(tutorGovernedWritesProvider.future);
  if (writes == null) {
    throw StateError('Tutored context is not ready for a governed write');
  }
  return writes;
}

/// Whether the DEVICE USER is inside their own lock window now:
/// `AsyncData(false)` outside a tutored session.
///
/// It controls tutor write affordances using the same account-owned lock
/// source as the app overlay. A talmid's lock never blocks the tutor from
/// opening the talmid's account (product ruling 2026-10-05).
final tutoredLearnerLockProvider = Provider.autoDispose<AsyncValue<bool>>((
  ref,
) {
  if (ref.watch(activeTutoredProfileSelectionProvider) == null) {
    return const AsyncData(false);
  }
  return AsyncData(ref.watch(currentSacredWindowProvider) != null);
});

/// The write availability of the active session for every tutor write
/// control (Story 1.24, DNI-486): the parent's `can_edit_learning` first,
/// then a positive connectivity probe, then the device user's own lock.
final tutorWriteAvailabilityProvider =
    Provider.autoDispose<TutorWriteAvailability>((ref) {
      final selection = ref.watch(activeTutoredProfileSelectionProvider);
      if (selection == null) return TutorWriteAvailability.owner;
      if (!selection.permissions.canEditLearning) {
        return TutorWriteAvailability.noEditAccess;
      }
      if (ref.watch(connectivityStreamProvider).value != true) {
        return TutorWriteAvailability.offline;
      }
      if (ref.watch(tutoredLearnerLockProvider).value == true) {
        return TutorWriteAvailability.locked;
      }
      return TutorWriteAvailability.available;
    });

/// The display name of the learner whose screens are showing (the talmid
/// in a tutored session), trimmed; null while unknown or blank. It names
/// the learner in the tutor write copy ("{learner}'s parent hasn't given
/// you editing access", "{learner}'s parent has turned off editing").
final tutorLearnerNameProvider = Provider.autoDispose<String?>((ref) {
  final name = ref
      .watch(activeProfileProvider)
      .asData
      ?.value
      ?.displayName
      .trim();
  return name == null || name.isEmpty ? null : name;
});
