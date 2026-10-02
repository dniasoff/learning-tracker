/// Hermetic harness for the Story 1.24 (DNI-486) tutor write tests: a
/// recording callable invoker, a tutored selection, and
/// [TutorLearningCommands] / [TutorGovernedWrites] built over in-memory
/// reads, a scripted gate and a scripted connectivity probe.
library;

import 'dart:async';

import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/core/domain/value_objects/profile_mode.dart';
import 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart';
import 'package:learning_tracker/domain/learner_state/corpus.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/features/account/presentation/providers/connectivity_providers.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/profiles/domain/models/learner_profile_entity.dart';
import 'package:learning_tracker/features/profiles/presentation/providers/active_profile_provider.dart';
import 'package:learning_tracker/features/sacred_time/presentation/providers/learner_lock_settings_provider.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';
import 'package:learning_tracker/features/tutoring/domain/models/tutor_permissions.dart';
import 'package:learning_tracker/features/tutoring/presentation/providers/active_tutored_profile_provider.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/fake_learning_commands.dart';
import '../learner_state_fixtures.dart';

/// The talmid's owner (the parent) in every tutor fixture.
const tutorFixtureOwnerUid = 'parent-uid';

/// The grant in every tutor fixture.
const tutorFixtureGrantId = 'grant-1';

/// The fixed instant tutor commands are judged at.
final tutorFixtureNow = DateTime.utc(2026, 10, 1, 9);

/// A tutored selection of [profileUlid] by [tutorFixtureGrantId].
TutoredProfileSelection tutorSelection({bool canEditLearning = true}) =>
    TutoredProfileSelection(
      profileId: profileUlid,
      ownerUid: tutorFixtureOwnerUid,
      grantId: tutorFixtureGrantId,
      permissions: TutorPermissions(
        canViewProgress: true,
        canViewContent: true,
        canEditLearning: canEditLearning,
      ),
    );

/// One recorded callable invocation.
typedef TutorCall = ({String fn, Map<String, dynamic> args});

/// A [TutorCallableInvoker] that records every call and answers from
/// [respond] (default: the Story 1.23 success shape echoing the ids).
final class RecordingTutorInvoker {
  /// Creates the invoker.
  RecordingTutorInvoker({this.respond});

  /// Scripted answer; may throw a `FirebaseFunctionsException`.
  Object? Function(TutorCall call)? respond;

  /// The server stamp of the default success answer.
  DateTime recordedAt = DateTime.utc(2026, 10, 1, 9, 0, 1);

  /// Every call, in order.
  final List<TutorCall> calls = [];

  /// The invoker function.
  Future<Object?> call(String fn, Map<String, dynamic> args) async {
    final call = (fn: fn, args: args);
    calls.add(call);
    final scripted = respond;
    if (scripted != null) return scripted(call);
    return successFor(call);
  }

  /// The default success answer for [call].
  Map<String, Object?> successFor(TutorCall call, {bool replayed = false}) => {
    'success': true,
    'action_id': call.args['actionId'],
    'event_ids': eventIdsOf(call),
    'change_ids': const <String>[],
    'recorded_at': recordedAt.toIso8601String(),
    'replayed': replayed,
  };

  /// The event ids a call carries (record, void, replace).
  static List<String> eventIdsOf(TutorCall call) => [
    if (call.args['events'] case final List<Object?> events)
      for (final e in events) (e! as Map)['id']! as String,
    if (call.args['eventId'] case final String id) id,
    if (call.args['replacement'] case final Map<Object?, Object?> r)
      r['id']! as String,
  ];
}

/// A connectivity probe the test flips.
final class ScriptedConnectivity {
  /// Starts [online].
  ScriptedConnectivity({this.online = true});

  /// The current probe.
  bool online;
}

/// Everything a tutor command test drives.
final class TutorHarness {
  /// Builds the harness.
  TutorHarness({
    bool canEditLearning = true,
    bool online = true,
    CaptureGate? gate,
    LearnerSettingsHistory? history,
    List<LearningEvent>? events,
    Map<String, Corpus>? corpora,
    RecordingTutorInvoker? invoker,
  }) : selection = tutorSelection(canEditLearning: canEditLearning),
       connectivity = ScriptedConnectivity(online: online),
       gate = gate ?? FakeCaptureGate.open(),
       history = history ?? c0SettingsHistory(),
       eventLog = events ?? [],
       corpora = corpora ?? {},
       invoker = invoker ?? RecordingTutorInvoker(),
       analytics = RecordingLearningAnalytics() {
    service = TutorWriteService(
      invoker: this.invoker.call,
      analytics: analytics,
    );
    preflight = TutorWritePreflight(
      selection: selection,
      settingsHistory: () async => this.history,
      gate: this.gate,
      isOnline: () => connectivity.online,
      clock: () => tutorFixtureNow,
    );
    commands = TutorLearningCommands(
      selection: selection,
      service: service,
      preflight: preflight,
      events: () async => eventLog,
      corpus: (id) async => this.corpora[id],
      clock: () => tutorFixtureNow,
      newUlid: _ulids.next,
    );
    governed = TutorGovernedWrites(
      selection: selection,
      service: service,
      preflight: preflight,
      clock: () => tutorFixtureNow,
      newUlid: _ulids.next,
    );
  }

  /// The tutored selection.
  final TutoredProfileSelection selection;

  /// The connectivity probe.
  final ScriptedConnectivity connectivity;

  /// The target learner's gate.
  final CaptureGate gate;

  /// The target learner's settings history.
  LearnerSettingsHistory history;

  /// The talmid's event log the commands read.
  final List<LearningEvent> eventLog;

  /// The corpora by curriculum.
  final Map<String, Corpus> corpora;

  /// The callable invoker.
  final RecordingTutorInvoker invoker;

  /// The capture analytics sink.
  final RecordingLearningAnalytics analytics;

  /// The service under the commands.
  late final TutorWriteService service;

  /// The shared preflight.
  late final TutorWritePreflight preflight;

  /// The commands under test.
  late final TutorLearningCommands commands;

  /// The governed writes under test.
  late final TutorGovernedWrites governed;

  final _ulids = _UlidSequence();

  /// Releases the commands.
  void dispose() => commands.dispose();
}

/// Deterministic, ascending ULIDs (`01JT7T0R…0001`, `…0002`, …).
final class _UlidSequence {
  var _n = 0;

  String next(DateTime _) {
    _n++;
    return '01JT7T0R00000000000000${_n.toString().padLeft(4, '0')}';
  }
}

/// The talmid's display name in every tutor fixture.
const tutorFixtureLearnerName = 'Yossi';

/// The talmid's scope (the parent's namespace).
LearnerScope tutorFixtureScope() =>
    LearnerScope(ownerUid: tutorFixtureOwnerUid, profileId: profileUlid);

/// An [ActiveTutoredProfileSelection] fixed to one selection (null: the
/// tutor's own app).
final class FixedTutoredSelection extends ActiveTutoredProfileSelection {
  /// Creates the notifier.
  FixedTutoredSelection(this._initial);

  final TutoredProfileSelection? _initial;

  @override
  TutoredProfileSelection? build() => _initial;
}

/// Connectivity the test drives: each [emit] is one probe result.
final class ConnectivityFeed {
  final _controller = StreamController<bool>.broadcast();
  bool? _last;

  /// The stream behind `connectivityStreamProvider`.
  Stream<bool> stream() async* {
    final last = _last;
    if (last != null) yield last;
    yield* _controller.stream;
  }

  /// Emits one probe result.
  void emit(bool online) {
    _last = online;
    _controller.add(online);
  }

  /// Closes the feed.
  Future<void> close() => _controller.close();
}

/// Provider overrides for a tutored session over the talmid in
/// [tutorFixtureScope]: the selection (null: the tutor's own app), the
/// connectivity probe ([online] or a [connectivity] feed; an
/// `Exception` makes it error), the talmid's settings history and gate,
/// a fixed clock at [tutorFixtureNow] and the talmid's profile name.
List<Override> tutoredOverrides({
  TutoredProfileSelection? selection,
  bool online = true,
  ConnectivityFeed? connectivity,
  Object? connectivityError,
  LearnerSettingsHistory? lockSettings,
  Stream<LearnerSettingsHistory>? lockSettingsStream,
  CaptureGate? gate,
  DateTime? now,
}) => [
  activeTutoredProfileSelectionProvider.overrideWith(
    () => FixedTutoredSelection(selection),
  ),
  activeLearnerScopeProvider.overrideWith((ref) async => tutorFixtureScope()),
  connectivityStreamProvider.overrideWith((ref) {
    if (connectivityError != null) return Stream<bool>.error(connectivityError);
    return connectivity?.stream() ?? Stream.value(online);
  }),
  learnerLockSettingsProvider.overrideWith(
    (ref, _) =>
        lockSettingsStream ?? Stream.value(lockSettings ?? c0SettingsHistory()),
  ),
  captureGateProvider.overrideWithValue(gate ?? FakeCaptureGate.open()),
  learningCommandClockProvider.overrideWithValue(() => now ?? tutorFixtureNow),
  tutorLearnerNameOverride(),
];

/// The talmid's profile (its name feeds the tutor note).
Override tutorLearnerNameOverride() => activeProfileProvider.overrideWith(
  (ref) async => LearnerProfileEntity(
    profileId: profileUlid,
    displayName: tutorFixtureLearnerName,
    mode: ProfileMode.child,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  ),
);
