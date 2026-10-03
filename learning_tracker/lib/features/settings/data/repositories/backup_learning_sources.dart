/// The settings feature's repository layer for the AD-49 backup (AD-23
/// `R`, DNI-482): the one place `data_export_import_providers.dart`
/// reaches the learner-state repositories
/// (`tool/check_dependency_direction.dart` Rule A), plus the
/// [BackupLearningPort] built on them.
///
/// Re-exports the learner-state providers without a second declaration
/// (ruling B4).
library;

import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/domain/learner_state/actor.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings_history.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/learning_event_stamp.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/change_log_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/complete_read.dart';
import 'package:learning_tracker/domain/learner_state/ports/governed_doc_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_scope.dart';
import 'package:learning_tracker/domain/learner_state/ports/learner_settings_reader.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_command_reads.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_event_repository.dart';
import 'package:learning_tracker/domain/learner_state/ports/learning_write_port.dart';
import 'package:learning_tracker/domain/learner_state/ports/sub_track_repository.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_gate.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_analytics.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_commands.dart';
import 'package:learning_tracker/features/learning/domain/commands/learning_failure_reporter.dart';
import 'package:learning_tracker/features/settings/domain/services/backup_learning_port.dart';

export 'package:learning_tracker/data/firestore/learner_state_repository_providers.dart'
    show
        activeAuthUidProvider,
        changeLogRepositoryProvider,
        governedDocReaderProvider,
        learnerSettingsReaderProvider,
        learningEventRepositoryProvider,
        learningWritePortProvider,
        pointsAmountReaderProvider,
        subTrackRepositoryProvider;

/// How long a backup read waits for a complete read.
const Duration backupReadWait = Duration(seconds: 20);

/// A [BackupRecordWritePort] over the backup gateway: one batch of creates
/// under `{profilePath}/{collection}/{docId}`.
final class GatewayBackupRecordWritePort implements BackupRecordWritePort {
  /// Creates the port.
  const GatewayBackupRecordWritePort(this._gateway);

  final BackupFirestoreGateway _gateway;

  @override
  Future<void> commit(LearnerScope scope, List<BackupRecordWrite> writes) {
    if (writes.length > BackupRecordWritePort.maxWrites) {
      throw ArgumentError.value(writes.length, 'writes', 'over the budget');
    }
    return _gateway.writeBatch([
      for (final w in writes)
        BackupDocumentWrite(
          '${scope.profilePath}/${w.collection.name}/${w.docId}',
          Map<String, dynamic>.of(w.fields),
        ),
    ]);
  }
}

/// The production [BackupLearningPort]: one owner [LearningCommands] per
/// restored profile, bound to that profile's [LearnerScope] and the
/// importing parent, kept for the session so its "not saved — retry"
/// failures stay retryable.
final class CommandsBackupLearningPort implements BackupLearningPort {
  /// Creates the port for the account [ownerUid], written as [actor].
  CommandsBackupLearningPort({
    required this.ownerUid,
    required this.actor,
    required SubTrackRepository subTracks,
    required ChangeLogRepository changeLog,
    required GovernedDocReader reader,
    required LearnerSettingsReader settings,
    required LearningEventRepository events,
    required LearningWritePort writePort,
    required PointsAmountReader points,
    required BackupRecordWritePort records,
    required LearningFailureReporter failureReporter,
    required UtcClock clock,
    required UlidSource newUlid,
    CaptureGate gate = const LockWindowCaptureGate(),
  }) : _subTracks = subTracks,
       _changeLog = changeLog,
       _reader = reader,
       _settings = settings,
       _events = events,
       _writePort = writePort,
       _points = points,
       _records = records,
       _failureReporter = failureReporter,
       _clock = clock,
       _newUlid = newUlid,
       _gate = gate;

  /// The account's path uid.
  final String ownerUid;

  /// The importing owner.
  final Actor actor;

  final SubTrackRepository _subTracks;
  final ChangeLogRepository _changeLog;
  final GovernedDocReader _reader;
  final LearnerSettingsReader _settings;
  final LearningEventRepository _events;
  final LearningWritePort _writePort;
  final PointsAmountReader _points;
  final BackupRecordWritePort _records;
  final LearningFailureReporter _failureReporter;
  final UtcClock _clock;
  final UlidSource _newUlid;
  final CaptureGate _gate;

  final Map<String, DefaultLearningCommands> _commands = {};
  final Map<String, BackupReplayInput> _inputs = {};

  LearnerScope _scope(String profileId) =>
      LearnerScope(ownerUid: ownerUid, profileId: profileId);

  @override
  Future<List<SubTrack>> readSubTracks(String profileId) async {
    final read = await _subTracks
        .watchAll(_scope(profileId))
        .firstWhere((r) => r is CompleteReadReady<SubTrack>)
        .timeout(backupReadWait);
    final ready = read as CompleteReadReady<SubTrack>;
    if (!ready.isClean) {
      throw StateError('sub_tracks of $profileId hold undecodable rows');
    }
    return ready.items;
  }

  @override
  Future<List<LearningEvent>> readLearningEvents(String profileId) async {
    final read = await _events
        .watchAll(_scope(profileId))
        .firstWhere((r) => r is CompleteReadReady<LearningEvent>)
        .timeout(backupReadWait);
    final ready = read as CompleteReadReady<LearningEvent>;
    if (!ready.isClean) {
      throw StateError('learning_events of $profileId hold undecodable rows');
    }
    return ready.items;
  }

  @override
  Future<BackupReplayResult> replay(String profileId, BackupReplayInput input) {
    _inputs[profileId] = input;
    return _commandsFor(profileId).importBackup(input);
  }

  @override
  Future<CaptureResult> retry(String profileId, String pendingFailureId) =>
      _commands[profileId]?.retry(pendingFailureId) ??
      Future.value(
        const CaptureResult.rejected(CaptureRejection.targetNotFound),
      );

  DefaultLearningCommands _commandsFor(String profileId) =>
      _commands.putIfAbsent(profileId, () {
        final scope = _scope(profileId);
        return DefaultLearningCommands(
          scope: scope,
          actor: actor,
          reads: LearningCommandReadsFrom(
            settingsHistory: _settingsHistory,
            events: (s) async {
              final read = await _events
                  .watchAll(s)
                  .firstWhere((r) => r is CompleteReadReady<LearningEvent>)
                  .timeout(backupReadWait);
              return (read as CompleteReadReady<LearningEvent>).items;
            },
            // An import never reads a corpus.
            corpus: (_) async => null,
            points: _points,
          ),
          writePort: _writePort,
          gate: _gate,
          // An import emits no capture analytics.
          analytics: SinkLearningAnalytics((_, _) {}),
          failureReporter: _failureReporter,
          clock: _clock,
          newUlid: _newUlid,
          backupReplay: BackupImportReplay(
            scope: scope,
            changeLog: _changeLog,
            subTracks: _subTracks,
            reader: _reader,
            writePort: _writePort,
            records: _records,
            failureReporter: _failureReporter,
          ),
        );
      });

  /// The destination's settings history; when the destination has no
  /// readable settings yet (a profile restored onto an account that lost
  /// it), the history the backup is about to restore — so the lock gate
  /// still judges the import (AD-36).
  Future<LearnerSettingsHistory> _settingsHistory(LearnerScope scope) async {
    try {
      final current = await _settings
          .watch(scope)
          .first
          .timeout(backupReadWait);
      final read = await _changeLog
          .watchIntentHistory(scope)
          .firstWhere((r) => r is CompleteReadReady<ChangeLogEntry>)
          .timeout(backupReadWait);
      final ready = read as CompleteReadReady<ChangeLogEntry>;
      if (!ready.isClean) throw StateError('unreadable settings history');
      return LearnerSettingsHistory.reconstruct(
        current: current,
        entries: ready.items,
      );
    } on Object {
      final input = _inputs[scope.profileId];
      final restored = restoredSettingsHistory(
        scope.profileId,
        input?.changeLog ?? const [],
        seed: input?.settingsSeed ?? const {},
      );
      if (restored == null) rethrow;
      return restored;
    }
  }
}

/// The settings history a backup describes for [profileId]: its
/// `learnerSettings` [entries] ending in the source's current settings
/// [seed] (`BackupReplayInput.settingsSeed`), or, without a seed, in the
/// state the entries build. Null when neither holds a time zone.
LearnerSettingsHistory? restoredSettingsHistory(
  String profileId,
  List<ChangeLogEntry> entries, {
  Map<String, Object?> seed = const {},
}) {
  final mine =
      entries.where((e) => e.entity == GovernedEntity.learnerSettings).toList()
        ..sort((a, b) {
          final byTime = (a.originalAt ?? a.at).compareTo(b.originalAt ?? b.at);
          return byTime != 0 ? byTime : a.id.compareTo(b.id);
        });
  if (seed[LearnerSettings.kTimeZone] != null) {
    try {
      return LearnerSettingsHistory.reconstruct(
        current: LearnerSettings.fromProfileDoc(profileId, seed),
        entries: [
          for (final e in mine)
            if (e.entityId == profileId) e,
        ],
      );
    } on StorageFormatException {
      // Fall back to the entries alone.
    }
  }
  final fields = <String, Object?>{};
  for (final e in mine) {
    for (final MapEntry(:key, :value) in e.after.entries) {
      final k = ChangedFieldKey.tryParse(key);
      if (k != null) fields[k.field] = value;
    }
  }
  try {
    final current = LearnerSettings.fromProfileDoc(profileId, {
      for (final MapEntry(:key, :value) in fields.entries)
        if (value != null && key != LearnerSettings.kLastChangeId) key: value,
    });
    return LearnerSettingsHistory.reconstruct(
      current: current,
      entries: [
        for (final e in mine)
          if (e.entityId == profileId) e,
      ],
    );
  } on StorageFormatException {
    return null;
  }
}
