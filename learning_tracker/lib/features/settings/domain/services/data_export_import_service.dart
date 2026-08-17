import 'dart:convert';
import 'dart:typed_data';

import 'package:learning_tracker/core/time/local_day_clock.dart';
import 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart';
import 'package:learning_tracker/features/settings/domain/exceptions/import_validation_exception.dart';
import 'package:package_info_plus/package_info_plus.dart';

export 'package:learning_tracker/data/repositories/backup_firestore_gateway.dart'
    show BackupDocumentWrite, BackupFirestoreGateway;

/// Summary of a Firestore backup payload.
class ImportPreview {
  const ImportPreview({
    required this.completionCount,
    required this.goalCount,
    required this.stageCount,
    required this.streakCount,
    required this.pointConfigCount,
    required this.bookmarkCount,
    required this.learningOrderCount,
    required this.curriculumTrackCount,
    required this.userProfileCount,
    required this.exportedAt,
    required this.appVersion,
    required this.ledgerCount,
    required this.totalDocumentCount,
  });

  final int completionCount;
  final int goalCount;
  final int stageCount;
  final int streakCount;
  final int pointConfigCount;
  final int bookmarkCount;
  final int learningOrderCount;
  final int curriculumTrackCount;
  final int userProfileCount;
  final int ledgerCount;
  final int totalDocumentCount;
  final String exportedAt;
  final String appVersion;

  int get totalRecords => totalDocumentCount;
}

/// Exports and restores the authenticated user's Firestore document tree.
///
/// This is deliberately a same-user backup format. The uid is part of the
/// payload and is checked on import; no profile or account identity is
/// remapped. Documents are represented by their Firestore document id and raw
/// field map so fields added by a repository are not silently discarded.
class DataExportImportService {
  DataExportImportService({
    Object? firestore,
    BackupFirestoreGateway? gateway,
    required String uid,
    Future<String> Function()? appVersionFetcher,
    LocalDayClock? clock,
  }) : _gateway = gateway ?? backupFirestoreGatewayFor(firestore!),
       _uid = uid,
       _clock = clock ?? const SystemLocalDayClock(),
       _appVersionFetcher =
           appVersionFetcher ??
           (() async {
             final info = await PackageInfo.fromPlatform();
             return info.version;
           });

  static const int formatVersion = 1;
  static const int _pageSize = 500;
  static const String _typeKey = '__firestore_type';

  // These are the profile-scoped collections declared in firestore.rules.
  // Keeping this list here makes the backup boundary explicit and prevents
  // tutor-owned or other-account collections from entering a user backup.
  static const List<String> _profileCollectionNames = [
    'completions',
    'streak_events',
    'learning_ledger',
    'points_ledger',
    'reward_redemptions',
    'settings',
    'stage_definitions',
    'point_configs',
    'curriculum_tracks',
    'bookmarks',
    'learning_order',
    'track_learning_order',
    'preferences',
    'goals',
    'import_metadata',
    'profile_programs',
    'curriculum_scopes',
    'study_day_configs',
  ];

  final BackupFirestoreGateway _gateway;
  final String _uid;
  final LocalDayClock _clock;
  final Future<String> Function() _appVersionFetcher;

  String get _accountPath => 'users/$_uid';

  String get _profilesPath => '$_accountPath/learner_profiles';

  /// Exports version 1 of the Firestore backup format.
  ///
  /// The top-level shape is:
  ///
  /// ```text
  /// {
  ///   version: 1,
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
      final profilePath = '$_profilesPath/${profile['id'] as String}';
      final collections = <String, dynamic>{};
      for (final collectionName in _profileCollectionNames) {
        collections[collectionName] = await _gateway.readCollection(
          '$profilePath/$collectionName',
        );
      }
      profilePayload.add({
        'id': profile['id'],
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

  /// Validates a version 1 backup and returns its document counts.
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
    var completions = 0;
    var goals = 0;
    var stages = 0;
    var streaks = 0;
    var pointConfigs = 0;
    var bookmarks = 0;
    var learningOrders = 0;
    var tracks = 0;
    var ledger = 0;

    for (var i = 0; i < profiles.length; i++) {
      final profile = _requireMapValue(profiles[i], 'profiles[$i]');
      final profileId = _requireString(profile, 'id', path: 'profiles[$i]');
      _validateUlid(profileId, 'profiles[$i].id');
      _validateDocumentData(profile, 'profiles[$i]');
      final collections = _requireMap(profile, 'collections');
      for (final entry in collections.entries) {
        if (!_profileCollectionNames.contains(entry.key)) {
          throw ImportValidationException(
            'Unknown profile collection: ${entry.key}',
          );
        }
        final documents = _requireDocumentListValue(
          entry.value,
          'profiles[$i].collections.${entry.key}',
        );
        total += documents.length;
        switch (entry.key) {
          case 'completions':
            completions += documents.length;
          case 'goals':
            goals += documents.length;
          case 'stage_definitions':
            stages += documents.length;
          case 'streak_events':
            streaks += documents.length;
          case 'point_configs':
            pointConfigs += documents.length;
          case 'bookmarks':
            bookmarks += documents.length;
          case 'learning_order' || 'track_learning_order':
            learningOrders += documents.length;
          case 'curriculum_tracks':
            tracks += documents.length;
          case 'learning_ledger':
            ledger += documents.length;
        }
        for (var j = 0; j < documents.length; j++) {
          _validateDocumentRecord(
            documents[j],
            'profiles[$i].collections.${entry.key}[$j]',
          );
        }
      }
      total += 1;
    }

    total += profileSnapshot.length + diagnosticLogs.length;
    return ImportPreview(
      completionCount: completions,
      goalCount: goals,
      stageCount: stages,
      streakCount: streaks,
      pointConfigCount: pointConfigs,
      bookmarkCount: bookmarks,
      learningOrderCount: learningOrders,
      curriculumTrackCount: tracks,
      userProfileCount: profiles.length,
      ledgerCount: ledger,
      totalDocumentCount: total,
      exportedAt: data['exportedAt'] as String? ?? 'unknown',
      appVersion: data['appVersion'] as String? ?? 'unknown',
    );
  }

  /// Restores a backup into this same user's Firestore tree.
  ///
  /// Firestore client rules deny deletes, including for append-only
  /// collections. Import therefore only creates or overwrites documents that
  /// are present in the backup. Existing documents absent from the payload are
  /// intentionally left alone. A tombstoned completion or ledger entry is
  /// written with its encoded `purged_at` value intact, so restore never
  /// resurrects purged history.
  Future<void> importData(String jsonString) async {
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

    for (final rawProfile in _requireList(data, 'profiles')) {
      final profile = _requireMapValue(rawProfile, 'profile');
      final profileId = _requireString(profile, 'id', path: 'profile');
      final profilePath = '$_profilesPath/$profileId';
      writes.add(
        BackupDocumentWrite(
          profilePath,
          _decodeMapValue(profile['data'], 'profiles.$profileId.data'),
        ),
      );
      final collections = _requireMap(profile, 'collections');
      for (final entry in collections.entries) {
        final documents = _requireDocumentListValue(
          entry.value,
          'profiles.$profileId.collections.${entry.key}',
        );
        _addWrites(writes, '$profilePath/${entry.key}', documents);
      }
    }

    for (var offset = 0; offset < writes.length; offset += _pageSize) {
      final end = (offset + _pageSize).clamp(0, writes.length);
      await _gateway.writeBatch(writes.sublist(offset, end));
    }
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
