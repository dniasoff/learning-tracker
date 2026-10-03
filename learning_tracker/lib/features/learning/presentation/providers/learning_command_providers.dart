/// Riverpod access to [LearningCommands], its [CaptureGate], its
/// [LearningAnalytics] seam and its [LearningFailureReporter].
///
/// C0 (DNI-524) fixes the names and types; DNI-469 (1.7) fills them. Plain
/// Riverpod providers (no codegen), matching the DNI-464 provider style.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/core/analytics/analytics_provider.dart';
import 'package:learning_tracker/core/analytics/analytics_service.dart';
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/core/logging/crashlytics_service.dart';
import 'package:learning_tracker/core/providers/crashlytics_provider.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/civil_date.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learner_state.dart';
import 'package:learning_tracker/domain/learner_state/learner_zone.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_intent_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/gamification/data/repositories/achievement_latch_adapter.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/achievement_latch.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/governed_action_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/learning/domain/commands/owner_governed_writer.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/sub_track_source_check.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/parent_pin_session_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

/// The capture gate every command runs first (AD-36).
final captureGateProvider = Provider<CaptureGate>(
  (ref) => const LockWindowCaptureGate(),
);

/// The learning analytics seam: AD-47 enum/count payloads, logged through
/// the [AnalyticsService] catalog (`AnalyticsEvent.capture`).
final learningAnalyticsProvider = Provider<LearningAnalytics>((ref) {
  final analytics = ref.watch(analyticsServiceProvider);
  return SinkLearningAnalytics((event, parameters) {
    final Future<void> sent;
    switch (event) {
      case LearningAnalyticsEvent.capture:
        sent = analytics.logEvent(
          AnalyticsEvent.capture,
          parameters: parameters,
        );
      case LearningAnalyticsEvent.subTrackLifecycle:
        sent = analytics.logEvent(
          AnalyticsEvent.subTrackLifecycle,
          parameters: parameters,
        );
    }
    // Analytics never fails a command.
    unawaited(sent.catchError((Object _) {}));
  });
});

/// Sends permanently rejected learning writes to Crashlytics as non-fatal
/// errors carrying enums and a count only (AD-54 Observability).
final class CrashlyticsLearningFailureReporter
    implements LearningFailureReporter {
  /// Creates the reporter.
  const CrashlyticsLearningFailureReporter(this._crashlytics);

  final CrashlyticsService _crashlytics;

  @override
  void writeRejected({
    required LearningCommandKind command,
    required PendingFailureReason reason,
    required int writeCount,
  }) {
    final error = LearningWriteRejectedError(
      command: command,
      reason: reason,
      writeCount: writeCount,
    );
    unawaited(
      _crashlytics
          .recordError(error, StackTrace.current)
          .catchError((Object _) {}),
    );
  }
}

/// The [LearningFailureReporter] of the commands.
final learningFailureReporterProvider = Provider<LearningFailureReporter>(
  (ref) =>
      CrashlyticsLearningFailureReporter(ref.watch(crashlyticsServiceProvider)),
);

/// The UTC clock the commands read once per command (tests override it;
/// TQ-6: no wall clock in tests).
final learningCommandClockProvider = Provider<UtcClock>(
  (ref) => ref.watch(localDayClockProvider).nowUtc,
);

/// The session [Actor] of an owner write (AD-46): the live signed-in
/// [uid]; `child` while the active [profile] is a child profile whose
/// parent PIN is not verified this session ([pinProfileId]), else
/// `parent`. A child's display name is the profile's; a parent's is empty
/// (no parent name is known on the device).
Actor learningSessionActor({
  required String uid,
  required LearnerProfileEntity? profile,
  required String? pinProfileId,
}) {
  final child =
      profile != null &&
      profile.mode == ProfileMode.child &&
      pinProfileId != profile.profileId;
  return Actor(
    uid: uid,
    role: child ? ActorRole.child : ActorRole.parent,
    displayName: child ? profile.displayName : '',
  );
}

/// The learner state of [scope] as the commands' achievement latch reads it
/// (DNI-480): the latest complete state and every later one, held through
/// a subscription that lives as long as the commands.
LearnerStateFeed learnerStateFeed(Ref ref, LearnerScope scope) {
  final changes = StreamController<LearnerState>.broadcast();
  LearnerState? latest;
  ref.listen<AsyncValue<LearnerState>>(learnerStateProvider(scope), (_, next) {
    if (next case AsyncData(:final value)) {
      latest = value;
      changes.add(value);
    }
  }, fireImmediately: true);
  ref.onDispose(changes.close);
  return LearnerStateFeed(latest: () => latest, changes: changes.stream);
}

/// The learner's civil date under the current settings, falling back to UTC
/// until the settings history is available.
CivilDate learnerToday(DateTime nowUtc, LearnerSettingsHistory? history) =>
    history == null
    ? formatCivilDay(DateTime.utc(nowUtc.year, nowUtc.month, nowUtc.day))
    : civilDate(nowUtc, history);

final class _DeferredGovernedIntentRepository
    implements GovernedIntentRepository {
  _DeferredGovernedIntentRepository(this._resolve);

  final Future<GovernedIntentRepository?> Function() _resolve;

  @override
  Stream<LearnerIntent> watch(LearnerScope scope) async* {
    final GovernedIntentRepository? repository;
    try {
      repository = await _resolve();
    } on Object {
      throw TimeoutException('governed intent repository unavailable');
    }
    // Not ready: the read fails as a timeout, so the command answers
    // onlineRequired (a closed stream would surface as a StateError).
    if (repository == null) {
      throw TimeoutException('governed intent repository unavailable');
    }
    yield* repository.watch(scope);
  }
}

/// A [SubTrackRepository] that resolves the real one only when a sub-track
/// command first reads it, so ordinary captures never wait on, or fail
/// with, the sub-track repository (DNI-497). While it is unavailable (not
/// ready, or its provider failed) [watchAll] fails as a timeout, so the
/// command answers onlineRequired; every other command is unaffected.
final class _DeferredSubTrackRepository implements SubTrackRepository {
  _DeferredSubTrackRepository(this._resolve);

  final Future<SubTrackRepository?> Function() _resolve;

  Future<SubTrackRepository?> _repository() async {
    try {
      return await _resolve();
    } on Object {
      return null;
    }
  }

  @override
  Stream<CompleteRead<SubTrack>> watchAll(LearnerScope scope) async* {
    final repository = await _repository();
    if (repository == null) {
      throw TimeoutException('sub-track repository unavailable');
    }
    yield* repository.watchAll(scope);
  }

  @override
  Future<void> applyGovernedChange(
    LearnerScope scope,
    SubTrackChange change,
  ) async {
    // Reached only after watchAll delivered a complete read, so the
    // repository has resolved; a null here is the account going away
    // between the read and the write.
    final repository = await _repository();
    if (repository == null) {
      throw StateError('sub-track repository unavailable');
    }
    return repository.applyGovernedChange(scope, change);
  }
}

/// The commands bound to the active learner's scope and session actor, or
/// null while no learner is active, the account is not ready, or the
/// session is a tutored one (tutor writes go through callables, AD-53;
/// the `tutor` role is never client-written, AD-46).
///
/// The commands live as long as the scope and actor do, so their pending
/// failures survive settings and corpus changes: those are read on demand
/// through subscriptions held here.
final learningCommandsProvider = FutureProvider<LearningCommands?>((ref) async {
  if (ref.watch(activeTutoredProfileSelectionProvider) != null) return null;
  final scope = await ref.watch(activeLearnerScopeProvider.future);
  if (scope == null) return null;
  final uid = await ref.watch(activeAuthUidProvider.future);
  final port = await ref.watch(learningWritePortProvider.future);
  final points = await ref.watch(pointsAmountReaderProvider.future);
  final events = await ref.watch(learningEventRepositoryProvider.future);
  final changeLog = await ref.watch(changeLogRepositoryProvider.future);
  final docReader = await ref.watch(governedDocReaderProvider.future);
  final oversized = await ref.watch(oversizedGovernedWritePortProvider.future);
  if (uid == null ||
      port == null ||
      points == null ||
      events == null ||
      changeLog == null ||
      docReader == null ||
      oversized == null) {
    return null;
  }
  final actor = learningSessionActor(
    uid: uid,
    profile: await ref.watch(activeProfileProvider.future),
    pinProfileId: ref.watch(parentPinAuthenticatedProfileIdProvider),
  );
  final settings = ref.listen(
    learnerLockSettingsProvider(scope).future,
    (_, _) {},
  );
  final settingsNow = ref.listen(learnerLockSettingsProvider(scope), (_, _) {});
  final corpora = ref.listen(corporaProvider.future, (_, _) {});
  final intent = ref.listen(governedIntentRepositoryProvider.future, (_, _) {});
  final subTrackRepository = ref.listen(
    subTrackRepositoryProvider.future,
    (_, _) {},
  );
  final subTracks = _DeferredSubTrackRepository(subTrackRepository.read);
  final clock = ref.watch(learningCommandClockProvider);
  Future<Corpus?> corpusOf(String curriculumId) async =>
      (await corpora.read())[curriculumId];
  final failureReporter = ref.watch(learningFailureReporterProvider);
  // The sub-track commands treat an unreadable corpus as absent: their
  // contract skips only the cross-curriculum ground check then, while the
  // AD-45 limit rules still run. A sub-track save never fails on the
  // corpus read (until DNI-474 fills corporaProvider, every read fails).
  Future<Corpus?> subTrackCorpusOf(String curriculumId) async {
    try {
      return await corpusOf(curriculumId);
    } on Object {
      return null;
    }
  }

  final governed = DefaultGovernedLearningCommands(
    scope: scope,
    actor: actor,
    changeLog: changeLog,
    subTracks: subTracks,
    reader: docReader,
    oversized: oversized,
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
    failureReporter: failureReporter,
  );
  final achievements = AchievementLatch(
    FirestoreAchievementLatchAdapter(
      ref: ref,
      states: learnerStateFeed(ref, scope),
    ),
  );
  final subTrackCommands = SubTrackCommands(
    scope: scope,
    actor: actor,
    subTracks: subTracks,
    intent: _DeferredGovernedIntentRepository(intent.read),
    today: () => learnerToday(clock(), settingsNow.read().value),
    nowUtc: clock,
    newId: newUlid,
    corpusOf: subTrackCorpusOf,
    analytics: ref.watch(learningAnalyticsProvider),
  );
  final commands = DefaultLearningCommands(
    scope: scope,
    actor: actor,
    reads: LearningCommandReadsFrom(
      settingsHistory: (_) => settings.read(),
      events: (s) async {
        final ready = await events
            .watchAll(s)
            .firstWhere((r) => r is CompleteReadReady<LearningEvent>);
        return (ready as CompleteReadReady<LearningEvent>).items;
      },
      corpus: corpusOf,
      points: points,
    ),
    writePort: port,
    gate: ref.watch(captureGateProvider),
    analytics: ref.watch(learningAnalyticsProvider),
    failureReporter: failureReporter,
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
    governed: governed,
    achievements: achievements,
    // A sub-track source must be live in this learner's scope and curriculum.
    sourceCheck: subTrackSourceCheckFrom(subTracks, scope),
    subTrackCommands: subTrackCommands,
  );
  // Recover any latch a failed check left absent (app start, learner
  // switch); runs in the background and retries its own failures.
  unawaited(achievements.reconcile(scope));
  ref.onDispose(achievements.dispose);
  ref.onDispose(commands.dispose);
  ref.onDispose(governed.dispose);
  ref.onDispose(subTrackCommands.dispose);
  return commands;
}, retry: (retryCount, error) => null);

/// The governed writer the owner repositories (goals, curriculum tracks,
/// order, programs, study days, stages, scopes) write through (AD-38,
/// DNI-476): every write resolves [learningCommandsProvider] at call time
/// and goes through `applyGovernedChange`; with no commands (no active
/// learner, or a tutored session) it throws
/// [GovernedWriterNotReadyException] and nothing is written.
final ownerGovernedWriterProvider = Provider<OwnerGovernedWriter>(
  (ref) => LearningCommandsOwnerWriter(
    () => ref.read(learningCommandsProvider.future),
  ),
);
