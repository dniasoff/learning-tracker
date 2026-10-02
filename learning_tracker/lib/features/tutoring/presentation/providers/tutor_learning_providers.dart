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
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/lock_windows.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_write_availability.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/tutor_grant_providers.dart';

/// The [TutorWritePreflight] of the active tutored selection, or null
/// outside a tutored session or while the talmid's scope is not ready.
///
/// It judges the TARGET learner: the talmid's own settings history (the
/// active scope is the talmid's, resolved from the validated grant —
/// ruling B10), never the tutor device's. Settings and connectivity are
/// read on demand through subscriptions held here, so the preflight lives
/// as long as the selection and scope do.
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
  return TutorWritePreflight(
    selection: selection,
    settingsHistory: () => settings.read(),
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

/// The longest [tutoredLearnerLockProvider] waits before re-judging the
/// lock. The provider re-judges exactly at the next lock boundary (the
/// start of the next window, or just after the end of the current one);
/// this backstop only bounds how long a wall-clock jump or a suspended
/// timer can go unnoticed.
const tutoredLearnerLockBackstop = Duration(seconds: 30);

/// How far ahead [tutoredLearnerLockProvider] looks for the next lock
/// start. Anything further away is reached through the backstop.
const Duration _nextLockLookahead = Duration(days: 8);

/// The delay until the tutored learner's lock state can next change after
/// [nowUtc] under [decision]: the instant just after the current lock ends,
/// or the start of the next lock, capped by [tutoredLearnerLockBackstop].
/// A lock that cannot be bounded (an unknown, zero-length lock or a window
/// computation that throws) is re-judged at the backstop.
Duration tutoredLearnerLockRecheckDelay(
  LearnerSettingsHistory settingsHistory,
  DateTime nowUtc,
  GateDecision decision,
) {
  final now = nowUtc.toUtc();
  DateTime? boundary;
  if (decision case GateLocked(:final window)) {
    if (window.endUtc.isAfter(now)) boundary = window.endUtc.add(civilTick);
  } else {
    try {
      for (final w in lockWindows(
        settingsHistory,
        now,
        now.add(_nextLockLookahead),
      )) {
        if (w.startUtc.isAfter(now)) {
          boundary = w.startUtc;
          break;
        }
      }
    } on Object {
      boundary = null;
    }
  }
  if (boundary == null) return tutoredLearnerLockBackstop;
  final delay = boundary.difference(now);
  if (delay <= Duration.zero) return tutoredLearnerLockBackstop;
  return delay < tutoredLearnerLockBackstop
      ? delay
      : tutoredLearnerLockBackstop;
}

/// Whether the TUTORED learner is inside a lock window now (AD-36
/// multi-learner rule): `AsyncData(false)` outside a tutored session.
///
/// It judges the talmid's own settings history with the shared
/// [captureGateProvider] — the same judgement the tutor preflight applies
/// to writes — never the tutor device's settings. Loading while the
/// talmid's settings load; an error when they cannot be read.
final tutoredLearnerLockProvider = Provider.autoDispose<AsyncValue<bool>>((
  ref,
) {
  if (ref.watch(activeTutoredProfileSelectionProvider) == null) {
    return const AsyncData(false);
  }
  final scope = ref.watch(activeLearnerScopeProvider);
  if (scope case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<bool>(error, stackTrace);
  }
  if (!scope.hasValue) return const AsyncLoading<bool>();
  final active = scope.requireValue;
  if (active == null) return const AsyncLoading<bool>();
  final settings = ref.watch(learnerLockSettingsProvider(active));
  if (settings case AsyncError(:final error, :final stackTrace)) {
    return AsyncError<bool>(error, stackTrace);
  }
  if (!settings.hasValue) return const AsyncLoading<bool>();
  final now = ref.watch(learningCommandClockProvider)().toUtc();
  final history = settings.requireValue;
  final decision = ref.watch(captureGateProvider).check(history, now);
  // Re-judge at the next lock boundary, so the cover appears the instant
  // the learner's lock starts and leaves the instant it ends.
  final timer = Timer(
    tutoredLearnerLockRecheckDelay(history, now, decision),
    ref.invalidateSelf,
  );
  ref.onDispose(timer.cancel);
  return AsyncData(decision is GateLocked);
});

/// The write availability of the active session for every tutor write
/// control (Story 1.24, DNI-486): the parent's `can_edit_learning` first,
/// then a positive connectivity probe, then the tutored learner's lock
/// (loading or unreadable counts as locked: fail closed).
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
      if (ref.watch(tutoredLearnerLockProvider).value != false) {
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
