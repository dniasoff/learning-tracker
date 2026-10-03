import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/domain/learner_state/change_log_entry.dart';
import 'package:learning_tracker/domain/learner_state/learner_settings.dart';
import 'package:learning_tracker/domain/learner_state/learning_event.dart';
import 'package:learning_tracker/domain/learner_state/ports/backup_record_write_port.dart';
import 'package:learning_tracker/domain/learner_state/storage_codec.dart';
import 'package:learning_tracker/domain/learner_state/sub_track.dart';
import 'package:learning_tracker/features/learning/domain/commands/backup_import_replay.dart';
import 'package:learning_tracker/features/learning/domain/commands/capture_result.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:learning_tracker/features/settings/domain/services/backup_learning_port.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart'
    show BackupDocumentWrite, BackupFirestoreGateway, backupLearningEventsKey;
export 'package:learning_tracker/features/settings/domain/services/backup_learning_port.dart'
    show BackupLearningPort;

/// Summary of a Firestore backup payload.
class ImportPreview {
  const ImportPreview({
    required this.learningEventCount,
    required this.subTrackCount,
    required this.goalCount,
    required this.stageCount,
    required this.pointConfigCount,
    required this.bookmarkCount,
    required this.learningOrderCount,
    required this.curriculumTrackCount,
    required this.userProfileCount,
    required this.exportedAt,
    required this.appVersion,
    required this.totalDocumentCount,
  });

  final int learningEventCount;
  final int subTrackCount;
  final int goalCount;
  final int stageCount;
  final int pointConfigCount;
  final int bookmarkCount;
  final int learningOrderCount;
  final int curriculumTrackCount;
  final int userProfileCount;
  final int totalDocumentCount;
  final String exportedAt;
  final String appVersion;

  int get totalRecords => totalDocumentCount;
}

/// What a restore did, per restored profile (AD-49, AD-54).
final class BackupImportReport {
  /// Creates the report.
  BackupImportReport({
    required Map<String, BackupReplayResult> profiles,
    required BackupLearningPort learning,
    Set<String> alreadyRestored = const {},
  }) : profiles = Map.unmodifiable(profiles),
       alreadyRestored = Set.unmodifiable(alreadyRestored),
       _learning = learning;

  /// Each restored profile's replay result, by profile id.
  final Map<String, BackupReplayResult> profiles;

  /// The profiles whose learning record this backup already restored: not
  /// replayed again, since a replay writes every record under fresh ids
  /// and would duplicate the history, awards, spends and redemptions.
  final Set<String> alreadyRestored;

  final BackupLearningPort _learning;

  /// Whether every learning write was saved: no profile was refused, none
  /// has a "not saved — retry" failure and none still awaits the server.
  bool get saved => profiles.values.every((r) => r.saved);

  /// Whether nothing failed so far but some write still awaits the server
  /// (queued offline); [settled] completes when it is acknowledged or
  /// rejected, after which [saved] and [notSavedCount] are final.
  bool get queued =>
      notSavedCount == 0 &&
      profiles.values.every((r) => r.result is CaptureSuccess) &&
      profiles.values.any((r) => !r.isSettled);

  /// Completes once every queued write was acknowledged or rejected.
  Future<void> get settled =>
      Future.wait([for (final r in profiles.values) r.settled]);

  /// The writes the server did not save, including a queued write it
  /// rejected after the ack wait.
  int get notSavedCount =>
      profiles.values.fold(0, (n, r) => n + r.notSaved.length);

  /// Re-sends every write that was not saved, unchanged (AD-54 Recovery).
  Future<void> retryNotSaved() async {
    for (final MapEntry(key: profileId, value: result) in profiles.entries) {
      for (final failure in [...result.notSaved]) {
        await _learning.retry(profileId, failure.id);
      }
    }
  }
}

/// Exports and restores the authenticated user's backup (AD-49).
///
/// This is deliberately a same-user backup format. The uid is part of the
/// payload and is checked on import; profile ids are kept.
///
/// - The account, profile snapshot, diagnostic logs, learner profile docs
///   (without their governed settings keys) and the non-learning profile
///   collections ([rawProfileCollections]) are raw documents.
/// - The learning record is the AD-49 set: `learning_events` (read through
///   `LearningEventRepository`), `sub_tracks` (read through
///   `SubTrackRepository`), `change_log`, the governed
///   collections, the non-event `points_ledger` entries and the
///   `reward_redemptions`. Event-linked `pts_` entries are never exported:
///   a restore re-derives them (AD-50). A restore replays the record
///   through `LearningCommands.importBackup` ([BackupLearningPort]), never
///   as raw documents.
class DataExportImportService {
  DataExportImportService({
    Object? firestore,
    BackupFirestoreGateway? gateway,
    required BackupLearningPort learning,
    required String uid,
    Future<String> Function()? appVersionFetcher,
    LocalDayClock? clock,
  }) : _gateway = gateway ?? backupFirestoreGatewayFor(firestore!),
       _learning = learning,
       _uid = uid,
       _clock = clock ?? const SystemLocalDayClock(),
       _appVersionFetcher =
           appVersionFetcher ??
           (() async {
             final info = await PackageInfo.fromPlatform();
             return info.version;
           });

  /// Version 2: the AD-49 learning record (version 1 carried the retired
  /// completion stores and is no longer restorable, AD-13).
  static const int formatVersion = 2;

  /// AD-54: writes per raw batch.
  static const int _maxBatchWrites = 450;
  static const String _typeKey = '__firestore_type';

  /// `learning_events`: its payload key, read through
  /// [BackupLearningPort.readLearningEvents].
  static const String learningEventsCollection = backupLearningEventsKey;

  /// `sub_tracks`.
  static const String subTracksCollection = 'sub_tracks';

  /// `change_log`.
  static const String changeLogCollection = 'change_log';

  /// `points_ledger` (non-event entries only).
  static const String pointsLedgerCollection = 'points_ledger';

  /// `reward_redemptions`.
  static const String rewardRedemptionsCollection = 'reward_redemptions';

  /// The governed collections, by name (AD-38).
  static final Map<String, GovernedEntity> governedCollections = {
    for (final e in backupGovernedEntities) e.collection: e,
  };

  /// Profile collections outside the learning record, restored as raw
  /// documents. The retired completion stores (`completions`,
  /// `learning_ledger`, `streak_events`, `learning_order`) are neither
  /// exported nor restored (AD-49, R1/R5/R6/R13).
  static const List<String> rawProfileCollections = [
    'settings',
    'point_configs',
    'bookmarks',
    'preferences',
    'import_metadata',
  ];

  /// The learner profile doc field recording the learning records this
  /// profile has been restored from: `{<record key>: <ISO-8601 instant>}`
  /// ([importData]).
  static const String restoredBackupsField = 'restored_backups';

  /// Every profile collection a backup holds.
  static final List<String> profileCollectionNames = [
    learningEventsCollection,
    subTracksCollection,
    changeLogCollection,
    ...governedCollections.keys,
    pointsLedgerCollection,
    rewardRedemptionsCollection,
    ...rawProfileCollections,
  ];

  final BackupFirestoreGateway _gateway;
  final BackupLearningPort _learning;
  final String _uid;
  final LocalDayClock _clock;
  final Future<String> Function() _appVersionFetcher;

  String get _accountPath => 'users/$_uid';

  String get _profilesPath => '$_accountPath/learner_profiles';

  /// Exports version 2 of the backup format.
  ///
  /// The top-level shape is:
  ///
  /// ```text
  /// {
  ///   version: 2,
  ///   uid: string,
  ///   exportedAt: ISO-8601 string,
  ///   appVersion: string,
  ///   account: {id, data},
  ///   profileSnapshot: [{id, data}],
  ///   diagnosticLogs: [{id, data}],
  ///   profiles: [{id, data, collections: {name: [{id, data}]}}]
  /// }
  /// ```
  Future<String> exportData() async {
    final accountData = await _gateway.readDocument(_accountPath);
    final profileSnapshot = await _gateway.readCollection(
      '$_accountPath/profile',
    );
    final diagnosticLogs = await _gateway.readCollection(
      '$_accountPath/diagnostic_logs',
    );
    final profiles = await _gateway.readCollection(_profilesPath);
    final profilePayload = <Map<String, dynamic>>[];

    for (final profile in profiles) {
      final profileId = profile['id'] as String;
      final profilePath = '$_profilesPath/$profileId';
      Future<List<Map<String, dynamic>>> raw(String name) =>
          _gateway.readCollection('$profilePath/$name');
      final events = [...await _learning.readLearningEvents(profileId)]
        ..sort((a, b) => a.id.compareTo(b.id));
      final subTracks = await _learning.readSubTracks(profileId);
      final collections = <String, dynamic>{
        learningEventsCollection: [
          for (final event in events)
            {'id': event.id, 'data': _encodeMap(event.toStorage())},
        ],
        subTracksCollection: [
          for (final track in subTracks)
            {'id': track.id, 'data': _encodeMap(track.toStorage())},
        ],
        changeLogCollection: await raw(changeLogCollection),
        for (final name in governedCollections.keys) name: await raw(name),
        pointsLedgerCollection: [
          for (final entry in await raw(pointsLedgerCollection))
            if (!_isEventEntry(entry)) entry,
        ],
        rewardRedemptionsCollection: await raw(rewardRedemptionsCollection),
        for (final name in rawProfileCollections) name: await raw(name),
      };
      profilePayload.add({
        'id': profileId,
        'data': profile['data'],
        'collections': collections,
      });
    }

    final payload = <String, dynamic>{
      'version': formatVersion,
      'uid': _uid,
      'exportedAt': _clock.nowUtc().toIso8601String(),
      'appVersion': await _appVersionFetcher(),
      'account': {'id': _uid, 'data': accountData},
      'profileSnapshot': profileSnapshot,
      'diagnosticLogs': diagnosticLogs,
      'profiles': profilePayload,
    };
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static bool _isEventEntry(Map<String, dynamic> document) {
    final data = document['data'];
    return isEventPointsEntry(
      document['id'] as String,
      data is Map<String, dynamic> ? data : const {},
    );
  }

  /// Validates a version 2 backup, including every learning record, and
  /// returns its document counts.
  ImportPreview validateAndPreview(String jsonString) {
    final data = _decodePayload(jsonString);
    final account = _requireMap(data, 'account');
    final profileSnapshot = _requireDocumentList(data, 'profileSnapshot');
    final diagnosticLogs = _requireDocumentList(data, 'diagnosticLogs');
    final profiles = _requireList(data, 'profiles');

    _requireString(data, 'uid');
    if (data['uid'] != _uid) {
      throw const ImportValidationException(
        'Backup belongs to a different user',
      );
    }
    if (account['id'] != _uid) {
      throw const ImportValidationException('Invalid account document id');
    }
    _validateDocumentData(account, 'account');
    for (var i = 0; i < profileSnapshot.length; i++) {
      _validateDocumentRecord(profileSnapshot[i], 'profileSnapshot[$i]');
    }
    for (var i = 0; i < diagnosticLogs.length; i++) {
      _validateDocumentRecord(diagnosticLogs[i], 'diagnosticLogs[$i]');
    }

    var total = account['data'] == null ? 0 : 1;
    final counts = <String, int>{};

    for (var i = 0; i < profiles.length; i++) {
      final profile = _requireMapValue(profiles[i], 'profiles[$i]');
      final profileId = _requireString(profile, 'id', path: 'profiles[$i]');
      _validateUlid(profileId, 'profiles[$i].id');
      _validateDocumentData(profile, 'profiles[$i]');
      final collections = _requireMap(profile, 'collections');
      for (final entry in collections.entries) {
        if (!profileCollectionNames.contains(entry.key)) {
          throw ImportValidationException(
            'Unknown profile collection: ${entry.key}',
          );
        }
        final documents = _requireDocumentListValue(
          entry.value,
          'profiles[$i].collections.${entry.key}',
        );
        total += documents.length;
        counts[entry.key] = (counts[entry.key] ?? 0) + documents.length;
        for (var j = 0; j < documents.length; j++) {
          _validateDocumentRecord(
            documents[j],
            'profiles[$i].collections.${entry.key}[$j]',
          );
        }
      }
      _replayInput(
        collections,
        'profiles[$i]',
        profileId: profileId,
        profileData: profile['data'],
      ); // strict record decode
      total += 1;
    }

    total += profileSnapshot.length + diagnosticLogs.length;
    return ImportPreview(
      learningEventCount: counts[learningEventsCollection] ?? 0,
      subTrackCount: counts[subTracksCollection] ?? 0,
      goalCount: counts['goals'] ?? 0,
      stageCount: counts['stage_definitions'] ?? 0,
      pointConfigCount: counts['point_configs'] ?? 0,
      bookmarkCount: counts['bookmarks'] ?? 0,
      learningOrderCount: counts['track_learning_order'] ?? 0,
      curriculumTrackCount: counts['curriculum_tracks'] ?? 0,
      userProfileCount: profiles.length,
      totalDocumentCount: total,
      exportedAt: data['exportedAt'] as String? ?? 'unknown',
      appVersion: data['appVersion'] as String? ?? 'unknown',
    );
  }

  /// Restores a backup into this same user's account.
  ///
  /// 1. The raw documents are written first: the account doc, the
  ///    profile snapshot, the diagnostic logs, each learner profile doc
  ///    merged WITHOUT its governed settings keys (AD-37), and the
  ///    [rawProfileCollections] — in batches of at most 450 writes.
  /// 2. Each profile's learning record is then replayed through
  ///    `LearningCommands.importBackup` (AD-49): its settings history as
  ///    updates of the import-time settings, governed docs as logged
  ///    updates, sub-tracks and events under fresh ids with `pts_`
  ///    re-derived, then the non-event points and redemptions.
  ///
  /// A profile whose learning record this backup already restored (its
  /// doc's [restoredBackupsField] holds the record's key) is not replayed
  /// again ([BackupImportReport.alreadyRestored]): every replayed record
  /// gets a fresh id, so a second replay would duplicate the history and
  /// the points, spends and redemptions.
  ///
  /// Nothing is deleted. The report never claims a write was saved when
  /// the server refused it: such writes are "not saved — retry" entries
  /// ([BackupImportReport.retryNotSaved]).
  Future<BackupImportReport> importData(String jsonString) async {
    validateAndPreview(jsonString);
    final data = _decodePayload(jsonString);
    final writes = <BackupDocumentWrite>[];

    final account = _requireMap(data, 'account');
    final accountData = account['data'];
    if (accountData != null) {
      writes.add(
        BackupDocumentWrite(
          _accountPath,
          _decodeMapValue(accountData, 'account'),
        ),
      );
    }

    _addWrites(
      writes,
      '$_accountPath/profile',
      _requireDocumentList(data, 'profileSnapshot'),
    );
    _addWrites(
      writes,
      '$_accountPath/diagnostic_logs',
      _requireDocumentList(data, 'diagnosticLogs'),
    );

    final replays = <String, BackupReplayInput>{};
    final recordKeys = <String, String>{};
    for (final rawProfile in _requireList(data, 'profiles')) {
      final profile = _requireMapValue(rawProfile, 'profile');
      final profileId = _requireString(profile, 'id', path: 'profile');
      final profilePath = '$_profilesPath/$profileId';
      final profileData = profile['data'];
      if (profileData != null) {
        final fields = _decodeMapValue(profileData, 'profiles.$profileId.data')
          ..removeWhere((key, _) => LearnerSettings.storageKeys.contains(key));
        writes.add(BackupDocumentWrite(profilePath, fields, merge: true));
      }
      final collections = _requireMap(profile, 'collections');
      for (final name in rawProfileCollections) {
        final documents = collections[name];
        if (documents == null) continue;
        _addWrites(
          writes,
          '$profilePath/$name',
          _requireDocumentListValue(
            documents,
            'profiles.$profileId.collections.$name',
          ),
        );
      }
      replays[profileId] = _replayInput(
        collections,
        'profiles.$profileId',
        profileId: profileId,
        profileData: profileData,
      );
      recordKeys[profileId] = await _recordKey(profileId, collections);
    }

    for (var offset = 0; offset < writes.length; offset += _maxBatchWrites) {
      final end = (offset + _maxBatchWrites).clamp(0, writes.length);
      await _gateway.writeBatch(writes.sublist(offset, end));
    }

    final results = <String, BackupReplayResult>{};
    final alreadyRestored = <String>{};
    for (final MapEntry(key: profileId, value: input) in replays.entries) {
      final profilePath = '$_profilesPath/$profileId';
      final key = recordKeys[profileId]!;
      final current = await _gateway.readDocument(profilePath);
      final restored = current?[restoredBackupsField];
      if (restored is Map && restored.containsKey(key)) {
        alreadyRestored.add(profileId);
        continue;
      }
      final result = await _learning.replay(profileId, input);
      results[profileId] = result;
      if (result.result is CaptureSuccess && result.steps.isNotEmpty) {
        // Something was written (or queued): mark the record restored so
        // a repeat import cannot replay it a second time. Its unsaved
        // writes stay retryable through the report, never by re-importing.
        await _gateway.writeBatch([
          BackupDocumentWrite(profilePath, {
            restoredBackupsField: {key: _clock.nowUtc().toIso8601String()},
          }, merge: true),
        ]);
      }
    }
    return BackupImportReport(
      profiles: results,
      learning: _learning,
      alreadyRestored: alreadyRestored,
    );
  }

  /// The identity of one profile's learning record in a backup: the
  /// SHA-256 of its profile id and its AD-49 collections. The same backup
  /// (or another export of an unchanged record) has the same key.
  static Future<String> _recordKey(
    String profileId,
    Map<String, dynamic> collections,
  ) async {
    final record = [
      profileId,
      for (final name in profileCollectionNames)
        if (!rawProfileCollections.contains(name)) [name, collections[name]],
    ];
    final hash = await Sha256().hash(utf8.encode(jsonEncode(record)));
    return [
      for (final b in hash.bytes) b.toRadixString(16).padLeft(2, '0'),
    ].join();
  }

  /// The strictly decoded AD-49 learning record of one profile's
  /// [collections], with the settings of its [profileData] as the replay's
  /// settings seed. Throws [ImportValidationException] for any record no
  /// replay could write.
  BackupReplayInput _replayInput(
    Map<String, dynamic> collections,
    String at, {
    required String profileId,
    required Object? profileData,
  }) {
    List<(String, Map<String, Object?>)> docs(String name) {
      final value = collections[name];
      if (value == null) return const [];
      return [
        for (final document in _requireDocumentListValue(value, '$at.$name'))
          (
            document['id'] as String,
            _storageMap(document['data'], '$at.$name.${document['id']}'),
          ),
      ];
    }

    T decode<T>(String what, String id, T Function() read) {
      try {
        return read();
      } on StorageFormatException catch (e) {
        throw ImportValidationException('$at: invalid $what $id ($e)');
      }
    }

    return BackupReplayInput(
      settingsSeed: _settingsSeed(profileId, profileData, at),
      events: [
        for (final (id, map) in docs(learningEventsCollection))
          decode(
            'learning event',
            id,
            () => LearningEvent.fromStorage(id, map)..toStorage(),
          ),
      ],
      subTracks: [
        for (final (id, map) in docs(subTracksCollection))
          decode('sub-track', id, () => SubTrack.fromStorage(id, map)),
      ],
      changeLog: [
        for (final (id, map) in docs(changeLogCollection))
          // Only learnerSettings entries replay (AD-49); the rest of the
          // history is exported but never re-written.
          if (map[ChangeLogEntry.kEntity] ==
              GovernedEntity.learnerSettings.storage)
            decode(
              'change-log entry',
              id,
              () => ChangeLogEntry.fromStorage(id, map),
            ),
      ],
      governed: {
        for (final MapEntry(key: name, value: entity)
            in governedCollections.entries)
          entity: [for (final (id, map) in docs(name)) BackupDoc(id, map)],
      },
      pointsEntries: [
        for (final (id, map) in docs(pointsLedgerCollection))
          if (!isEventPointsEntry(id, map)) BackupDoc(id, map),
      ],
      rewardRedemptions: [
        for (final (id, map) in docs(rewardRedemptionsCollection))
          BackupDoc(id, map),
      ],
    );
  }

  /// The governed settings a backed-up learner profile doc holds (the
  /// state its `learnerSettings` history ends in), strictly decoded; empty
  /// when it holds no `time_zone` (never seeded).
  Map<String, Object?> _settingsSeed(
    String profileId,
    Object? profileData,
    String at,
  ) {
    if (profileData is! Map) return const {};
    // Only the settings keys: the rest of the doc is restored raw.
    final map = _storageMap({
      for (final key in LearnerSettings.storageKeys)
        if (profileData[key] != null) key: profileData[key],
    }, '$at.data');
    if (map[LearnerSettings.kTimeZone] == null) return const {};
    try {
      LearnerSettings.fromProfileDoc(profileId, map);
    } on StorageFormatException catch (e) {
      throw ImportValidationException('$at: invalid learner settings ($e)');
    }
    return {
      for (final key in LearnerSettings.storageKeys)
        if (key != LearnerSettings.kLastChangeId && map[key] != null)
          key: map[key],
    };
  }

  /// [value] decoded to the AD-52 storage form the domain codecs read:
  /// instants as UTC `DateTime`s. Any other typed Firestore value has no
  /// place in a learning record and is rejected.
  Map<String, Object?> _storageMap(Object? value, String path) {
    final decoded = _storageValue(value, path);
    if (decoded is! Map<String, Object?>) {
      throw ImportValidationException('$path must be an object');
    }
    return decoded;
  }

  Object? _storageValue(Object? value, String path) {
    if (value is List) {
      return [for (final v in value) _storageValue(v, path)];
    }
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    final type = map[_typeKey];
    if (type is String) {
      switch (type) {
        case 'map':
          return _storageMap(map['value'], path);
        case 'timestamp':
          final raw = map['value'];
          final parsed = raw is String ? DateTime.tryParse(raw) : null;
          if (parsed == null) {
            throw ImportValidationException('$path: invalid timestamp');
          }
          return parsed.toUtc();
        default:
          throw ImportValidationException(
            '$path: unsupported value type $type',
          );
      }
    }
    return <String, Object?>{
      for (final entry in map.entries)
        entry.key: _storageValue(entry.value, path),
    };
  }

  void _addWrites(
    List<BackupDocumentWrite> writes,
    String collectionPath,
    List<Map<String, dynamic>> documents,
  ) {
    for (final document in documents) {
      final id = document['id'];
      if (id is! String || id.isEmpty) {
        throw const ImportValidationException('Document id must be a string');
      }
      writes.add(
        BackupDocumentWrite(
          '$collectionPath/$id',
          _decodeMapValue(document['data'], 'document $id'),
        ),
      );
    }
  }

  Map<String, dynamic> _decodePayload(String jsonString) {
    final Object? decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (_) {
      throw const ImportValidationException('Invalid JSON format');
    }
    if (decoded is! Map) {
      throw const ImportValidationException('Backup root must be an object');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['version'] != formatVersion) {
      throw const ImportValidationException('Unsupported backup version');
    }
    return data;
  }

  Map<String, dynamic> _encodeMap(Map<String, dynamic> data) {
    final encoded = <String, dynamic>{
      for (final entry in data.entries) entry.key: _encodeValue(entry.value),
    };
    if (encoded.containsKey(_typeKey)) {
      return {_typeKey: 'map', 'value': encoded};
    }
    return encoded;
  }

  dynamic _encodeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is DateTime) {
      return {_typeKey: 'timestamp', 'value': value.toUtc().toIso8601String()};
    }
    if (value is Uint8List) {
      return {_typeKey: 'bytes', 'value': base64Encode(value)};
    }
    if (value is List) return value.map(_encodeValue).toList();
    if (value is Map) {
      return _encodeMap(Map<String, dynamic>.from(value));
    }
    return _gateway.decodeValue(value);
  }

  Map<String, dynamic> _decodeMapValue(Object? value, String path) {
    final decoded = _decodeValue(value);
    if (decoded is! Map<String, dynamic>) {
      throw ImportValidationException('$path must be an object');
    }
    return decoded;
  }

  dynamic _decodeValue(Object? value) {
    if (value is List) return value.map(_decodeValue).toList();
    if (value is! Map) return value;
    final map = Map<String, dynamic>.from(value);
    final type = map[_typeKey];
    if (type is String) {
      switch (type) {
        case 'map':
          return _decodeMapValue(map['value'], 'encoded map');
        case 'timestamp' || 'geopoint' || 'reference' || 'bytes':
          return _gateway.decodeValue(map);
        default:
          throw ImportValidationException(
            'Unknown Firestore value type: $type',
          );
      }
    }
    return <String, dynamic>{
      for (final entry in map.entries) entry.key: _decodeValue(entry.value),
    };
  }

  static List<dynamic> _requireList(Map<String, dynamic> data, String key) {
    final value = data[key];
    if (value is! List) {
      throw ImportValidationException('Missing or invalid section: $key');
    }
    return value;
  }

  static Map<String, dynamic> _requireMap(
    Map<String, dynamic> data,
    String key,
  ) {
    final value = data[key];
    if (value is! Map) {
      throw ImportValidationException('Missing or invalid object: $key');
    }
    return Map<String, dynamic>.from(value);
  }

  static Map<String, dynamic> _requireMapValue(Object? value, String path) {
    if (value is! Map) {
      throw ImportValidationException('$path must be an object');
    }
    return Map<String, dynamic>.from(value);
  }

  static String _requireString(
    Map<String, dynamic> data,
    String key, {
    String path = 'backup',
  }) {
    final value = data[key];
    if (value is! String || value.isEmpty) {
      throw ImportValidationException('$path.$key must be a string');
    }
    return value;
  }

  static List<Map<String, dynamic>> _requireDocumentList(
    Map<String, dynamic> data,
    String key,
  ) => _requireDocumentListValue(_requireList(data, key), key);

  static List<Map<String, dynamic>> _requireDocumentListValue(
    Object? value,
    String path,
  ) {
    if (value is! List) {
      throw ImportValidationException('$path must be a list');
    }
    return [for (final item in value) _requireMapValue(item, path)];
  }

  static void _validateDocumentRecord(
    Map<String, dynamic> document,
    String path,
  ) {
    final id = document['id'];
    if (id is! String || id.isEmpty) {
      throw ImportValidationException('$path.id must be a non-empty string');
    }
    _validateDocumentData(document, path);
  }

  static void _validateDocumentData(
    Map<String, dynamic> document,
    String path,
  ) {
    if (!document.containsKey('data')) {
      throw ImportValidationException('$path.data is missing');
    }
    if (document['data'] != null && document['data'] is! Map) {
      throw ImportValidationException('$path.data must be an object or null');
    }
  }

  static void _validateUlid(String value, String path) {
    if (!RegExp(r'^[0-9A-HJKMNP-TV-Z]{26}$').hasMatch(value)) {
      throw ImportValidationException(
        '$path must be a valid 26-character ULID',
      );
    }
  }
}
