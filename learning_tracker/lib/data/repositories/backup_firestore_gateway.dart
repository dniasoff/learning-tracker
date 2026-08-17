import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:learning_tracker/data/firestore/active_account_providers.dart';

/// The persistence contract used by the settings backup service.
///
/// The service depends on document paths and JSON-safe maps only. This
/// interface and its Firebase implementation live in the repository layer so
/// feature/domain code never needs to import the Firebase SDK.
abstract interface class BackupFirestoreGateway {
  Future<Map<String, dynamic>?> readDocument(String path);

  Future<List<Map<String, dynamic>>> readCollection(String path);

  Future<void> writeBatch(List<BackupDocumentWrite> writes);

  Object? decodeValue(Object? value);
}

final class BackupDocumentWrite {
  const BackupDocumentWrite(this.path, this.data);

  final String path;
  final Map<String, dynamic> data;
}

/// Account-bound backup access resolved from the active authenticated session.
final class BackupFirestoreGatewaySession {
  const BackupFirestoreGatewaySession({
    required this.uid,
    required this.gateway,
  });

  final String uid;
  final BackupFirestoreGateway gateway;
}

/// Keeps the legacy constructor seam used by unit tests while leaving the
/// Firebase-specific cast inside the allowed repository layer.
BackupFirestoreGateway backupFirestoreGatewayFor(Object firestore) =>
    _FirebaseBackupFirestoreGateway(firestore as FirebaseFirestore);

final backupFirestoreGatewayProvider =
    FutureProvider<BackupFirestoreGatewaySession?>((ref) async {
      final handles = await ref.watch(activeAccountFirebaseProvider.future);
      if (handles == null) return null;
      return BackupFirestoreGatewaySession(
        uid: handles.uid,
        gateway: _FirebaseBackupFirestoreGateway(handles.firestore),
      );
    }, retry: (retryCount, error) => null);

final class _FirebaseBackupFirestoreGateway implements BackupFirestoreGateway {
  _FirebaseBackupFirestoreGateway(this._firestore);

  static const int _pageSize = 500;
  static const String _typeKey = '__firestore_type';

  final FirebaseFirestore _firestore;

  @override
  Future<Map<String, dynamic>?> readDocument(String path) async {
    final snapshot = await _firestore.doc(path).get();
    final data = snapshot.data();
    return data == null ? null : _encodeMap(data);
  }

  @override
  Future<List<Map<String, dynamic>>> readCollection(String path) async {
    final result = <Map<String, dynamic>>[];
    DocumentSnapshot<Map<String, dynamic>>? last;
    while (true) {
      var query = _firestore
          .collection(path)
          .orderBy(FieldPath.documentId)
          .limit(_pageSize);
      if (last != null) query = query.startAfterDocument(last);
      final snapshot = await query.get();
      result.addAll(
        snapshot.docs.map(
          (doc) => {'id': doc.id, 'data': _encodeMap(doc.data())},
        ),
      );
      if (snapshot.docs.length < _pageSize) break;
      last = snapshot.docs.last;
    }
    return result;
  }

  @override
  Future<void> writeBatch(List<BackupDocumentWrite> writes) async {
    final batch = _firestore.batch();
    for (final write in writes) {
      batch.set(_firestore.doc(write.path), write.data);
    }
    await batch.commit();
  }

  @override
  Object? decodeValue(Object? value) {
    if (value == null || value is String || value is num || value is bool) {
      return value;
    }
    if (value is Timestamp) {
      return {
        _typeKey: 'timestamp',
        'value': value.toDate().toUtc().toIso8601String(),
      };
    }
    if (value is DateTime) {
      return {_typeKey: 'timestamp', 'value': value.toUtc().toIso8601String()};
    }
    if (value is GeoPoint) {
      return {
        _typeKey: 'geopoint',
        'latitude': value.latitude,
        'longitude': value.longitude,
      };
    }
    if (value is DocumentReference) {
      return {_typeKey: 'reference', 'path': value.path};
    }
    if (value is Blob) {
      return {_typeKey: 'bytes', 'value': base64Encode(value.bytes)};
    }
    if (value is Uint8List) {
      return {_typeKey: 'bytes', 'value': base64Encode(value)};
    }
    if (value is List) return value.map(decodeValue).toList();
    if (value is Map) {
      final map = Map<String, dynamic>.from(value);
      final type = map[_typeKey];
      if (type is String &&
          const {
            'timestamp',
            'geopoint',
            'reference',
            'bytes',
          }.contains(type)) {
        return _restoreValue(map);
      }
      return _encodeMap(map);
    }

    throw FormatException('Unsupported Firestore value: ${value.runtimeType}');
  }

  Map<String, dynamic> _encodeMap(Map<String, dynamic> data) {
    final encoded = <String, dynamic>{
      for (final entry in data.entries) entry.key: decodeValue(entry.value),
    };
    if (encoded.containsKey(_typeKey)) {
      return {_typeKey: 'map', 'value': encoded};
    }
    return encoded;
  }

  Object? _restoreValue(Map<String, dynamic> map) {
    switch (map[_typeKey]) {
      case 'timestamp':
        return Timestamp.fromDate(
          DateTime.parse(map['value'] as String).toUtc(),
        );
      case 'geopoint':
        return GeoPoint(
          (map['latitude'] as num).toDouble(),
          (map['longitude'] as num).toDouble(),
        );
      case 'reference':
        final path = map['path'];
        if (path is! String || path.isEmpty) {
          throw const FormatException('Invalid document reference');
        }
        return _firestore.doc(path);
      case 'bytes':
        return Blob(Uint8List.fromList(base64Decode(map['value'] as String)));
      default:
        throw FormatException('Unknown Firestore value type: ${map[_typeKey]}');
    }
  }
}
