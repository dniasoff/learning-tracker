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
import 'package:learning_tracker/core/time/ulid.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/features/learner_state/presentation/providers/learner_state_provider.dart';
import 'package:learning_tracker/features/learning/data/repositories/learning_command_sources.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
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
  (ref) =>
      () => DateTime.now().toUtc(),
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
  if (uid == null || port == null || points == null || events == null) {
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
  final corpora = ref.listen(corporaProvider.future, (_, _) {});
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
      corpus: (curriculumId) async => (await corpora.read())[curriculumId],
      points: points,
    ),
    writePort: port,
    gate: ref.watch(captureGateProvider),
    analytics: ref.watch(learningAnalyticsProvider),
    failureReporter: ref.watch(learningFailureReporterProvider),
    clock: ref.watch(learningCommandClockProvider),
    newUlid: newUlid,
  );
  ref.onDispose(commands.dispose);
  return commands;
}, retry: (retryCount, error) => null);
