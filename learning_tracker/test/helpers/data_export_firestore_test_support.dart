import 'dart:convert';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:learning_tracker/features/settings/domain/services/data_export_import_service.dart';

const testUid = 'backup-test-user';
const testProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FAV';
const secondTestProfileId = '01ARZ3NDEKTSV4RRFFQ69G5FB0';

DataExportImportService backupService(
  FakeFirebaseFirestore firestore, {
  String uid = testUid,
  String appVersion = '1.0.0-test',
}) => DataExportImportService(
  firestore: firestore,
  uid: uid,
  appVersionFetcher: () async => appVersion,
);

Future<Map<String, dynamic>> exportedMap(
  DataExportImportService service,
) async => jsonDecode(await service.exportData()) as Map<String, dynamic>;

Map<String, dynamic> profileFrom(
  Map<String, dynamic> payload,
  String profileId,
) {
  final profiles = (payload['profiles'] as List).cast<Map<String, dynamic>>();
  return profiles.singleWhere((profile) => profile['id'] == profileId);
}

List<Map<String, dynamic>> collectionDocuments(
  Map<String, dynamic> profile,
  String collectionName,
) => ((profile['collections'] as Map<String, dynamic>)[collectionName] as List)
    .cast<Map<String, dynamic>>();

Map<String, dynamic> documentData(Map<String, dynamic> document) =>
    document['data'] as Map<String, dynamic>;
