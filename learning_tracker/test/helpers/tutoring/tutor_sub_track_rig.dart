/// Story 4.2 (DNI-510) acceptance rig: the shared Epic 2 sub-track surfaces
/// (Manage tracks Sub-tracks group, forms, detail, ground picker) in tutor
/// mode over the REAL [TutorLearningCommands] and [TutorWriteService].
///
/// A [RecordingTutorInvoker] plays the server: every call is recorded, and
/// a successful `tutorUpsertSubTrack` lands in the in-memory talmid mirror
/// ([SubTrackHarness.repo]) only once the callable has answered, so a test
/// sees exactly what a tutor device sees — nothing before success. [failWith]
/// scripts a callable failure and [hold] keeps a call in flight.
library;

import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/presentation/providers/learning_command_providers.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_governed_writes.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_learning_commands.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_preflight.dart';
import 'package:learning_tracker/features/tutoring/data/services/tutor_write_service.dart';
import 'package:learning_tracker/features/tutoring/domain/models/session_role.dart';

import '../learner_state/c0_fixtures.dart';
import '../learner_state/engine_fixtures.dart';
import '../learner_state/fake_learning_commands.dart';
import '../sub_tracks/sub_track_harness.dart';
import 'tutor_learning_harness.dart';

/// The tutor's own name in every rig (the tutor-mode bar).
const tutorRigTutorName = 'Rabbi Cohen';

/// One tutor-mode rig per test.
final class TutorSubTrackRig {
  /// Builds the rig over [seed] (the talmid's sub-tracks).
  TutorSubTrackRig({
    bool canEditLearning = true,
    Iterable<SubTrack> seed = const [],
    bool online = true,
  }) : hub = SubTrackHarness(seed: seed),
       selection = tutorSelection(canEditLearning: canEditLearning),
       _online = online {
    connectivity.emit(online);
    invoker = RecordingTutorInvoker(respond: _serve);
    service = TutorWriteService(invoker: invoker.call, analytics: analytics);
    final preflight = TutorWritePreflight(
      selection: selection,
      settingsHistory: () async => c0SettingsHistory(),
      gate: FakeCaptureGate.open(),
      isOnline: () => _online,
      clock: () => tutorFixtureNow,
    );
    commands = TutorLearningCommands(
      selection: selection,
      service: service,
      preflight: preflight,
      events: () async => const [],
      corpus: (id) async => id == engineCurriculum ? mishnayosCorpus() : null,
      clock: () => tutorFixtureNow,
      newUlid: (_) => _nextUlid(),
      subTracks: () async => hub.repo.tracksOf(hub.scope),
      ledger: ledger,
    );
  }

  /// The talmid's stores, forms environment and hub providers.
  final SubTrackHarness hub;

  /// The tutored selection.
  final TutoredProfileSelection selection;

  /// The connectivity the screens watch.
  final ConnectivityFeed connectivity = ConnectivityFeed();

  bool _online;

  /// The callable invoker (the server).
  late final RecordingTutorInvoker invoker;

  /// The analytics sink.
  final RecordingLearningAnalytics analytics = RecordingLearningAnalytics();

  /// The service under the commands.
  late final TutorWriteService service;

  /// The tutor's commands (what `learningCommandsProvider` returns).
  late final TutorLearningCommands commands;

  /// The frozen action ids.
  final TutorGovernedActionLedger ledger = TutorGovernedActionLedger();

  /// When set, the next calls fail with it (until cleared).
  FirebaseFunctionsException? failWith;

  /// When set, every call waits for it before answering.
  Completer<void>? hold;

  var _n = 0;

  String _nextUlid() {
    _n++;
    return '01JT7T0R00000000000000${_n.toString().padLeft(4, '0')}';
  }

  /// Flips the device's connectivity (the probe and the preflight).
  void setOnline(bool online) {
    _online = online;
    connectivity.emit(online);
  }

  /// The `tutorUpsertSubTrack` calls, in order.
  List<TutorCall> get subTrackCalls => [
    for (final c in invoker.calls)
      if (c.fn == 'tutorUpsertSubTrack') c,
  ];

  Future<Object?> _serve(TutorCall call) async {
    final gate = hold;
    if (gate != null) await gate.future;
    final failure = failWith;
    if (failure != null) throw failure;
    if (call.fn == 'tutorUpsertSubTrack') _apply(call);
    return invoker.successFor(call);
  }

  /// The server's write, reaching the talmid's mirror after success.
  void _apply(TutorCall call) {
    final id = call.args['subTrackId'] as String;
    final actionId = (call.args['actionId'] ?? id) as String;
    final fields = Map<String, Object?>.from(
      (call.args['fields'] as Map?) ?? const {},
    );
    final current = hub.repo
        .tracksOf(hub.scope)
        .where((t) => t.id == id)
        .firstOrNull;
    final base = current?.toStorage() ?? <String, Object?>{};
    final next = <String, Object?>{
      ...base,
      ...fields,
      SubTrack.kLastChangeId: actionId,
      if (call.args['op'] case 'end' || 'delete') ...{
        SubTrack.kEndedAt: tutorFixtureNow,
        SubTrack.kEndReason: call.args['op'] == 'end' ? 'ended' : 'deleted',
      },
    }..removeWhere((k, v) => v == null && k != SubTrack.kWindowEnd);
    next.putIfAbsent(SubTrack.kWindowEnd, () => null);
    hub.repo.seed(hub.scope, [SubTrack.fromStorage(id, next)]);
  }

  /// Provider overrides: the hub rig with the tutor's commands, plus the
  /// tutored session (selection, connectivity, the talmid's settings,
  /// gate, clock and name).
  List<Override> overrides() => [
    ...hub.overrides(parentSession: null, commands: false),
    learningCommandsProvider.overrideWith((ref) async => commands),
    ...tutoredOverrides(
      selection: selection,
      connectivity: connectivity,
      withScope: false,
    ),
  ];

  /// Closes the stores.
  Future<void> dispose() async {
    commands.dispose();
    await connectivity.close();
    await hub.dispose();
  }
}
